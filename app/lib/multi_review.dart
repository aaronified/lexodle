import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'ui.dart';
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

  /// The best picks for each step, if they were already being worked out while
  /// the game was played (null for a step whose picks are not needed, such as
  /// the last try's).
  final List<Future<List<MultiPick>>?>? analysis;
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
  final finals = <int, List<FinalPick>>{};

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  Future<void> _analyse() async {
    final guessable = r.bank.guessable(r.length);
    for (var i = 0; i < r.steps.length; i++) {
      final s = r.steps[i];
      if (s.finalTry) {
        // nothing is left to learn: only words that fit a board can win
        setState(() => finals[i] = finalPicks(s.liveBefore));
        continue;
      }
      final ready = r.analysis != null && i < r.analysis!.length
          ? r.analysis![i]
          : null;
      final top =
          await (ready ??
              recommendMulti(
                s.liveBefore,
                multiCandidates(s.liveBefore, guessable),
              ));
      if (!mounted) return;
      setState(() => picks[i] = top);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = r.steps.length;
    final s = r.steps[step];
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
                            child: Text(
                              _explanation,
                              style: dim.copyWith(height: 1.5),
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

  String get _explanation =>
      'words left: the words still possible on that board, before and after '
      'your guess. a board you solved says so.\n'
      'skill: for one board, how well the guess split its possible words: '
      '100 is a perfect split, 0 tells you nothing. '
      '${r.mode == GameMode.quartet ? 'the "all boards" line is the average over the boards the guess was made for, each weighted by how much was left to find out on it (the log of its words left, at least one bit), so a board with a thousand words counts far more than one with two, and a board with a single word left counts as one bit: playing that word is rewarded and missing it is not free.' : 'in a relay race a guess is made for the board that is on, so it is judged on that board alone.'}\n'
      'luck: how much smaller (+, green) or larger (-, red) than average the '
      'group you landed in was; averaged the same way. on your last try luck is '
      'the chance of the pick instead: the chance of any one word on a board is '
      '1 in its words left, and you gain what you score above it (+67 for the '
      'right one of three, -33 for a wrong one).'
      '${r.mode == GameMode.relay ? '\nhead start: a board opens with every earlier guess already applied to it, so a guess also works for the boards still to come. the review says how many words were left the moment each one opened.' : ''}';

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
      yourSolved: s.finalTry ? expectedSolved(s.liveBefore, s.guess) : null,
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
            cell('skill', w: 48, align: TextAlign.right, style: dim),
            cell('luck', w: 60, align: TextAlign.right, style: dim),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < r.steps.length; i++)
          InkWell(
            key: ValueKey('guess-row-$i'),
            onTap: () => setState(() => step = i),
            child: Container(
              color: i == step
                  ? c.primary.withValues(alpha: .08)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  cell(
                    '${i + 1}  ${r.steps[i].guess}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: i == step
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == step ? c.primary : null,
                    ),
                  ),
                  cell(
                    r.steps[i].solvedNow == 0 ? '–' : '${r.steps[i].solvedNow}',
                    w: 56,
                    align: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: r.steps[i].solvedNow == 0 ? null : c.secondary,
                    ),
                  ),
                  cell(
                    '${r.steps[i].skill.round()}',
                    w: 48,
                    align: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
                  ),
                  cell(
                    luckText(r.steps[i].luck),
                    w: 60,
                    align: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: luckColor(c, r.steps[i].luck),
                    ),
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
              style: base.copyWith(color: strong ? c.primary : null),
            ),
            cell(
              luckText(luck),
              w: 64,
              align: TextAlign.right,
              style: base.copyWith(color: luckColor(c, luck)),
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
            cell('skill', w: 52, align: TextAlign.right, style: dim),
            cell('luck', w: 64, align: TextAlign.right, style: dim),
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
          '${h.words == 1 ? 'one word' : '${_n(h.words)} words'} possible out '
          'of ${_n(h.total)}: your earlier guesses had already cut '
          '${h.cut.toStringAsFixed(h.cut >= 99.9 ? 2 : 0)}% of the list'
          '${r.guesses.take(h.opensAfter).contains(r.answers[h.board]) ? ' and solved it the moment it opened: a free ride' : ''}.',
          key: ValueKey('opened-${h.board}'),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: c.onSurface.withValues(alpha: .85),
          ),
        ),
      ),
  ];

  Widget _picks(ColorScheme c, MultiStep s) {
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
                    ? expectedSolved(s.liveBefore, s.guess).toStringAsFixed(2)
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
