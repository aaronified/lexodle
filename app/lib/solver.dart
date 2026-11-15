import 'haptics.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import 'guess_input.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'app_log.dart';
import 'modes.dart';
import 'split_plot.dart';
import 'swipe_clear.dart';
import 'typing_keys.dart';
import 'ui.dart';
import 'words.dart';

/// Helps with a game played elsewhere: enter each guess and tap its tiles to
/// match the colours the game showed, and it narrows the words still possible
/// and recommends the best next guess. Ported from the original solver_gui.py,
/// with the recommendation scored by expected words left (the skill measure)
/// over a wider candidate list. [excluded] holds answers the solver must not
/// know (see SolverExclusions): they are neither listed nor recommended. The
/// [mode] (its draw), [length] and [tries] default to the settings.
class SolverPage extends StatefulWidget {
  const SolverPage({
    super.key,
    required this.bank,
    this.excluded = const {},
    this.mode,
    this.length,
    this.tries,
  });
  final WordBank bank;
  final Set<String> excluded;
  final GameMode? mode;
  final int? length;
  final int? tries;

  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final _focus = FocusNode();
  late final int length = widget.length ?? appState.length;
  late final int tries = widget.tries ?? appState.tries;
  late final Draw _draw = appState.drawOf(widget.mode ?? appState.mode);
  // The words the answer can be: every word of the length but the excluded.
  // Guesses are scored over every word the game accepts too (see _solve).
  late final List<String> _answers = [
    for (final w in widget.bank.answers(length))
      if (!widget.excluded.contains(w)) w,
  ];
  late final Set<String> _letters = widget.bank.letters(length);

  final history = <(String, List<Mark>)>[];
  late final input = GuessInput(length);
  late final inputMarks = List.filled(length, Mark.absent);
  String message = '';
  late List<String> eligible = _answers;
  Recommendation? rec;
  // up to five next guesses, best first: rec, then the best of the rest
  List<Recommendation> alts = const [];
  int altSel = 0;
  // each word's split of the words that fit, kept while the history stays
  final _splits = <String, (List<(int, int)>, double)>{};
  late final Set<String> _guessable = {
    for (final w in widget.bank.guessable(length)) w,
    ...widget.bank.answers(length),
  };
  bool busy = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _solve();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _solve() async {
    final run = ++_run;
    var left = _answers;
    for (final (g, m) in history) {
      left = filterEligible(left, g, m);
    }
    setState(() {
      eligible = left;
      busy = true;
      altSel = 0;
      _splits.clear();
    });
    try {
      final candidates = recommendationCandidates(left, [
        for (final w in widget.bank.guessable(length))
          if (!widget.excluded.contains(w)) w,
      ]);
      final weights = widget.bank.law(length, _draw);
      // the tries left shape the advice: with two, the guess most likely to
      // solve it in time; with one, only a word that fits
      final r = await recommendWithin(
        left,
        candidates,
        max(tries - history.length, 1),
        weights: weights,
      );
      final more = left.length > 1
          ? await recommendTop(left, candidates, k: 5, weights: weights)
          : const <Recommendation>[];
      if (!mounted || run != _run) return; // a newer guess superseded this one
      setState(() {
        rec = r;
        alts = [
          ?r,
          for (final x in more)
            if (x.word != r?.word) x,
        ].take(5).toList();
        busy = false;
      });
    } catch (e) {
      appLog.w('solver', 'solve failed ${e.runtimeType}');
      if (!mounted || run != _run) return;
      setState(() {
        rec = null;
        alts = const [];
        busy = false;
      });
    }
  }

  void _type(String ch) {
    setState(() {
      final at = input.type(ch, _letters);
      if (at < 0) return;
      inputMarks[at] = Mark.absent; // a new letter starts unmarked
      message = '';
    });
  }

  void _back() {
    setState(() {
      final at = input.back();
      if (at < 0) return;
      inputMarks[at] = Mark.absent;
      message = '';
    });
  }

  void _move(int by) => setState(() => input.move(by));

  /// A swipe from right to left over the row being typed erases it.
  Widget _swipeClear(bool typing, Widget row) =>
      typing ? SwipeClear(onClear: _clearRow, child: row) : row;

  void _resetInput() {
    input.clear();
    inputMarks.fillRange(0, length, Mark.absent);
  }

  void _cycle(int i) => setState(() {
    inputMarks[i] = switch (inputMarks[i]) {
      Mark.absent => Mark.present,
      Mark.present => Mark.correct,
      Mark.correct => Mark.absent,
    };
  });

