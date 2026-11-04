import 'dart:math';

import 'package:flutter/material.dart';

import 'clue.dart';
import 'earned_rows.dart';
import 'learn_log.dart';
import 'store.dart' show Achievement;
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'typing_keys.dart';
import 'ui.dart';
import 'words.dart';

/// Read the clue: a guess and its colours (or counts, in blind), and four
/// words; pick the one that fits every clue. Ten to a round.
class CluePage extends StatefulWidget {
  const CluePage({super.key, required this.bank, this.seed});
  final WordBank bank;

  /// Fixes the positions drawn, for a test.
  final int? seed;

  @override
  State<CluePage> createState() => _CluePageState();
}

class _CluePageState extends State<CluePage> {
  late final _rng = Random(widget.seed);
  late final int length = appState.learnLength;
  late ClueQuestion? question = _next();
  int asked = 1;
  int right = 0;
  int? picked;
  bool done = false;
  List<Achievement> _earned = const [];

  ClueQuestion? _next() => buildClueQuestion(
    bank: widget.bank,
    length: length,
    draw: appState.learnDraw,
    rng: _rng,
  );

  void _pick(int i) {
    final q = question!;
    setState(() {
      picked = i;
      if (i == q.fit) right++;
    });
  }

  void _forward() {
    if (asked >= clueRoundLength) {
      final earned = appState.recordLearn(
        LearnEvent(
          kind: LearnKind.clue,
          language: widget.bank.language.code,
          length: length,
          date: DateTime.now().toIso8601String().substring(0, 10),
          questions: clueRoundLength,
          right: right,
          avgSkill: 100.0 * right / clueRoundLength,
          mode: appState.mode,
        ),
      );
      setState(() {
        done = true;
        _earned = earned;
      });
      return;
    }
    setState(() {
      asked++;
      picked = null;
      question = _next();
    });
  }

  void _again() => setState(() {
    asked = 1;
    right = 0;
    picked = null;
    done = false;
    _earned = const [];
    question = _next();
  });

  Widget _row(
    String word,
    List<Mark> marks,
    double size, {
    bool blind = false,
  }) => Row(
    children: [
      for (var i = 0; i < word.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        MarkTile(word[i], mark: blind ? null : marks[i], size: size),
      ],
      if (blind) ...[
        const SizedBox(width: 12),
        for (final m in [Mark.correct, Mark.present]) ...[
          MarkTile('${marks.where((x) => x == m).length}', mark: m, size: size),
          const SizedBox(width: 2),
        ],
      ],
    ],
  );

  List<Widget> _body(ColorScheme c) {
    final q = question;
    if (q == null) {
      return [const Caption('could not find a position')];
    }
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final blind = appState.mode == GameMode.blind;
    final p = picked;
    return [
      Caption(
        'which ${thingOf(appState.mode, plural: false)} fits every clue?',
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) {
          final slots = length + (blind ? 3 : 0);
          final size = min(44.0, (box.maxWidth - 6.0 * (slots - 1)) / slots);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var g = 0; g < q.guesses.length; g++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _row(q.guesses[g], q.marks[g], size, blind: blind),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            key: ValueKey('clue-option-$i'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              shape: const RoundedRectangleBorder(),
              alignment: Alignment.centerLeft,
              side: BorderSide(
                width: p != null && (i == q.fit || i == p) ? 2 : 1,
                color: p == null
                    ? c.outline
                    : i == q.fit
                    ? c.primary
                    : i == p
                    ? c.error
                    : c.outline,
              ),
            ),
            onPressed: p == null ? () => _pick(i) : null,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                q.options[i],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      if (p != null) ...[
        const SizedBox(height: 6),
        if (p == q.fit)
          Text('yes: it gives every clue.', key: const ValueKey('clue-verdict'))
        else ...[
          Text(
            '${q.options[p]} would give this for ${q.guesses[q.broken(q.options[p])!]}, not the '
            'clue above.',
            key: const ValueKey('clue-verdict'),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              final slots = length + (blind ? 3 : 0);
              final size = min(
                28.0,
                (box.maxWidth - 6.0 * (slots - 1)) / slots,
              );
              final g = q.broken(q.options[p])!;
              return _row(
                q.guesses[g],
                q.would(q.options[p], g),
                size,
                blind: blind,
              );
            },
          ),
        ],
        const SizedBox(height: 4),
        Text('the one that fits is ${q.options[q.fit]}.', style: dim),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('clue-next'),
          onPressed: _forward,
          child: Text(asked >= clueRoundLength ? 'see the result' : 'next'),
        ),
      ],
    ];
  }

  List<Widget> _summary() => [
    Text(
      '$right of $clueRoundLength read right',
      key: const ValueKey('clue-result'),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    if (_earned.isNotEmpty) ...[
      const SizedBox(height: 10),
      EarnedRows(_earned),
    ],
    const SizedBox(height: 14),
    FilledButton(
      key: const ValueKey('clue-again'),
      onPressed: _again,
      child: const Text('another round'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final head = 'read the clue · ${widget.bank.language.name.toLowerCase()}';
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => done
          ? KeyEventResult.ignored
          : handleChoiceKey(
              e,
              count: question?.options.length ?? 0,
              answered: picked != null,
              pick: _pick,
              next: _forward,
            ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TablerIcon('school', size: headerIconSize, color: c.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  done ? head : '$head · $asked of $clueRoundLength',
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
                children: done ? _summary() : _body(c),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
