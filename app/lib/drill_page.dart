import 'dart:math';

import 'package:flutter/material.dart';

import 'drill.dart';
import 'earned_rows.dart';
import 'learn_log.dart';
import 'learn_text.dart';
import 'logic.dart';
import 'main.dart';
import 'store.dart' show Achievement;
import 'ui.dart';
import 'words.dart';

/// Choose the best (or, with [LearnKind.opener], choose the best first guess):
/// a position is shown (the guesses so far with their colours
/// and how many words still fit) with four words to choose from, and the job is
/// to pick the one that tells the words apart best. After each pick it says
/// which was best and why. A round is [drillRoundLength] positions; the next one
/// is worked out while the last is answered. Not scored and not kept in the
/// history, as learn mode is not.
class DrillPage extends StatefulWidget {
  const DrillPage({
    super.key,
    required this.bank,
    this.kind = LearnKind.choose,
    this.seed,
    this.onRound,
  });
  final WordBank bank;

  /// Which drill: positions from play, or the opening guess.
  final LearnKind kind;

  /// Fixes the positions drawn, for a test; null draws at random.
  final int? seed;

  /// Called with each finished round.
  final void Function(DrillRound round)? onRound;

  @override
  State<DrillPage> createState() => _DrillPageState();
}

class _DrillPageState extends State<DrillPage> {
  late final _rng = Random(widget.seed);
  late final int length = appState.length;

  final _answers = <DrillAnswer>[];
  DrillQuestion? question;
  Future<DrillQuestion?>? _next;
  DrillOption? picked;
  bool failed = false;
  bool done = false;

  /// The achievements the finished round earned.
  List<Achievement> _earned = const [];

  @override
  void initState() {
    super.initState();
    _begin();
  }

  bool get _opener => widget.kind == LearnKind.opener;
  late final int _total = roundLengthOf(widget.kind);

  // the opener is analysed once, for every question of every round
  Landscape? _openerLand;

  Future<DrillQuestion?> _build() async {
    if (!_opener) {
      return buildDrillQuestion(
        bank: widget.bank,
        length: length,
        draw: appState.draw,
        rng: _rng,
      );
    }
    final q = await buildOpenerQuestion(
      bank: widget.bank,
      length: length,
      draw: appState.draw,
      rng: _rng,
      landscape: _openerLand,
    );
    _openerLand ??= q?.landscape;
    return q;
  }

  void _begin() {
    _answers.clear();
    question = null;
    picked = null;
    failed = false;
    done = false;
    _earned = const [];
    _next = _build();
    _show();
  }

  /// Puts the prefetched position on screen and starts the one after it.
  Future<void> _show() async {
    final q = await _next;
    if (!mounted) return;
    setState(() {
      question = q;
      failed = q == null;
      picked = null;
    });
    if (q != null && _answers.length + 1 < _total) _next = _build();
  }

  void _pick(DrillOption o) {
    final q = question;
    if (q == null || picked != null) return;
    setState(() {
      picked = o;
      _answers.add(DrillAnswer(o.word, o.skill, q.isRight(o)));
    });
  }

  void _forward() {
    if (_answers.length >= _total) {
      final round = _round();
      final earned = appState.recordLearn(
        round.toEvent(DateTime.now().toIso8601String().substring(0, 10)),
      );
      widget.onRound?.call(round);
      setState(() {
        done = true;
        _earned = earned;
      });
      return;
    }
    setState(() {
      question = null;
      picked = null;
    });
    _show();
  }

  DrillRound _round() => DrillRound(
    widget.bank.language.code,
    length,
    List.of(_answers),
    kind: widget.kind,
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    final n = min(_answers.length + (picked == null ? 1 : 0), _total);
    final head =
        '${_opener ? 'the opener' : 'choose the best'} · $lang · $length';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagBadge(widget.bank.language.flag, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                done ? head : '$head · $n of $_total',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
              children: done ? _summary(c) : _body(c),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(ColorScheme c) {
    final q = question;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    if (failed) {
      return const [
        Caption('this word list has no position to choose in at this length'),
      ];
    }
    if (q == null) {
      return const [Caption('finding a position…')];
    }
    final p = picked;
    final fits = q.eligible.length;
    return [
      Caption(
        _opener
            ? 'which word is the best first guess?'
            : 'which guess tells the words that fit apart best?',
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) {
          const gap = 6.0;
          final size = min(44.0, (box.maxWidth - gap * (length - 1)) / length);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var g = 0; g < q.guesses.length; g++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        MarkTile(
                          q.guesses[g][i],
                          mark: q.marks[g][i],
                          size: size,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
      Text(
        '$fits ${fits == 1 ? 'word fits' : 'words fit'} the clues',
        key: const ValueKey('drill-fits'),
        style: dim,
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < q.options.length; i++) _option(c, q, q.options[i], i),
      if (p != null) ...[
        const SizedBox(height: 10),
        _verdict(c, q, p, dim),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('drill-next'),
          onPressed: _forward,
          child: Text(_answers.length >= _total ? 'see the result' : 'next'),
        ),
      ],
    ];
  }

  Widget _option(ColorScheme c, DrillQuestion q, DrillOption o, int i) {
    final p = picked;
    final isPicked = identical(p, o);
    final isBest = p != null && q.isRight(o);
    final border = p == null
        ? c.outline
        : isBest
        ? c.secondary
        : isPicked
        ? c.error
        : c.outlineVariant;
    final faded = p != null && !isPicked && !isBest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        key: ValueKey('drill-option-$i'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border, width: isPicked || isBest ? 2 : 1),
          shape: const RoundedRectangleBorder(),
          alignment: Alignment.centerLeft,
        ),
        onPressed: p == null ? () => _pick(o) : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                o.word,
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 2,
                  color: faded
                      ? c.onSurface.withValues(alpha: dimAlpha)
                      : c.onSurface,
                ),
              ),
            ),
            if (p != null)
              Text(
                isBest
                    ? 'best · ${o.skill.round()}'
                    : 'skill ${o.skill.round()}',
                style: TextStyle(
                  fontSize: 12,
                  color: isBest ? c.secondary : c.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _verdict(
    ColorScheme c,
    DrillQuestion q,
    DrillOption p,
    TextStyle dim,
  ) {
    final right = q.isRight(p);
    final r = q.report(p);
    return Column(
      key: const ValueKey('drill-verdict'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          right
              ? 'right: nothing here does better'
              : 'not the best: ${r.bestWord} is',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: right ? c.secondary : c.error,
          ),
        ),
        for (final line in learnWhy(r))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(line, style: dim),
          ),
      ],
    );
  }

  List<Widget> _summary(ColorScheme c) {
    final round = _round();
    return [
      const SizedBox(height: 12),
      Text(
        '${round.right} of $_total right',
        key: const ValueKey('drill-score'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Text(
        'average skill ${round.averageSkill.round()}',
        key: const ValueKey('drill-average'),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < _answers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '${i + 1}  ${_answers[i].word}  skill ${_answers[i].skill.round()}',
            style: TextStyle(
              color: _answers[i].right ? c.secondary : c.onSurface,
            ),
          ),
        ),
      if (_earned.isNotEmpty) ...[
        const SizedBox(height: 16),
        EarnedRows(_earned),
      ],
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('drill-again'),
        onPressed: () => setState(_begin),
        child: const Text('another round'),
      ),
    ];
  }
}