  void _add() {
    if (!input.complete) {
      Haptics.fire(Haptic.reject);
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    history.add((input.word, List.of(inputMarks)));
    _resetInput();
    message = '';
    _solve();
  }

  void _undo() {
    if (history.isEmpty) return;
    history.removeLast();
    _solve();
  }

  void _use(String word) => setState(() {
    input.setWord(word);
    inputMarks.fillRange(0, length, Mark.absent);
    message = '';
  });

  void _clearRow() => setState(() {
    input.clearTyped();
  });

  late final _keys = TypingKeys(
    submit: _add,
    back: _back,
    clearRow: _clearRow,
    move: _move,
    type: _type,
  );

  KeyEventResult _onKey(FocusNode _, KeyEvent e) => _keys.handle(e);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(19, 4, 19, 12),
                      children: [
                        if (history.isEmpty)
                          Text(
                            'type a guess, tap its tiles to match the game',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurface.withValues(alpha: dimAlpha),
                            ),
                          ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            const gap = 6.0;
                            final size = min(
                              48.0,
                              (box.maxWidth - gap * (length - 1)) / length,
                            );
                            // a row's tiles, one string per slot ('' empty, a
                            // blank, or a letter); only letters take a colour
                            Widget row(
                              List<String> chars,
                              List<Mark> marks, {
                              void Function(int)? tap,
                              int? cursor,
                            }) => Padding(
                              padding: const EdgeInsets.only(bottom: gap),
                              child: _swipeClear(
                                cursor != null,
                                Row(
                                  children: [
                                    for (var i = 0; i < length; i++) ...[
                                      if (i > 0) const SizedBox(width: gap),
                                      MarkTile(
                                        chars[i],
                                        mark:
                                            chars[i].isEmpty ||
                                                chars[i] == GuessInput.blank
                                            ? null
                                            : marks[i],
                                        size: size,
                                        cursor: i == cursor,
                                        onTap:
                                            tap != null &&
                                                chars[i].isNotEmpty &&
                                                chars[i] != GuessInput.blank
                                            ? () => tap(i)
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (g, m) in history)
                                  row(g.split(''), m),
                                row(
                                  input.slots,
                                  inputMarks,
                                  tap: _cycle,
                                  cursor: input.cursor,
                                ),
                              ],
                            );
                          },
                        ),
                        if (message.isNotEmpty)
                          Text(message, style: TextStyle(color: c.error)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: history.isEmpty ? null : _undo,
                              child: const Text('undo'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _add,
                                child: const Text('add guess'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _result(c),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
                    onCursor: _move,
                    onEnter: _add,
                    onBack: _back,
                    enterLabel: 'add',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (List<(int, int)>, double) _split(String word) =>
      _splits.putIfAbsent(word, () {
        final groups = splitGroups(eligible, word);
        var sq = 0;
        for (final g in groups) {
          sq += g.$2 * g.$2;
        }
        return (groups, eligible.isEmpty ? 0.0 : sq / eligible.length);
      });

  Widget _result(ColorScheme c) {
    final n = eligible.length;
    final left = tries - history.length;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    if (n == 0) {
      return Text(
        'no word matches. check the colours or the list.',
        style: TextStyle(color: c.error, fontSize: 13),
      );
    }
    if (n == 1) {
      return Text(
        'the only word that fits: ${eligible.first}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );
    }
    final line = Caption(
      '$n ${n == 1 ? 'word fits' : 'words fit'} · '
      '${left > 0 ? '$left ${left == 1 ? 'try' : 'tries'} left' : 'out of tries'}',
    );
    if (busy || alts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line,
          const SizedBox(height: 10),
          const Caption('working out the best guesses…'),
        ],
      );
    }
    final typed = input.complete ? input.word : null;
    final typedKnown = typed != null && _guessable.contains(typed);
    final Widget plot;
    if (typedKnown) {
      final (groups, avg) = _split(typed);
      plot = SplitPlot(
        word: typed,
        groups: groups,
        average: avg,
        length: length,
        highlight: markCode(inputMarks),
      );
    } else if (typed != null) {
      plot = Text(
        '$typed is not in the word list',
        style: TextStyle(fontSize: 12, color: dim),
      );
    } else {
      final word = alts[min(altSel, alts.length - 1)].word;
      final (groups, avg) = _split(word);
      plot = SplitPlot(
        word: word,
        groups: groups,
        average: avg,
        length: length,
        onUse: () => _use(word),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        const SizedBox(height: 12),
        const Caption('alternatives'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < alts.length; i++)
              _chip(c, i, alts[i], selected: !typedKnown && i == altSel),
          ],
        ),
        const SizedBox(height: 12),
        plot,
      ],
    );
  }

  Widget _chip(
    ColorScheme c,
    int i,
    Recommendation r, {
    required bool selected,
  }) {
    final border = BorderRadius.circular(4);
    return InkWell(
      key: ValueKey('alt-${r.word}'),
      borderRadius: border,
      onTap: () => setState(() => altSel = i),
      child: Container(
        constraints: const BoxConstraints(minWidth: 78),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.surfaceContainerHighest : null,
          borderRadius: border,
          border: Border.all(
            color: selected ? c.onSurface : hairlineColor(c),
            width: selected ? 1 : hairlineWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.word,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${r.expected.toStringAsFixed(1)} left',
              style: TextStyle(
                fontSize: 10,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
