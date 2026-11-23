import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'calc_dialog.dart';
import 'guess_quiz.dart';
import 'logic.dart';
import 'main.dart';
import 'typing_keys.dart';
import 'ui.dart';
import 'words.dart';

/// Guess the best, an endless quiz of real positions. The questions alternate
/// between two kinds: which guess splits the rest best (skill), and which of
/// four guesses, all played against the same hidden word, got the luckiest
/// reply (luck). Not scored and not kept, as learn is not.
class GuessPage extends StatefulWidget {
  const GuessPage({super.key, required this.bank, this.seed});
  final WordBank bank;

  /// Fixes the questions drawn, for a test; null draws at random.
  final int? seed;

  @override
  State<GuessPage> createState() => _GuessPageState();
}

class _GuessPageState extends State<GuessPage> {
  late final _rng = Random(widget.seed);
  late final int length = appState.learnLength;
  GuessQuestion? question;
  int? picked;
  bool failed = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _next();
  }

  /// Works out the next question (first skill, then luck, then skill...).
  Future<void> _next() async {
    final kind = _count.isEven ? GuessKind.skill : GuessKind.luck;
    _count++;
    setState(() {
      question = null;
      picked = null;
      failed = false;
    });
    GuessQuestion? q;
    try {
      // let the "finding" caption show before the work
      await Future<void>.delayed(Duration.zero);
      q = buildGuessQuestion(
        bank: widget.bank,
        length: length,
        draw: appState.learnDraw,
        rng: _rng,
        kind: kind,
      );
    } catch (e) {
      appLog.w('learn', 'could not build a guess question ${e.runtimeType}');
    }
    if (!mounted) return;
    setState(() {
      question = q;
      failed = q == null;
    });
  }

  void _pick(int i) {
    if (question == null || picked != null) return;
    setState(() => picked = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => handleChoiceKey(
        e,
        count: question?.options.length ?? 0,
        answered: picked != null,
        pick: _pick,
        next: _next,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlagBadge(widget.bank.language.flag, size: 16),
              const SizedBox(width: 8),
              TablerIcon('school', size: headerIconSize, color: c.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'guess the best · $lang · $length',
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
                children: _body(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  CalcSpec _questionSpec(GuessQuestion q) {
    final n = q.eligible.length;
    return q.kind == GuessKind.skill
        ? CalcSpec(
            metric: 'skill',
            title: 'splitting the rest',
            intro:
                'the best guess is the one expected to gain the most bits, so '
                'it leaves the fewest words on average. it does not depend on '
                'the hidden word.',
            rows: [
              ('words that fit', '$n'),
              ('bits to find', bitsOf(1 / n).toStringAsFixed(2)),
            ],
            note: 'the answer is shown with each guess\'s groups.',
          )
        : CalcSpec(
            metric: 'luck',
            title: 'the luckiest reply',
            intro:
                'the hidden word is fixed. each guess gave it a reply, a group '
                'of words. the smaller the group, the luckier you were.',
            rows: [('words that fit', '$n')],
            note: 'luck is not skill: a poor guess can be lucky.',
          );
  }

  CalcSpec _optionSpec(GuessQuestion q, GuessOption o) {
    final n = q.eligible.length;
    final plot = q.plotOf(o);
    if (q.kind == GuessKind.skill) {
      return CalcSpec(
        metric: 'skill',
        title: o.word,
        intro: '${o.word} splits the $n words into ${o.groups} groups.',
        rows: [
          ('groups', '${o.groups}'),
          ('bits gained on average (H)', o.h.toStringAsFixed(2)),
          ('best H among all guesses', q.bestH.toStringAsFixed(2)),
          ('biggest group', '${o.largest}'),
        ],
        result: ('skill = H ÷ H* × 100', '${o.skill.round()}'),
        plot: plot,
      );
    }
    return CalcSpec(
      metric: 'luck',
      title: o.word,
      intro:
          'the hidden word was ${q.answer}. ${o.word} would have put it in a '
          'group of ${o.landedWords} of $n words.',
      rows: [
        ('group', '${o.landedWords}'),
        ('bits that reply gains', o.bits.toStringAsFixed(2)),
        ('its average gain (H)', o.h.toStringAsFixed(2)),
      ],
      result: ('luck = P(less) − P(more)', luckText(o.luck)),
      plot: plot,
    );
  }

  List<Widget> _body(ColorScheme c) {
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    if (failed) {
      return const [
        Caption('this list has no position to ask about at this length'),
      ];
    }
    final q = question;
    if (q == null) return const [Caption('finding a position…')];
    final p = picked;
    final skill = q.kind == GuessKind.skill;
    final n = q.eligible.length;
    return [
      Caption(skill ? 'pick the best splitter' : 'pick the luckiest guess'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) {
          const gap = 6.0;
          final size = min(44.0, (box.maxWidth - gap * (length - 1)) / length);
          return Row(
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                MarkTile(q.first[i], mark: q.marks[i], size: size),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              '$n words fit. ${skill ? 'which guess splits the rest best?' : 'which guess got the luckiest reply?'}',
              key: const ValueKey('guess-question'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          CalcDot(_questionSpec(q)),
        ],
      ),
      if (!skill) ...[
        const SizedBox(height: 4),
        Text(
          'the hidden word is fixed; all four were played against it.',
          style: dim,
        ),
      ],
      const SizedBox(height: 14),
      for (var i = 0; i < q.options.length; i++) _option(c, q, i, dim),
      if (p != null) ...[
        const SizedBox(height: 6),
        _verdict(c, q, p),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('guess-next'),
          onPressed: _next,
          child: const Text('next ›'),
        ),
      ],
    ];
  }

  Widget _option(ColorScheme c, GuessQuestion q, int i, TextStyle dim) {
    final o = q.options[i];
    final p = picked;
    final word = Text(
      o.word,
      style: TextStyle(fontSize: 20, letterSpacing: 2, color: c.onSurface),
    );
    if (p == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          key: ValueKey('guess-option-$i'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: c.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(),
            side: hairline(c),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _pick(i),
          child: Align(alignment: Alignment.centerLeft, child: word),
        ),
      );
    }
    final isRight = i == q.rightIndex;
    final isPicked = i == p;
    final skill = q.kind == GuessKind.skill;
    final colour = metricColor(c, skill ? 'skill' : 'luck');
    final numbers = skill
        ? '${o.h.toStringAsFixed(2)} bits · ${o.groups} groups · '
              'skill ${o.skill.round()}'
        : 'luck ${luckText(o.luck)} · group of ${o.landedWords} · '
              '${o.bits.toStringAsFixed(2)} bits';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('guess-option-$i'),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: isRight
              ? c.secondaryContainer
              : isPicked
              ? c.errorContainer
              : c.surfaceContainerHighest,
          border: Border.fromBorderSide(
            isRight
                ? BorderSide(color: c.secondary, width: 1.5)
                : isPicked
                ? BorderSide(color: c.error, width: 1.5)
                : hairline(c),
          ),
        ),
        child: Row(
          children: [
            word,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                numbers,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isRight ? FontWeight.bold : null,
                  color: colour,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CalcDot(_optionSpec(q, o)),
          ],
        ),
      ),
    );
  }

  Widget _verdict(ColorScheme c, GuessQuestion q, int p) {
    final right = p == q.rightIndex;
    return Column(
      key: const ValueKey('guess-verdict'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          right ? 'right.' : 'not this one: the best is ${q.right.word}.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: right ? c.secondary : c.error,
          ),
        ),
        if (q.kind == GuessKind.luck)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'the word was ${q.answer}.',
              style: TextStyle(
                fontSize: 12,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ),
      ],
    );
  }
}
