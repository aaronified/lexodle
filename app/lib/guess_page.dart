import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'calc_dialog.dart';
import 'guess_quiz.dart';
import 'logic.dart';
import 'main.dart';
import 'typing_keys.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart';
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  PageHeader(
                    text: 'guess the best · $lang · $length',
                    back: true,
                    settings: false,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _body(context, c),
                    ),
                  ),
                ],
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

  /// The words expected to be left after [o]: the words that fit over 2 to the
  /// power of the bits it gains, as the calculation says.
  int _leftOf(GuessQuestion q, GuessOption o) =>
      max(1, (q.eligible.length / pow(2, o.h)).round());

  int _maxLeftOf(GuessQuestion q) =>
      q.options.fold<int>(1, (m, o) => max(m, _leftOf(q, o)));

  /// The colour of one letter of a guess: green right, yellow wrong place, and
  /// the absent grey.
  Color _squareOf(ColorScheme c, Mark m) => switch (m) {
    Mark.correct => c.secondary,
    Mark.present => yellowOf(c),
    Mark.absent => markColors(c, Mark.absent).$1,
  };

  /// A bar of [f] (0 to 1) of the width, on the tone three above the page.
  Widget _bar(BuildContext context, ColorScheme c, double f) {
    final v = f > 1 ? 1.0 : (f < 0 ? 0.0 : f);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: tonesOf(context).s3,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, ColorScheme c) {
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
      TonalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'after '),
                  TextSpan(
                    text: q.first,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' you got'),
                ],
              ),
              style: dim,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _squareOf(c, q.marks[i]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
      SectionLabel(
        p == null ? 'pick one' : 'words left on average after each guess',
      ),
      for (var i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _option(context, c, q, i),
        ),
      if (p != null) ...[
        const SizedBox(height: 4),
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

  Widget _option(BuildContext context, ColorScheme c, GuessQuestion q, int i) {
    final o = q.options[i];
    final p = picked;
    final tones = tonesOf(context);
    final skill = q.kind == GuessKind.skill;
    final isRight = p != null && i == q.rightIndex;
    final isPicked = p != null && i == p;
    final fill = isRight
        ? c.secondaryContainer
        : isPicked
        ? tones.s2
        : tones.s1;
    final ink = isRight ? c.onSecondaryContainer : c.onSurface;
    final tileFill = isPicked && !isRight ? tones.s3 : tones.s2;
    final left = _leftOf(q, o);
    final colour = metricColor(c, skill ? 'skill' : 'luck');
    final numbers = skill
        ? '${o.h.toStringAsFixed(2)} bits · ${o.groups} groups · '
              'skill ${o.skill.round()}'
        : 'luck ${luckText(o.luck)} · group of ${o.landedWords} · '
              '${o.bits.toStringAsFixed(2)} bits';
    return Material(
      key: ValueKey('guess-option-$i'),
      color: fill,
      borderRadius: BorderRadius.circular(radiusContainer),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: p == null ? () => _pick(i) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var k = 0; k < o.word.length; k++) ...[
                        if (k > 0) const SizedBox(width: 6),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tileFill,
                            borderRadius: BorderRadius.circular(radiusElement),
                          ),
                          child: Text(
                            o.word[k],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (p == null)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: c.onSurfaceVariant,
                    )
                  else
                    Text(
                      '$left',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                ],
              ),
              if (p != null) ...[
                const SizedBox(height: 10),
                _bar(context, c, left / _maxLeftOf(q)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        numbers,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isRight ? FontWeight.bold : null,
                          color: isRight ? ink : colour,
                        ),
                      ),
                    ),
                    CalcDot(_optionSpec(q, o)),
                  ],
                ),
              ],
            ],
          ),
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
