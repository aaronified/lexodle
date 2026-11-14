import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'equations.dart';
import 'guess_input.dart';
import 'haptics.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'swipe_clear.dart';
import 'typing_keys.dart';
import 'settings_button.dart';
import 'ui.dart';
import 'words.dart';

/// Helps with an equations game played elsewhere: enter each guess equation and
/// tap its tiles to match the colours the game showed, and it narrows the
/// equations still possible and recommends the best next guess, scored by the
/// equations expected to be left. [bank] is the equations bank (see
/// [Equations.load]); [excluded] holds answers the solver must not know (see
/// SolverExclusions): they are not in its pool.
class EquationSolverPage extends StatefulWidget {
  const EquationSolverPage({
    super.key,
    required this.bank,
    this.excluded = const {},
  });
  final WordBank bank;
  final Set<String> excluded;

  @override
  State<EquationSolverPage> createState() => _EquationSolverPageState();
}

class _EquationSolverPageState extends State<EquationSolverPage> {
  final _focus = FocusNode();
  late final int length = appState.eqLength;
  late final int tries = appState.eqTries;
  // The equations the answer can be: every one of the length but the excluded.
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
    try {
      for (final (g, m) in history) {
        left = filterEligible(left, g, m);
      }
    } catch (e) {
      appLog.w('equation solver', 'could not narrow: ${e.runtimeType}');
    }
    setState(() {
      eligible = left;
      busy = true;
    });
    Recommendation? r;
    try {
      // the tries left shape the advice: with two, the guess most likely to
      // solve it in time; with one, only an equation that fits
      r = await recommendWithin(
        left,
        recommendationCandidates(left, widget.bank.guessable(length)),
        max(tries - history.length, 1),
      );
    } catch (e) {
      appLog.w('equation solver', 'could not recommend: ${e.runtimeType}');
    }
    if (!mounted || run != _run) return; // a newer guess superseded this one
    setState(() {
      rec = r;
      busy = false;
    });
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
        () =>
            message = input.hasBlank ? 'fill the blanks' : 'need $length tiles',
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
    equations: true,
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
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'solver · equations · $length · $tries tries',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
          actions: [const SettingsButton()],
        ),
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
                        const Caption(
                          'type each equation you played, then tap '
                          'its tiles to match the colours the game showed',
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
                                        faceOf(chars[i]),
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
                            Expanded(
                              child: OutlinedButton(
                                onPressed: history.isEmpty ? null : _undo,
                                child: const Text('undo last'),
                              ),
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
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),
                        _result(c),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    numberPad: true,
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

  String _face(String eq) => eq.split('').map(faceOf).join();

  Widget _result(ColorScheme c) {
    final n = eligible.length;
    final left = tries - history.length;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption('$n ${n == 1 ? 'equation' : 'equations'} on my list fit'),
        const SizedBox(height: 4),
        Caption(
          'answers from ${_answers.length} equations · '
          '${left > 0 ? '$left ${left == 1 ? 'try' : 'tries'} left' : 'out of tries'}',
        ),
      ],
    );
    if (n == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 8),
          Text(
            'no equation matches. check the colours of the guesses above.',
            style: TextStyle(color: c.error, fontSize: 13),
          ),
        ],
      );
    }
    final r = rec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        const SizedBox(height: 10),
        if (n == 1) ...[
          Text(
            'the only equation on my list that fits: ${_face(eligible.first)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ] else if (r == null || busy)
          const Caption('working out the best guess…')
        else ...[
          Caption(switch (tries - history.length) {
            <= 1 => 'last try: an equation that fits',
            2 => 'two tries left: the guess most likely to solve it in time',
            _ => 'recommended guess',
          }),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _use(r.word),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _face(r.word),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.primary,
                ),
              ),
            ),
          ),
          metricLine(
            context,
            '${r.winChance == null ? 'skill ${r.skill.toStringAsFixed(1)}' : 'about ${(r.winChance! * 100).toStringAsFixed(0)}% to solve it'}'
                ' · expect about '
                '${r.expected.toStringAsFixed(1)} equations left'
                '${r.canWin ? ' · could be the answer' : ''}  (tap to use)',
            'skill',
            style: TextStyle(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
        if (n > 1) ...[
          const SizedBox(height: 16),
          Caption(n > 40 ? 'the first 40' : 'all the equations that fit'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final w in eligible.take(40))
                InkWell(onTap: () => _use(w), child: Text(_face(w))),
            ],
          ),
        ],
      ],
    );
  }
}
