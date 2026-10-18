import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic.dart';
import 'ui.dart';
import 'words.dart';

/// Everything the review needs about one finished game.
class GameRecord {
  const GameRecord({
    required this.bank,
    required this.length,
    required this.poolSize,
    required this.answer,
    required this.guesses,
    required this.marks,
    required this.metrics,
    required this.befores,
    required this.finalEligible,
    required this.won,
    this.tries = 0,
  });

  final WordBank bank;
  final int length;

  /// The answer pool this game was played with.
  final int poolSize;
  final String answer;
  final List<String> guesses;
  final List<List<Mark>> marks;
  final List<GuessMetrics> metrics;

  /// The words still possible before each guess.
  final List<List<String>> befores;

  /// The words still possible after the last guess.
  final List<String> finalEligible;
  final bool won;

  /// How many tries the game allowed (0 when not known).
  final int tries;

  int get initial => befores.first.length;
  List<String> afterOf(int i) =>
      i + 1 < befores.length ? befores[i + 1] : finalEligible;
}

/// Steps back through a finished game, one guess at a time, in the manner of
/// WordleBot's review: the board with a skill / luck / words left / info
/// gained table, your guess beside the best picks, and a short reading of the
/// step. The alternatives are worked out here, after the game, one step after
/// another.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.record, this.initialStep = 0});
  final GameRecord record;
  final int initialStep;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  GameRecord get r => widget.record;
  late int step = widget.initialStep.clamp(0, r.guesses.length - 1);
  bool explain = false;
  final picks = <int, List<Recommendation>>{};

  /// How common each word the game accepts is (its weight in the list).
  late final Map<String, int> _weight = {
    for (final (i, w) in r.bank.guessable(r.length).indexed)
      w: r.bank.guessWeights(r.length)[i],
  };

  /// How many picks are named, as on every other step.
  static const _listed = 3;

  /// The last try: there is nothing left to learn from a guess, so only words
  /// that fit the clues are worth naming.
  bool _isFinalTry(int i) => r.tries > 0 && i == r.tries - 1;

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  Future<void> _analyse() async {
    final guessable = r.bank.guessable(r.length);
    for (var i = 0; i < r.guesses.length; i++) {
      if (_isFinalTry(i)) {
        // every possible word, equally likely; the skill field carries that
        // chance, in percent, since no split matters any more
        final fits = r.befores[i];
        setState(
          () => picks[i] = [
            for (final w in fits.take(_listed))
              Recommendation(
                w,
                100 / fits.length,
                fits.length.toDouble(),
                true,
              ),
          ],
        );
        continue;
      }
      final top = await recommendTop(
        r.befores[i],
        recommendationCandidates(r.befores[i], guessable),
      );
      if (!mounted) return;
      setState(() => picks[i] = top);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = r.guesses.length;
    final last = step == n - 1;
    final m = r.metrics[step];
    final top = picks[step];
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: .6),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyUpEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight && step < n - 1) {
          setState(() => step++);
        } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft && step > 0) {
          setState(() => step--);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'review',
            style: TextStyle(fontSize: 14, letterSpacing: 1.5),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      children: [
                        _progress(c, n),
                        const SizedBox(height: 22),
                        Text(
                          'your ${ordinal(step + 1)} guess',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Caption('the word was ${r.answer}'),
                        const SizedBox(height: 16),
                        _board(c),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => setState(() => explain = !explain),
                          child: Text(
                            explain ? 'hide explanation' : 'explain this table',
                            style: TextStyle(color: c.primary),
                          ),
                        ),
                        if (explain)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'skill: how well the guess split the words that were '
                              'still possible. 100 is a perfect split, 0 tells you '
                              'nothing.\n'
                              'luck: how much smaller (+, green) or larger (-, red) than '
                              'average the pool you landed in was. 0% is exactly '
                              'average, which is also what it is when only one '
                              'word was left.\n'
                              'words left: the words still possible afterwards.\n'
                              'info gained: the share of the starting uncertainty '
                              'removed so far. It reaches 100% when one word is left.',
                              style: dim.copyWith(height: 1.5),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _picks(c, m, top),
                        const SizedBox(height: 18),
                        _frequency(c),
                        const SizedBox(height: 18),
                        if (!_isFinalTry(step)) _pool(c, m, top),
                        Text(
                          top == null
                              ? 'Working out the alternatives…'
                              : stepComment(
                                  m: m,
                                  picks: top,
                                  after: r.afterOf(step),
                                  solved: r.guesses[step] == r.answer,
                                  finalTry: _isFinalTry(step),
                                  guessFits: r.befores[step].contains(
                                    r.guesses[step],
                                  ),
                                ),
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: step == 0
                                ? null
                                : () => setState(() => step--),
                            child: const Text('back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: last
                                ? () => Navigator.pop(context)
                                : () => setState(() => step++),
                            child: Text(last ? 'done' : 'next'),
                          ),
                        ),
                      ],
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

  /// One segment per guess, the current one in the accent colour; tap to jump.
  Widget _progress(ColorScheme c, int n) => Row(
    children: [
      for (var i = 0; i < n; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => step = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i == step
                      ? c.primary
                      : (i < step
                            ? c.onSurface.withValues(alpha: .45)
                            : c.outlineVariant),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );

  /// The board with the table beside it. Guesses after the current step stay
  /// blank, so stepping through gives nothing away.
  Widget _board(ColorScheme c) {
    const colW = 46.0;
    const gap = 2.0;
    final head = TextStyle(
      fontSize: 10,
      letterSpacing: .8,
      height: 1.2,
      color: c.onSurface.withValues(alpha: .6),
    );
    Widget cell(
      String t, {
      bool strong = false,
      bool dimmed = false,
      Color? color,
    }) => SizedBox(
      width: colW,
      child: Text(
        t,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.bold : FontWeight.normal,
          color: color != null
              ? (strong ? color : color.withValues(alpha: dimmed ? .5 : .75))
              : strong
              ? c.primary
              : c.onSurface.withValues(alpha: dimmed ? .4 : .55),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final area = box.maxWidth - colW * 4 - 8;
        final tile = min(30.0, (area - gap * (r.length - 1)) / r.length);
        return Column(
          children: [
            Row(
              children: [
                const Spacer(),
                for (final h in const [
                  'skill',
                  'luck',
                  'words\nleft',
                  'info\ngained',
                ])
                  SizedBox(
                    width: colW,
                    child: Text(h, textAlign: TextAlign.right, style: head),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < r.guesses.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    for (var k = 0; k < r.length; k++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: k < r.length - 1 ? gap : 0,
                        ),
                        child: i <= step
                            ? MarkTile(
                                r.guesses[i][k],
                                mark: r.marks[i][k],
                                size: tile,
                              )
                            : MarkTile('', size: tile),
                      ),
                    const Spacer(),
                    if (i <= step) ...[
                      cell(
                        r.metrics[i].skill.round().toString(),
                        strong: i == step,
                        dimmed: i < step,
                      ),
                      cell(
                        luckText(r.metrics[i].luck),
                        strong: i == step,
                        dimmed: i < step,
                        color: luckColor(c, r.metrics[i].luck),
                      ),
                      cell(
                        r.metrics[i].after.toString(),
                        strong: i == step,
                        dimmed: i < step,
                      ),
                      cell(
                        '${infoGained(r.initial, r.metrics[i].after).round()}%',
                        strong: i == step,
                        dimmed: i < step,
                      ),
                    ] else
                      for (var k = 0; k < 4; k++) cell('–', dimmed: true),
                  ],
                ),
              ),
              if (i < r.guesses.length - 1)
                Divider(
                  height: 1,
                  color: c.outlineVariant.withValues(alpha: .5),
                ),
            ],
          ],
        );
      },
    );
  }

  /// How the guess divided the pool of possible words, and how the pool you
  /// landed in compares with the average one for that guess.
  Widget _pool(ColorScheme c, GuessMetrics m, List<Recommendation>? top) {
    if (m.before <= 1) return const SizedBox();
    String fmt(double v) =>
        v < 10 ? v.toStringAsFixed(1) : v.round().toString();
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: .6),
    );
    final landed = m.after <= m.expected + 1e-9 ? c.secondary : yellowOf(c);

    Widget bar(String label, double value, Color color, {bool strong = false}) {
      final frac = (value / m.before).clamp(0.015, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              child: Text(
                label,
                style: strong
                    ? const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                    : dim,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: box.maxWidth * frac,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                fmt(value),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final pct = m.luck.abs().round();
    final String landing = pct < 1
        ? 'You landed in an average-sized pool for this guess.'
        : m.luck > 0
        ? 'You landed in a pool $pct% smaller than the average for '
              'this guess.'
        : 'You landed in a pool $pct% larger than the average for '
              'this guess.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Caption('the pool'),
          const SizedBox(height: 6),
          Text(
            'Your guess split the ${m.before} possible words into ${m.groups} '
            'groups; the biggest held ${m.largest}.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          bar(
            'before your guess',
            m.before.toDouble(),
            c.onSurface.withValues(alpha: .25),
          ),
          bar('expected after', m.expected, c.onSurface.withValues(alpha: .5)),
          if (top != null && top.isNotEmpty)
            bar(
              'best pick expects',
              top.first.expected,
              c.primary.withValues(alpha: .8),
            ),
          bar('you landed in', m.after.toDouble(), landed, strong: true),
          ...[
            const SizedBox(height: 6),
            Text(landing, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  /// How common the words still possible were, most common first, with your
  /// guess and the answer marked where they stand. Heights are on a log scale
  /// (how common a word is spans orders of magnitude) shared by every step, so
  /// the shape can be compared as the pool shrinks.
  Widget _frequency(ColorScheme c) {
    final words = r.befores[step];
    if (words.isEmpty) return const SizedBox();
    final series = frequencySeries(words, _weight, _weight.values);
    final guessAt = words.indexOf(r.guesses[step]);
    final answerAt = words.indexOf(r.answer);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: .6),
    );
    Widget key(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: dim),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption('the ${words.length} possible words, by how common'),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('freq-plot'),
            painter: _FrequencyPainter(
              series,
              bars: words.length <= 60,
              guessAt: guessAt,
              answerAt: answerAt,
              base: c.onSurface.withValues(alpha: .3),
              guess: c.primary,
              answer: c.secondary,
              axis: c.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text('most common', style: dim),
            if (guessAt >= 0) key(c.primary, 'your guess'),
            if (answerAt >= 0) key(c.secondary, 'the answer'),
            Text('rarest', style: dim),
          ],
        ),
      ],
    );
  }

  Widget _picks(ColorScheme c, GuessMetrics m, List<Recommendation>? top) {
    final finalTry = _isFinalTry(step);
    final fits = r.befores[step];
    final chance = fits.isEmpty ? 0.0 : 100 / fits.length;
    String pct(double v) =>
        v == 0 ? '0%' : (v < 10 ? '${v.toStringAsFixed(1)}%' : '${v.round()}%');
    // Two real columns: the words share one edge, and the skill sits in a
    // fixed-width column of its own, whatever size the line is set in.
    Widget line(
      String word,
      double skill, {
      bool big = false,
      bool wordRight = false,
      String keys = 'pick',
      String? shown,
    }) {
      final style = TextStyle(
        fontSize: big ? 20 : 15,
        fontWeight: big ? FontWeight.bold : FontWeight.normal,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                word,
                key: ValueKey('$keys-word-$word'),
                style: style,
                textAlign: wordRight ? TextAlign.right : TextAlign.left,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              child: Text(
                shown ?? '${skill.round()}',
                key: ValueKey('$keys-skill-$word'),
                style: style.copyWith(color: c.primary),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Caption('your guess'),
              Divider(color: c.outlineVariant),
              line(
                m.guess,
                m.skill,
                big: true,
                keys: 'yours',
                shown: finalTry
                    ? pct(
                        fits.contains(m.guess) ? chance : 0,
                      ) // pool words only
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: const Caption('my picks'),
              ),
              Divider(color: c.outlineVariant),
              if (top == null)
                const Caption('working it out…')
              else if (finalTry) ...[
                for (var i = 0; i < top.length; i++)
                  line(
                    top[i].word,
                    top[i].skill,
                    big: i == 0,
                    wordRight: true,
                    shown: pct(chance),
                  ),
                Text(
                  fits.length > top.length
                      ? 'any of the ${fits.length} words that fit, equally '
                            'likely'
                      : 'each equally likely',
                  key: const ValueKey('pick-each'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.onSurface.withValues(alpha: .6),
                  ),
                ),
              ] else
                for (var i = 0; i < top.length; i++)
                  line(top[i].word, top[i].skill, big: i == 0, wordRight: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// The heights of the plot for [words] (most common first): each word's
/// log-weight scaled to 0..1 between the rarest and the most common word of
/// [all], the weights of the whole pool, so that every step shares one scale.
/// A word missing from [weights] counts as the rarest.
List<double> frequencySeries(
  List<String> words,
  Map<String, int> weights,
  Iterable<int> all,
) {
  double lg(int w) => log(max(w, 1)) / ln10;
  final lo = all.isEmpty ? 0.0 : all.map(lg).reduce(min);
  final hi = all.isEmpty ? 1.0 : all.map(lg).reduce(max);
  final span = hi - lo;
  return [
    for (final w in words)
      span <= 0
          ? 1.0
          : ((lg(weights[w] ?? 1) - lo) / span).clamp(0.0, 1.0).toDouble(),
  ];
}

class _FrequencyPainter extends CustomPainter {
  _FrequencyPainter(
    this.series, {
    required this.bars,
    required this.guessAt,
    required this.answerAt,
    required this.base,
    required this.guess,
    required this.answer,
    required this.axis,
  });
  final List<double> series;
  final bool bars;
  final int guessAt, answerAt;
  final Color base, guess, answer, axis;

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.length;
    if (n == 0) return;
    // a floor, so the rarest word still shows as a sliver
    double h(double v) => (0.06 + 0.94 * v) * size.height;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    Color colorOf(int i) => i == answerAt
        ? answer
        : i == guessAt
        ? guess
        : base;
    if (bars) {
      final slot = size.width / n;
      final w = max(1.0, slot * .7);
      for (var i = 0; i < n; i++) {
        final x = slot * i + (slot - w) / 2;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - h(series[i]), w, h(series[i])),
          Paint()..color = colorOf(i),
        );
      }
      return;
    }
    // many words: an area, one column per pixel pair, the marks as lines
    final cols = max(2, (size.width / 2).floor());
    final path = Path()..moveTo(0, size.height);
    for (var k = 0; k < cols; k++) {
      final i = (k / (cols - 1) * (n - 1)).round();
      path.lineTo(k / (cols - 1) * size.width, size.height - h(series[i]));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = base);
    for (final i in [guessAt, answerAt]) {
      if (i < 0) continue;
      final x = n == 1 ? 0.0 : i / (n - 1) * size.width;
      canvas.drawLine(
        Offset(x, size.height - h(series[i])),
        Offset(x, size.height),
        Paint()
          ..color = colorOf(i)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x, size.height - h(series[i])),
        3,
        Paint()..color = colorOf(i),
      );
    }
  }

  @override
  bool shouldRepaint(_FrequencyPainter old) =>
      old.series != series ||
      old.guessAt != guessAt ||
      old.answerAt != answerAt ||
      old.bars != bars;
}
