import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis.dart';
import 'logic.dart';
import 'review_plots.dart';
import 'review_text.dart';
import 'ui.dart';
import 'wiki_links.dart';
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
    this.weights,
    this.analysis,
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

  /// The law the answer was drawn by, as weights; null when every possible
  /// word was as likely as the next.
  final Map<String, int>? weights;

  /// The best picks for each guess, if they were already being worked out
  /// while the game was played (null for a guess that needs none).
  final List<Future<Landscape>?>? analysis;

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

  /// How every guess scored, per step, for the skill plot.
  final landscapes = <int, Landscape>{};

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

  /// The metrics of guess [i], with skill measured against the best real guess
  /// once the analysis of that step has found it; until then the skill is
  /// provisional ([GuessMetrics.ready] is false, or measured against 1).
  GuessMetrics metric(int i) => () {
    final m = r.metrics[i];
    final land = landscapes[i];
    return land == null ? m : m.withLandscape(land);
  }();

  /// The chance each of [fits] is the answer: equal, or by the weights of the
  /// law the game drew its answer by.
  List<double> _chances(List<String> fits) {
    final w = r.weights;
    if (w == null) return List.filled(fits.length, 1 / fits.length);
    int weightOf(String x) => max(w[x] ?? 1, 1);
    final total = fits.fold<int>(0, (a, x) => a + weightOf(x));
    return [for (final x in fits) weightOf(x) / total];
  }

  /// Whether the guess at [i] fits every clue given before it: it need not be
  /// one of the words the answer can be (a daily draws from 3,000 only).
  bool _fitsClues(int i) {
    final g = r.guesses[i];
    for (var j = 0; j < i; j++) {
      if (filterEligible([g], r.guesses[j], r.marks[j]).isEmpty) return false;
    }
    return true;
  }

  Future<void> _analyse() async {
    final guessable = r.bank.guessable(r.length);
    for (var i = 0; i < r.guesses.length; i++) {
      final finalTry = _isFinalTry(i);
      if (finalTry) {
        // every possible word, each with its chance; the skill field carries
        // that chance, in percent, since no split matters any more
        final fits = r.befores[i];
        final shares = _chances(fits);
        setState(
          () => picks[i] = [
            for (var k = 0; k < fits.length && k < _listed; k++)
              Recommendation(
                fits[k],
                shares[k] * 100,
                fits.length.toDouble(),
                true,
              ),
          ],
        );
      }
      // every step is scored against every real guess, last try included: the
      // best of them is what skill is measured against
      final ready = r.analysis != null && i < r.analysis!.length
          ? r.analysis![i]
          : null;
      final land =
          await (ready ??
              analyseGuesses(r.befores[i], guessable, weights: r.weights));
      if (!mounted) return;
      setState(() {
        if (!finalTry) picks[i] = land.top;
        landscapes[i] = land;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = r.guesses.length;
    final last = step == n - 1;
    final m = metric(step);
    final top = picks[step];
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
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
                        const SizedBox(height: 10),
                        _formula(c, dim),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final line in [
                                  ...tableHelp,
                                  'words left: the words still possible. '
                                      'info gained: how close you are to one '
                                      'word.',
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      line,
                                      style: dim.copyWith(height: 1.4),
                                    ),
                                  ),
                                reviewLink(
                                  WikiPage.skillLuckDaring,
                                  label: 'how skill, luck and daring work',
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        _picks(c, m, top),
                        const SizedBox(height: 18),
                        ..._quality(c, m),
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
                                  guessFits: _fitsClues(step),
                                  guessIsPossible: m.possible,
                                  equalChances: r.weights == null,
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

  /// "expected tries 4.4 = 9.4 − 3.6 skill + 0.3 luck − 0.8 daring", from the
  /// means of this game, with what it took beside it. Dots until every step
  /// has been analysed (daring needs it). A game with no daring leaves that
  /// term out.
  Widget _formula(ColorScheme c, TextStyle dim) {
    const style = TextStyle(fontSize: 13, height: 1.5);
    final landed = landscapes.length >= r.guesses.length;
    var n = 0, dn = 0;
    var skill = 0.0, luck = 0.0, daring = 0.0;
    if (landed) {
      for (var i = 0; i < r.guesses.length; i++) {
        final m = metric(i);
        if (m.before <= 1) continue;
        skill += m.skill;
        luck += m.luck;
        n++;
        if (m.daring != null) {
          daring += m.daring!;
          dn++;
        }
      }
    }
    // every guess had one word left: nothing was scored, so nothing to add up
    if (landed && n == 0) return const SizedBox();
    final took = r.won ? 'you took ${r.guesses.length}' : 'not solved';
    final List<InlineSpan> spans;
    if (!landed) {
      spans = const [TextSpan(text: 'expected tries …')];
    } else {
      final b = breakdownOf(skill / n, luck / n, dn == 0 ? null : daring / dn);
      TextSpan term(double v, String name, Color color) => TextSpan(
        text: ' ${v < 0 ? '−' : '+'} ${v.abs().toStringAsFixed(1)} $name',
        style: TextStyle(color: color),
      );
      spans = [
        TextSpan(
          text:
              'expected tries ${b.total.toStringAsFixed(1)} = '
              '${b.base.toStringAsFixed(1)}',
        ),
        term(b.skill, 'skill', skillColor(c)),
        term(b.luck, 'luck', luckColor(c)),
        if (dn > 0) term(b.daring, 'daring', daringColor(c)),
        TextSpan(text: ' · $took'),
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: spans),
          key: const ValueKey('expected-tries'),
          style: style,
        ),
        Text(
          'each term is the tries that skill, luck and daring added or took '
          'off, over the whole game.',
          key: const ValueKey('expected-tries-help'),
          style: dim.copyWith(height: 1.4),
        ),
        reviewLink(
          WikiPage.skillLuckDaring,
          label: 'how skill, luck and daring work',
        ),
      ],
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
    const colW = 40.0;
    const gap = 2.0;
    // the highlight of the current row stands off the tiles and the numbers
    const padX = 10.0, padY = 7.0;
    final head = TextStyle(
      fontSize: 9,
      letterSpacing: .4,
      height: 1.2,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    Widget cell(
      String t, {
      bool strong = false,
      bool dimmed = false,
      Color? color,
      Key? key,
    }) => SizedBox(
      width: colW,
      child: Text(
        t,
        key: key,
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
        final area = box.maxWidth - colW * 5 - 8 - padX * 2;
        final tile = min(30.0, (area - gap * (r.length - 1)) / r.length);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: padX),
              child: Row(
                children: [
                  const Spacer(),
                  for (final h in const [
                    'skill',
                    'luck',
                    'daring',
                    'words\nleft',
                    'info\ngained',
                  ])
                    SizedBox(
                      width: colW,
                      child: Text(
                        h,
                        key: ValueKey('head-$h'),
                        textAlign: TextAlign.right,
                        style: switch (h) {
                          'skill' => head.copyWith(color: skillColor(c)),
                          'luck' => head.copyWith(color: luckColor(c)),
                          'daring' => head.copyWith(color: daringColor(c)),
                          _ => head,
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < r.guesses.length; i++) ...[
              // a row is a button: tap it to go to that guess
              InkWell(
                key: ValueKey('row-$i'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => step = i),
                child: Container(
                  decoration: BoxDecoration(
                    color: i == step
                        ? c.primary.withValues(alpha: .08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: padX,
                    vertical: padY,
                  ),
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
                          metric(i).ready
                              ? metric(i).skill.round().toString()
                              : '…',
                          strong: i == step,
                          dimmed: i < step,
                          color: skillColor(c),
                          key: ValueKey('skill-$i'),
                        ),
                        cell(
                          luckText(metric(i).luck),
                          strong: i == step,
                          dimmed: i < step,
                          color: luckColor(c),
                          key: ValueKey('luck-$i'),
                        ),
                        cell(
                          // none when there was no choice (one word left)
                          !metric(i).ready
                              ? '…'
                              : metric(i).daring == null
                              ? '–'
                              : metric(i).daring!.round().toString(),
                          strong: i == step,
                          dimmed: i < step,
                          color: daringColor(c),
                          key: ValueKey('daring-$i'),
                        ),
                        cell(
                          metric(i).after.toString(),
                          strong: i == step,
                          dimmed: i < step,
                        ),
                        cell(
                          '${infoGained(r.initial, metric(i).after).round()}%',
                          strong: i == step,
                          dimmed: i < step,
                        ),
                      ] else
                        for (var k = 0; k < 5; k++) cell('–', dimmed: true),
                    ],
                  ),
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
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final landed = m.landedSize <= m.expected + 1e-9
        ? c.secondary
        : yellowOf(c);

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Caption('the pool'),
          const SizedBox(height: 6),
          Text(
            'The ${m.before} possible words split into ${m.groups} groups; '
            'the biggest held ${m.largest}.',
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
          bar('you landed in', m.landedSize, landed, strong: true),
          if (m.daring != null) ...[
            const SizedBox(height: 6),
            metricLine(
              context,
              !m.possible
                  ? 'daring 0: this guess could not be the answer, so it only '
                        'probed.'
                  : m.triesLeft <= 1
                  ? 'daring 0: with one try left, going for the word is the '
                        'only play.'
                  : 'daring ${m.daring!.round()}: how much you went for the '
                        'word itself rather than the clues.',
              'daring',
              key: const ValueKey('daring-line'),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
          reviewLink(
            WikiPage.skillLuckDaring,
            label: 'how skill, luck and daring work',
          ),
        ],
      ),
    );
  }

  /// The plots of how good the guess was: where it ranked among every guess
  /// I scored (skill) and where among the outcomes it could have had it landed
  /// (luck). On the last try nothing is left to learn, so they give way to one
  /// plot of the words that fit, all equally likely. Nothing to plot when one
  /// word was left.
  List<Widget> _quality(ColorScheme c, GuessMetrics m) {
    final before = r.befores[step];
    if (before.length <= 1) return const [];
    if (_isFinalTry(step)) {
      return [
        EqualChancePlot(
          fitting: before.length,
          guessAt: before.indexOf(m.guess),
          luck: m.luck,
          chances: r.weights == null ? null : _chances(before),
        ),
        const SizedBox(height: 18),
      ];
    }
    final land = landscapes[step];
    return [
      SplitPlot(
        key: ValueKey('split-$step'),
        outcomes: _outcomes.putIfAbsent(
          step,
          () => outcomesOf(before, m.guess, r.answer, weights: r.weights),
        ),
        best: land?.bestExpected ?? m.best,
        skill: m.skill,
        luck: m.luck,
        skillReady: land != null || m.ready,
      ),
      const SizedBox(height: 18),
    ];
  }

  /// The outcomes of each step's guess, worked out when first shown.
  final _outcomes = <int, Outcomes>{};

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
      color: c.onSurface.withValues(alpha: dimAlpha),
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
        // the two ends of the axis on one line, at its two ends
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('most common', style: dim),
            Text('rarest', style: dim),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 2,
          children: [
            if (guessAt >= 0) key(c.primary, 'your guess'),
            if (answerAt >= 0) key(c.secondary, 'the answer'),
          ],
        ),
      ],
    );
  }

  Widget _picks(ColorScheme c, GuessMetrics m, List<Recommendation>? top) {
    final finalTry = _isFinalTry(step);
    final fits = r.befores[step];
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
                style: style.copyWith(color: skillColor(c)),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    final row = Row(
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
                    ? pct(m.winChance * 100) // pool words only
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
                    shown: pct(top[i].skill),
                  ),
                Text(
                  r.weights != null
                      ? (fits.length > top.length
                            ? 'the likeliest of the ${fits.length} words that '
                                  'fit'
                            : 'by how likely each is')
                      : fits.length > top.length
                      ? 'any of the ${fits.length} words that fit, equally '
                            'likely'
                      : 'each equally likely',
                  key: const ValueKey('pick-each'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.onSurface.withValues(alpha: dimAlpha),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        reviewLink(WikiPage.solverAndLearn, label: 'how my picks are chosen'),
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
