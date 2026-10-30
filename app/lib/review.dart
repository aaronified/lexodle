import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_worker.dart';
import 'behaviour_popup.dart';
import 'history.dart';
import 'logic.dart';
import 'playstyle.dart';
import 'review_maths.dart';
import 'review_plots.dart';
import 'review_text.dart';
import 'ui.dart';
import 'wiki_links.dart';
import 'words.dart';

/// The icon of a guess type in the review table: smaller than the row, so it
/// never makes the row taller.
const typeIconSize = 16.0;

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
    this.kind,
    this.daily = false,
    this.blind = false,
    this.lockdown = false,
  });

  /// Whether the game was lockdown: only guesses that keep the greens were
  /// allowed, so skill is measured against those.
  final bool lockdown;

  /// Whether the game was blind: its guesses told only how many letters were
  /// right, so the words left and the scores go by those counts.
  final bool blind;

  final WordBank bank;
  final int length;

  /// How the answer was drawn, and whether it was a daily: for the sentences on
  /// the chances in the skill and luck sections. Null when not known.
  final DrawKind? kind;
  final bool daily;

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

/// Steps back through a finished game, one guess at a time: the four numbers of
/// the guess (skill, luck, risk, bits), the board with its table, the plot of
/// how the guess could have come out, three lists of picks side by side, and the
/// bits gained over the game. The alternatives are worked out here, after the
/// game, one step after another.
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
  final _scroll = ScrollController();

  /// Goes to guess [i], and back to the top of the page, as a new page.
  void _go(int i) {
    setState(() => step = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  final picks = <int, List<Recommendation>>{};

  /// How every guess scored, per step.
  final landscapes = <int, Landscape>{};

  /// How common each word the game accepts is (its weight in the list).
  late final Map<String, int> _weight = {
    for (final (i, w) in r.bank.guessable(r.length).indexed)
      w: r.bank.guessWeights(r.length)[i],
  };

  static const _listed = 3;

  /// The last try: there is nothing left to learn from a guess, so only words
  /// that fit the clues are worth naming.
  bool _isFinalTry(int i) => r.tries > 0 && i == r.tries - 1;

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  /// The metrics of guess [i], with skill and risk measured against the best
  /// real guess once the analysis of that step has found it.
  GuessMetrics metric(int i) {
    final m = r.metrics[i];
    final land = landscapes[i];
    return land == null ? m : m.withLandscape(land);
  }

  /// The chance each of [fits] is the answer: equal, or by the weights of the
  /// law the game drew its answer by.
  List<double> _chances(List<String> fits) {
    final w = r.weights;
    if (w == null) return List.filled(fits.length, 1 / fits.length);
    int weightOf(String x) => max(w[x] ?? 1, 1);
    final total = fits.fold<int>(0, (a, x) => a + weightOf(x));
    return [for (final x in fits) weightOf(x) / total];
  }

  /// The bits it takes to find the answer from the start.
  double get _needed {
    final first = r.befores.first;
    final at = first.indexOf(r.answer);
    if (at < 0) return log(max(first.length, 1)) / ln2;
    return bitsOf(_chances(first)[at]);
  }

  Future<void> _analyse() async {
    final guessable = r.bank.guessable(r.length);
    for (var i = 0; i < r.guesses.length; i++) {
      final finalTry = _isFinalTry(i);
      if (finalTry) {
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
      final ready = r.analysis != null && i < r.analysis!.length
          ? r.analysis![i]
          : null;
      final land =
          await (ready ??
              analyseOffThread(
                r.befores[i],
                r.lockdown
                    ? lockedGuesses(
                        guessable,
                        r.guesses.take(i).toList(),
                        r.marks.take(i).toList(),
                      )
                    : guessable,
                weights: r.weights,
                answer: r.answer,
                blind: r.blind,
              ));
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

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyUpEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight && step < n - 1) {
          _go(step + 1);
        } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft && step > 0) {
          _go(step - 1);
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
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(19, 4, 19, 16),
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
                        const SizedBox(height: 14),
                        const Caption('the whole game'),
                        const SizedBox(height: 6),
                        _pills(c),
                        const SizedBox(height: 16),
                        _board(c),
                        const SizedBox(height: 18),
                        ..._quality(c, m),
                        ..._maths(c, m, top),
                        _bits(c, m),
                        const SizedBox(height: 18),
                        _picks(c, m, top),
                        const SizedBox(height: 18),
                        _frequency(c),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 8, 19, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: step == 0 ? null : () => _go(step - 1),
                            child: const Text('back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: last
                                ? () => Navigator.pop(context)
                                : () => _go(step + 1),
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
            onTap: () => _go(i),
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

  /// The four numbers of the guess, each a pill that explains itself on tap.
  Widget _pills(ColorScheme c) {
    final all = [for (var i = 0; i < r.guesses.length; i++) metric(i)];
    final ready = all.every((m) => m.ready);
    double mean(double Function(GuessMetrics) f) =>
        all.fold<double>(0, (a, m) => a + f(m)) / all.length;
    final risks = [
      for (final m in all)
        if (m.risk != null) m.risk!,
    ];
    final skill = mean((m) => m.skill), luck = mean((m) => m.luck);
    final risk = risks.isEmpty
        ? null
        : risks.fold<double>(0, (a, b) => a + b) / risks.length;
    final bits = all.fold<double>(0, (a, m) => a + m.gain);
    Widget pill(String which, String value) => Expanded(
      child: InkWell(
        key: ValueKey('pill-$which'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => showMeasureHelp(context, which),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                value,
                key: ValueKey('pill-value-$which'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: metricColor(c, which),
                ),
              ),
              Text(
                which,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .4,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        pill('skill', ready ? '${skill.round()}' : '…'),
        const SizedBox(width: 8),
        pill('luck', signedLuck(luck)),
        const SizedBox(width: 8),
        pill('risk', !ready ? '…' : (risk == null ? '–' : '${risk.round()}')),
        const SizedBox(width: 8),
        pill('bits', bits.toStringAsFixed(2)),
      ],
    );
  }

  /// A chevron for luck: one for a little, two for a lot, up or down.
  Widget _luckChevrons(ColorScheme c, double luck, bool strong) {
    final a = luck.abs();
    if (a < 10) return const SizedBox(width: 14);
    final name = a >= 50
        ? (luck > 0 ? 'chevrons-up' : 'chevrons-down')
        : (luck > 0 ? 'chevron-up' : 'chevron-down');
    return TablerIcon(name, size: 14, color: luckColor(c));
  }

  /// The board with the table beside it. Guesses after the current step stay
  /// blank, so stepping through gives nothing away.
  Widget _board(ColorScheme c) {
    const wordsW = 36.0, skillW = 32.0, riskW = 46.0, typeW = 30.0;
    const gap = 2.0;
    const padX = 8.0, padY = 7.0;
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
    }) => Text(
      t,
      key: key,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 12,
        fontWeight: strong ? FontWeight.bold : FontWeight.normal,
        color: color != null
            ? (strong ? color : color.withValues(alpha: dimmed ? .5 : .75))
            : strong
            ? c.primary
            : c.onSurface.withValues(alpha: dimmed ? .4 : .55),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final area =
            box.maxWidth - wordsW - skillW - riskW - typeW - 8 - padX * 2;
        final tile = min(30.0, (area - gap * (r.length - 1)) / r.length);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: padX),
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: wordsW,
                    child: Text(
                      'left',
                      textAlign: TextAlign.right,
                      style: head,
                    ),
                  ),
                  SizedBox(
                    width: skillW,
                    child: Text(
                      'skill',
                      key: const ValueKey('head-skill'),
                      textAlign: TextAlign.right,
                      style: head.copyWith(color: skillColor(c)),
                    ),
                  ),
                  SizedBox(
                    width: riskW,
                    child: Text(
                      'risk',
                      key: const ValueKey('head-risk'),
                      textAlign: TextAlign.right,
                      style: head.copyWith(color: riskColor(c)),
                    ),
                  ),
                  SizedBox(
                    width: typeW,
                    child: Text(
                      'type',
                      key: const ValueKey('head-type'),
                      textAlign: TextAlign.right,
                      style: head,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < r.guesses.length; i++) ...[
              InkWell(
                key: ValueKey('row-$i'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => _go(i),
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
                      if (i <= step)
                        ..._rowCells(c, i, wordsW, skillW, riskW, typeW, cell)
                      else ...[
                        SizedBox(width: wordsW, child: cell('–', dimmed: true)),
                        SizedBox(width: skillW, child: cell('–', dimmed: true)),
                        SizedBox(width: riskW, child: cell('–', dimmed: true)),
                        SizedBox(width: typeW, child: cell('–', dimmed: true)),
                      ],
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

  List<Widget> _rowCells(
    ColorScheme c,
    int i,
    double wordsW,
    double skillW,
    double riskW,
    double typeW,
    Widget Function(String, {bool strong, bool dimmed, Color? color, Key? key})
    cell,
  ) {
    final m = metric(i);
    final strong = i == step, dimmed = i < step;
    final b = m.ready ? behaviourOf(guessRowOf(i + 1, m)) : null;
    return [
      SizedBox(
        width: wordsW,
        child: cell(
          '${m.after}',
          strong: strong,
          dimmed: dimmed,
          key: ValueKey('words-$i'),
        ),
      ),
      SizedBox(
        width: skillW,
        child: cell(
          m.ready ? m.skill.round().toString() : '…',
          strong: strong,
          dimmed: dimmed,
          color: skillColor(c),
          key: ValueKey('skill-$i'),
        ),
      ),
      SizedBox(
        width: riskW,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _luckChevrons(c, m.luck, strong),
              const SizedBox(width: 4),
              cell(
                !m.ready
                    ? '…'
                    : (m.risk == null ? '–' : m.risk!.round().toString()),
                strong: strong,
                dimmed: dimmed,
                color: riskColor(c),
                key: ValueKey('risk-$i'),
              ),
            ],
          ),
        ),
      ),
      // the type of the guess, its own column: tap it for what it is. The tap
      // is the icon and no more, so the row is no taller than a row without one
      SizedBox(
        width: typeW,
        child: !m.ready
            ? cell('…', dimmed: true)
            : Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  key: ValueKey('type-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      showBehaviourPopup(context, guessRowOf(i + 1, m)),
                  child: b == null
                      ? cell('·', strong: false, dimmed: true)
                      : TablerIcon(
                          b.icon,
                          size: typeIconSize,
                          color: behaviourColor(
                            c,
                            b.label,
                          ).withValues(alpha: dimmed ? .5 : 1),
                        ),
                ),
              ),
      ),
    ];
  }

  /// The plot of how the guess could have come out. On the last try nothing is
  /// left to learn, so it gives way to one plot of the words that fit. Nothing
  /// to plot when one word was left.
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
    final o = _outcomes.putIfAbsent(
      step,
      () => outcomesOf(before, m.guess, r.answer, r.weights),
    );
    return [
      GainPlot(
        key: ValueKey('gain-$step'),
        outcomes: o.outcomes,
        landed: o.landed,
        expected: m.expectedGain,
        best: land?.bestGain,
        word: m.guess,
      ),
      const SizedBox(height: 18),
    ];
  }

  final _outcomes = <int, ({List<Outcome> outcomes, int landed})>{};

  /// The skill, risk and luck of the guess worked out from the numbers on the
  /// plot, line by line.
  List<Widget> _maths(
    ColorScheme c,
    GuessMetrics m,
    List<Recommendation>? top,
  ) {
    String f1(double v) => v.toStringAsFixed(1);
    String f2(double v) => v.toStringAsFixed(2);
    String pc(double v) => '${f1(v)}%';
    Widget gap(Widget w) =>
        Padding(padding: const EdgeInsets.only(bottom: 18), child: w);
    final land = landscapes[step];
    final before = r.befores[step];
    // the chances the word was drawn by, which skill and luck are worked out
    // under, said once in each section
    final skillNote = r.kind == null
        ? null
        : r.blind
        ? '${skillDrawLine(r.kind!, daily: r.daily)} $blindLine'
        : skillDrawLine(r.kind!, daily: r.daily);
    final luckNote = r.kind == null
        ? null
        : luckDrawLine(r.kind!, daily: r.daily);
    if (before.length <= 1) {
      return [
        gap(
          MeasureBlock(
            title: 'skill',
            which: 'skill',
            tip: blockTips['skill']!,
            rows: const [],
            result: ('skill: one word left, the only play', '100'),
            note: skillNote,
          ),
        ),
        gap(
          MeasureBlock(
            title: 'risk',
            which: 'risk',
            tip: blockTips['risk']!,
            rows: const [],
            result: ('risk: one outcome, no gamble', '–'),
          ),
        ),
        gap(
          MeasureBlock(
            title: 'luck',
            which: 'luck',
            tip: blockTips['luck']!,
            rows: const [],
            result: ('luck: one outcome', '0%'),
            note: luckNote,
          ),
        ),
      ];
    }
    if (_isFinalTry(step)) {
      return [
        gap(
          MeasureBlock(
            title: 'skill',
            which: 'skill',
            tip: blockTips['skill']!,
            rows: [('chance this guess is the answer', pc(m.winChance * 100))],
            result: (
              'skill = chance ÷ best chance × 100',
              '${m.skill.round()}',
            ),
            note: skillNote,
          ),
        ),
        gap(
          MeasureBlock(
            title: 'luck',
            which: 'luck',
            tip: blockTips['luck']!,
            rows: const [],
            result: ('luck = outcome − chance of it', luckText(m.luck)),
            note: luckNote,
          ),
        ),
      ];
    }
    final o = _outcomes
        .putIfAbsent(
          step,
          () => outcomesOf(before, m.guess, r.answer, r.weights),
        )
        .outcomes;
    double share(bool Function(double gain) test) =>
        o.fold<double>(0, (a, x) => a + (test(x.gain) ? x.chance : 0)) * 100;
    final h = m.expectedGain;
    final lessH = share((g) => g < h - 1e-9),
        moreH = share((g) => g > h + 1e-9);
    final lessG = share((g) => g < m.gain - 1e-9);
    final moreG = share((g) => g > m.gain + 1e-9);
    final d = max(0.0, m.rawRisk);
    final bestWord = top == null || top.isEmpty ? '' : ' (${top.first.word})';
    final riskWord = land == null || land.riskiest.isEmpty
        ? ''
        : ' (${land.riskiest.first.word})';
    final side = m.rawRisk > 10
        ? 'Usually less than expected, with a small chance of much more.'
        : m.rawRisk < -10
        ? 'Usually more than expected, with a small chance of much less: no '
              'gamble, so risk is 0.'
        : 'Less and more than expected are about equally likely, so there is '
              'little gamble.';
    final ready = land != null && m.ready;
    final noRisk = m.risk == null;
    return [
      gap(
        MeasureBlock(
          title: 'skill',
          which: 'skill',
          tip: blockTips['skill']!,
          rows: [
            ('expected gain, H = Σ chance × bits', '${f2(h)} bits'),
            (
              'best guess, H*$bestWord',
              ready ? '${f2(land.bestGain)} bits' : '…',
            ),
          ],
          result: (
            ready
                ? 'skill = ${f2(h)} ÷ ${f2(land.bestGain)} × 100'
                : 'skill = H ÷ H* × 100',
            ready ? f1(m.skill) : '…',
          ),
          note: skillNote,
        ),
      ),
      gap(
        MeasureBlock(
          title: 'risk',
          which: 'risk',
          tip: blockTips['risk']!,
          rows: [
            ('chance of less than expected', pc(lessH)),
            ('chance of more than expected', pc(moreH)),
            ('less − more, at least 0', pc(d)),
            ('riskiest guess, D*$riskWord', ready ? pc(land.bestRisk) : '…'),
          ],
          result: noRisk
              ? ('risk: nothing to gamble on', '–')
              : (
                  'risk = ${f1(d)} ÷ ${f1(land?.bestRisk ?? 0)} × 100',
                  f1(m.risk!),
                ),
          note: noRisk ? null : side,
        ),
      ),
      gap(
        MeasureBlock(
          title: 'luck',
          which: 'luck',
          tip: blockTips['luck']!,
          rows: [
            ('chance of gaining less than ${f2(m.gain)} bits', pc(lessG)),
            ('chance of gaining more than ${f2(m.gain)} bits', pc(moreG)),
          ],
          result: ('luck = less − more', luckText(m.luck)),
          note: luckNote,
        ),
      ),
    ];
  }

  /// The bits gained guess by guess, up to the one on show.
  Widget _bits(ColorScheme c, GuessMetrics m) {
    final steps = [
      for (var i = 0; i < r.guesses.length; i++)
        WaterfallStep(
          r.guesses[i],
          metric(i).expectedGain,
          metric(i).gain,
          landscapes[i]?.bestGain,
        ),
    ];
    final far = [for (var i = 0; i <= step; i++) metric(i).gain]
        .fold<double>(0, (a, b) => a + b);
    final lucky = m.gain - m.expectedGain;
    String f2(double v) => v.toStringAsFixed(2);
    String sg(double v) => v < 0 ? '−${f2(-v)}' : '+${f2(v)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeasureBlock(
          title: 'bits gained',
          which: 'bits',
          tip: blockTips['bits']!,
          rows: [
            (
              'this guess: skill + luck',
              '${f2(m.expectedGain)} ${sg(lucky)} = ${f2(m.gain)} bits',
            ),
            (
              'so far, of ${f2(_needed)} needed',
              '${f2(far)} (${(far / _needed * 100).round()}%)',
            ),
          ],
        ),
        const SizedBox(height: 6),
        BitsWaterfall(steps: steps, needed: _needed, current: step),
      ],
    );
  }

  /// How common the words still possible were, most common first, with your
  /// guess and the answer marked where they stand.
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
        _FrequencyPlot(
          words: words,
          series: series,
          guessAt: guessAt,
          answerAt: answerAt,
        ),
        const SizedBox(height: 4),
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

  /// Three lists side by side: the best skill, the highest risk and the
  /// luckiest guess for this answer. The last try lists the likeliest words.
  Widget _picks(ColorScheme c, GuessMetrics m, List<Recommendation>? top) {
    final finalTry = _isFinalTry(step);
    final fits = r.befores[step];
    final land = landscapes[step];
    String pct(double v) =>
        v == 0 ? '0%' : (v < 10 ? '${v.toStringAsFixed(1)}%' : '${v.round()}%');

    Widget column(
      String title,
      String which,
      List<(String, String)> rows, {
      String? info,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .4,
                  color: metricColor(c, which),
                ),
              ),
            ),
            if (info != null) ...[
              const SizedBox(width: 4),
              InfoDot(info, title: title),
            ],
          ],
        ),
        Divider(color: c.outlineVariant),
        if (rows.isEmpty)
          const Caption('…')
        else
          for (final (w, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      w,
                      key: ValueKey('$which-word-$w'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      v,
                      key: ValueKey('$which-value-$w'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: metricColor(c, which),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );

    if (finalTry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column('likeliest', 'skill', [
            if (top != null)
              for (final p in top) (p.word, pct(p.skill)),
          ]),
          Text(
            r.weights != null
                ? 'by how likely each of the ${fits.length} words that fit is'
                : 'each of the ${fits.length} words that fit is equally likely',
            key: const ValueKey('pick-each'),
            style: TextStyle(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
      );
    }
    final best = land?.bestRisk ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: column('best skill', 'skill', [
                if (top != null)
                  for (final p in top) (p.word, '${p.skill.round()}'),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: column('top risk', 'risk', [
                if (land != null)
                  for (final p in land.riskiest)
                    (
                      p.word,
                      best <= 0 ? '0' : '${(p.raw / best * 100).round()}',
                    ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: column('luckiest', 'luck', [
                if (land != null)
                  for (final p in land.luckiest) (p.word, signedLuck(p.luck)),
              ]),
            ),
          ],
        ),
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
    required this.hoverColor,
    this.hover = -1,
  });
  final List<double> series;
  final bool bars;
  final int guessAt, answerAt;
  final Color base, guess, answer, axis, hoverColor;

  /// The word the pointer is on, or -1.
  final int hover;

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
          Paint()..color = i == hover ? hoverColor : colorOf(i),
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
    for (final i in [guessAt, answerAt, hover]) {
      if (i < 0) continue;
      final x = n == 1 ? 0.0 : i / (n - 1) * size.width;
      canvas.drawLine(
        Offset(x, size.height - h(series[i])),
        Offset(x, size.height),
        Paint()
          ..color = i == hover ? hoverColor : colorOf(i)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x, size.height - h(series[i])),
        3,
        Paint()..color = i == hover ? hoverColor : colorOf(i),
      );
    }
  }

  @override
  bool shouldRepaint(_FrequencyPainter old) =>
      old.series != series ||
      old.guessAt != guessAt ||
      old.answerAt != answerAt ||
      old.hover != hover ||
      old.hoverColor != hoverColor ||
      old.bars != bars;
}

/// The plot of the words still possible, by how common, that tells the word
/// under the pointer: hover with a mouse, or touch and drag along it. The word
/// is lit in the plot and named in a tooltip above it.
class _FrequencyPlot extends StatefulWidget {
  const _FrequencyPlot({
    required this.words,
    required this.series,
    required this.guessAt,
    required this.answerAt,
  });

  /// The words, most common first, and the height of each in the plot.
  final List<String> words;
  final List<double> series;
  final int guessAt, answerAt;

  @override
  State<_FrequencyPlot> createState() => _FrequencyPlotState();
}

class _FrequencyPlotState extends State<_FrequencyPlot> {
  int _hover = -1;
  Timer? _fade;

  @override
  void didUpdateWidget(_FrequencyPlot old) {
    super.didUpdateWidget(old);
    if (old.words != widget.words) _hover = -1;
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  bool get _bars => widget.words.length <= 60;

  /// The word at [dx] in a plot [width] wide, as the painter lays them out.
  int _at(double dx, double width) {
    final n = widget.words.length;
    if (n == 0 || width <= 0) return -1;
    if (_bars) return (dx / (width / n)).floor().clamp(0, n - 1);
    return n == 1 ? 0 : (dx / width * (n - 1)).round().clamp(0, n - 1);
  }

  void _point(Offset local, double width) {
    _fade?.cancel();
    final i = _at(local.dx, width);
    if (i != _hover) setState(() => _hover = i);
  }

  /// A mouse leaves at once; a finger lifted leaves the word named a moment.
  void _leave({bool soon = false}) {
    _fade?.cancel();
    if (soon) {
      _fade = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _hover = -1);
      });
    } else if (_hover != -1) {
      setState(() => _hover = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = widget.words.length;
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          // where the lit word stands, to put the tooltip over it
          double xOf(int i) => _bars
              ? (i + .5) * width / n
              : (n == 1 ? 0.0 : i / (n - 1) * width);
          final i = _hover;
          return MouseRegion(
            onHover: (e) => _point(e.localPosition, width),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _point(d.localPosition, width),
              onTapUp: (_) => _leave(soon: true),
              onTapCancel: () => _leave(soon: true),
              onHorizontalDragStart: (d) => _point(d.localPosition, width),
              onHorizontalDragUpdate: (d) => _point(d.localPosition, width),
              onHorizontalDragEnd: (_) => _leave(soon: true),
              onHorizontalDragCancel: () => _leave(soon: true),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('freq-plot'),
                      painter: _FrequencyPainter(
                        widget.series,
                        bars: _bars,
                        guessAt: widget.guessAt,
                        answerAt: widget.answerAt,
                        hover: i,
                        base: c.onSurface.withValues(alpha: .3),
                        guess: c.primary,
                        answer: c.secondary,
                        axis: c.outlineVariant,
                        hoverColor: c.onSurface,
                      ),
                    ),
                  ),
                  if (i >= 0 && i < n)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -30,
                      child: IgnorePointer(
                        // over the word, held inside the plot at either end
                        child: Align(
                          alignment: Alignment(
                            (xOf(i) / width * 2 - 1).clamp(-1.0, 1.0),
                            0,
                          ),
                          child: Container(
                            key: const ValueKey('freq-tooltip'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.surface,
                              border: Border.all(color: c.outline),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              i == widget.answerAt
                                  ? '${widget.words[i]} · the answer'
                                  : i == widget.guessAt
                                  ? '${widget.words[i]} · your guess'
                                  : widget.words[i],
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
