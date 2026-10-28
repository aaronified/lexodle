import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'review_text.dart';
import 'ui.dart';
import 'wiki_links.dart';
import 'words.dart';

/// Everything the review needs about one finished quartet or relay race.
class MultiRecord {
  const MultiRecord({
    required this.bank,
    required this.mode,
    required this.length,
    required this.tries,
    required this.answers,
    required this.guesses,
    required this.steps,
    required this.won,
    this.weights,
    this.analysis,
  });

  final WordBank bank;
  final GameMode mode;
  final int length;
  final int tries;
  final List<String> answers;
  final List<String> guesses;
  final List<MultiStep> steps;
  final bool won;

  /// The law the answers were drawn by, as weights; null for equal chances.
  final Map<String, int>? weights;

  /// The best picks for each step, if they were already being worked out while
  /// the game was played (null for a step whose picks are not needed, such as
  /// the last try's).
  final List<Future<MultiLandscape>?>? analysis;
}

String _n(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// Steps back through a quartet or a relay race one guess at a time: what the
/// guess did to every board it was made for, how it scored (see
/// multi_analysis.dart for the maths), and what the best guess would have been.
class MultiReviewPage extends StatefulWidget {
  const MultiReviewPage({
    super.key,
    required this.record,
    this.initialStep = 0,
  });
  final MultiRecord record;
  final int initialStep;

  @override
  State<MultiReviewPage> createState() => _MultiReviewPageState();
}

class _MultiReviewPageState extends State<MultiReviewPage> {
  MultiRecord get r => widget.record;
  late int step = widget.initialStep.clamp(0, r.steps.length - 1);
  bool explain = false;
  final picks = <int, List<MultiPick>>{};

  /// What the analysis of each step found: the best real split per board, which
  /// each board's skill is measured against, and the picks.
  final landscapes = <int, MultiLandscape>{};
  final finals = <int, List<FinalPick>>{};

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  /// Step [i] with each board's skill measured against its best real guess,
  /// once the analysis has found it; until then as the game had it.
  MultiStep stepAt(int i) {
    final land = landscapes[i];
    return land == null ? r.steps[i] : r.steps[i].withBests(land.bests);
  }

  Future<void> _analyse() async {
    final guessable = r.bank.guessable(r.length);
    for (var i = 0; i < r.steps.length; i++) {
      final s = r.steps[i];
      if (s.finalTry) {
        // nothing is left to learn: only words that fit a board can win
        setState(
          () => finals[i] = finalPicks(s.liveBefore, weights: r.weights),
        );
      }
      // every step is scored against every real guess, the last try included:
      // the best of them is what skill is measured against
      final ready = r.analysis != null && i < r.analysis!.length
          ? r.analysis![i]
          : null;
      final land =
          await (ready ??
              analyseMulti(s.liveBefore, guessable, weights: r.weights));
      if (!mounted) return;
      setState(() {
        if (!s.finalTry) picks[i] = land.picks;
        landscapes[i] = land;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = r.steps.length;
    final s = stepAt(step);
    final last = step == n - 1;
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
          title: Text(
            'review · ${r.mode.label}',
            style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
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
                        Caption(s.guess),
                        const SizedBox(height: 16),
                        _guessList(c, dim),
                        const SizedBox(height: 18),
                        _table(c, s, dim),
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
                                for (final line in _explanation)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      line,
                                      style: dim.copyWith(height: 1.4),
                                    ),
                                  ),
                                reviewLink(
                                  WikiPage.skillLuckRisk,
                                  label: 'how skill, luck and daring work',
                                ),
                              ],
                            ),
                          ),
                        ..._opened(c, s),
                        const SizedBox(height: 14),
                        _picks(c, s),
                        const SizedBox(height: 18),
                        Text(
                          _comment(s),
                          key: const ValueKey('multi-comment'),
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

  /// What the table means, one short line each.
  List<String> get _explanation => [
    'words left: the words still possible on that board, before and after.',
    ...tableHelp,
    if (r.mode == GameMode.quartet)
      'all: the average over the boards, bigger boards counting more.'
    else
      'a relay guess is judged on the board that is on.',
    'last try: luck is how the pick turned out against its chance.',
    if (r.mode == GameMode.relay)
      'head start: a board opens with earlier guesses already applied.',
  ];

  String _comment(MultiStep s) {
    final top = picks[step];
    final fin = finals[step];
    return multiComment(
      s,
      bestWord: top == null || top.isEmpty ? null : top.first.word,
      bestSkill: top == null || top.isEmpty ? null : top.first.skill,
      ready: s.finalTry ? fin != null : top != null,
      bestSolved: fin == null || fin.isEmpty ? null : fin.first.expectedSolved,
      bestFinalWord: fin == null || fin.isEmpty ? null : fin.first.word,
      yourSolved: s.finalTry
          ? expectedSolved(s.liveBefore, s.guess, weights: r.weights)
          : null,
    );
  }

  Widget _progress(ColorScheme c, int n) => Row(
    children: [
      for (var i = 0; i < n; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => step = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 4,
                color: i == step ? c.primary : c.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    ],
  );

  /// Every guess of the game, one row each, current one marked. A row is a
  /// button: tap it to go to that guess, as with next and back.
  Widget _guessList(ColorScheme c, TextStyle dim) {
    Widget cell(String t, {double? w, TextStyle? style, TextAlign? align}) {
      final text = Text(t, style: style, textAlign: align);
      return w == null
          ? Expanded(child: text)
          : SizedBox(width: w, child: text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            cell('guess', style: dim),
            cell('solved', w: 56, align: TextAlign.right, style: dim),
            cell(
              'skill',
              w: 48,
              align: TextAlign.right,
              style: dim.copyWith(color: skillColor(c)),
            ),
            cell(
              'luck',
              w: 60,
              align: TextAlign.right,
              style: dim.copyWith(color: luckColor(c)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < r.steps.length; i++)
          InkWell(
            key: ValueKey('guess-row-$i'),
            onTap: () => setState(() => step = i),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: i == step
                    ? c.primary.withValues(alpha: .08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                children: [
                  cell(
                    '${i + 1}  ${stepAt(i).guess}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: i == step
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == step ? c.primary : null,
                    ),
                  ),
                  cell(
                    stepAt(i).solvedNow == 0 ? '–' : '${stepAt(i).solvedNow}',
                    w: 56,
                    align: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: stepAt(i).solvedNow == 0 ? null : c.secondary,
                    ),
                  ),
                  cell(
                    stepAt(i).ready ? '${stepAt(i).skill.round()}' : '…',
                    w: 48,
                    align: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: skillColor(c)),
                  ),
                  cell(
                    luckText(stepAt(i).luck),
                    w: 60,
                    align: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: luckColor(c)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// One row for every board the guess was made for, then the combined line.
  Widget _table(ColorScheme c, MultiStep s, TextStyle dim) {
    Widget cell(String t, {double? w, TextStyle? style, TextAlign? align}) {
      final text = Text(t, style: style, textAlign: align);
      return w == null
          ? Expanded(child: text)
          : SizedBox(width: w, child: text);
    }

    Widget row(
      String board,
      String left,
      double skill,
      double luck, {
      bool strong = false,
      Color? leftColor,
    }) {
      final base = TextStyle(
        fontSize: 13,
        fontWeight: strong ? FontWeight.bold : FontWeight.normal,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            cell(board, w: 44, style: base),
            cell(left, style: base.copyWith(color: leftColor)),
            cell(
              '${skill.round()}',
              w: 52,
              align: TextAlign.right,
              style: base.copyWith(color: skillColor(c)),
            ),
            cell(
              luckText(luck),
              w: 64,
              align: TextAlign.right,
              style: base.copyWith(color: luckColor(c)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            cell('board', w: 44, style: dim),
            cell('words left', style: dim),
            cell(
              'skill',
              w: 52,
              align: TextAlign.right,
              style: dim.copyWith(color: skillColor(c)),
            ),
            cell(
              'luck',
              w: 64,
              align: TextAlign.right,
              style: dim.copyWith(color: luckColor(c)),
            ),
          ],
        ),
        Divider(color: c.outlineVariant),
        for (final b in s.boards)
          row(
            '${b.board + 1}',
            b.solved
                ? 'solved'
                : '${_n(b.metrics.before)} → ${_n(b.metrics.after)}',
            b.metrics.skill,
            b.metrics.luck,
            leftColor: b.solved ? c.secondary : null,
          ),
        if (s.boards.length > 1) ...[
          Divider(color: c.outlineVariant),
          row(
            'all',
            '${s.boards.length} boards',
            s.skill,
            s.luck,
            strong: true,
          ),
        ],
      ],
    );
  }

  /// Relay race: the boards that opened after this guess, and what they began
  /// with.
  List<Widget> _opened(ColorScheme c, MultiStep s) => [
    for (final h in s.opened)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'board ${h.board + 1} opened with '
          '${h.words == 1 ? 'one word' : '${_n(h.words)} words'} possible of '
          '${_n(h.total)}: earlier guesses cut '
          '${h.cut.toStringAsFixed(h.cut >= 99.9 ? 2 : 0)}%'
          '${r.guesses.take(h.opensAfter).contains(r.answers[h.board]) ? ' and solved it' : ''}.',
          key: ValueKey('opened-${h.board}'),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: c.onSurface.withValues(alpha: .85),
          ),
        ),
      ),
  ];

  Widget _picks(ColorScheme c, MultiStep s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pickRows(c, s),
      reviewLink(WikiPage.solverAndLearn, label: 'how my picks are chosen'),
    ],
  );

  Widget _pickRows(ColorScheme c, MultiStep s) {
    final fin = s.finalTry;
    final top = picks[step];
    final finalTop = finals[step];
    final ready = fin ? finalTop != null : top != null;

    Widget line(String word, String value, {bool big = false, String? key}) {
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
                key: key == null ? null : ValueKey('$key-word-$word'),
                style: style,
                textAlign: key == 'yours' ? TextAlign.left : TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(
                value,
                key: key == null ? null : ValueKey('$key-value-$word'),
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
              Caption(fin ? 'your guess · boards' : 'your guess'),
              Divider(color: c.outlineVariant),
              line(
                s.guess,
                fin
                    ? expectedSolved(
                        s.liveBefore,
                        s.guess,
                        weights: r.weights,
                      ).toStringAsFixed(2)
                    : '${s.skill.round()}',
                big: true,
                key: 'yours',
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
                child: Caption(fin ? 'my picks · boards' : 'my picks'),
              ),
              Divider(color: c.outlineVariant),
              if (!ready)
                const Caption('working it out…')
              else if (fin)
                for (var i = 0; i < finalTop!.length; i++)
                  line(
                    finalTop[i].word,
                    finalTop[i].expectedSolved.toStringAsFixed(2),
                    big: i == 0,
                    key: 'pick',
                  )
              else
                for (var i = 0; i < top!.length; i++)
                  line(
                    top[i].word,
                    '${top[i].skill.round()}',
                    big: i == 0,
                    key: 'pick',
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
