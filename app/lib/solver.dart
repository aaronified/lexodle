import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'guess_input.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'ui.dart';
import 'words.dart';

/// Helps with a game played elsewhere: enter each guess and tap its tiles to
/// match the colours the game showed, and it narrows the words still possible
/// and recommends the best next guess. Ported from the original solver_gui.py,
/// with the recommendation scored by expected words left (the skill measure)
/// over a wider candidate list.
class SolverPage extends StatefulWidget {
  const SolverPage({super.key, required this.bank});
  final WordBank bank;

  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final _focus = FocusNode();
  late final int length = appState.length;
  late final int tries = appState.tries;
  // The words the answer can be: every word of the length. Guesses are scored
  // over every word the game accepts too (see _solve).
  late final List<String> _answers = widget.bank.answers(length);
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
    for (final (g, m) in history) {
      left = filterEligible(left, g, m);
    }
    setState(() {
      eligible = left;
      busy = true;
    });
    final candidates = recommendationCandidates(
      left,
      widget.bank.guessable(length),
    );
    // the tries left shape the advice: with two, the guess most likely to solve
    // it in time; with one, only a word that fits
    final r = await recommendWithin(
      left,
      candidates,
      max(tries - history.length, 1),
      weights: appState.useFrequency ? widget.bank.weightMap(length) : null,
    );
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

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _add();
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(1);
    } else if (e.character != null) {
      _type(e.character!.toLowerCase());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlagBadge(widget.bank.language.flag, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'solver · $lang · $length · $tries tries',
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                      children: [
                        const Caption(
                          'type each guess you played, then tap '
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
                              child: Row(
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
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
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

  Widget _result(ColorScheme c) {
    final n = eligible.length;
    final left = tries - history.length;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption('$n ${n == 1 ? 'word' : 'words'} on my list fit'),
        const SizedBox(height: 4),
        Caption(
          'answers from ${_answers.length} words · '
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
            'no word matches. check the colours of the guesses above, or the '
            'game may use a word this list lacks.',
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
            'the only word on my list that fits: ${eligible.first}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'if the game does not accept it, the answer is a word my list '
            'does not have.',
            style: TextStyle(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ] else if (r == null || busy)
          const Caption('working out the best guess…')
        else ...[
          Caption(switch (tries - history.length) {
            <= 1 => 'last try: the likeliest word that fits',
            2 => 'two tries left: the guess most likely to solve it in time',
            _ => 'recommended guess',
          }),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _use(r.word),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                r.word,
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
                '${r.expected.toStringAsFixed(1)} words left'
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
          Caption(n > 40 ? 'most likely 40' : 'all the words that fit'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final w in eligible.take(40))
                InkWell(onTap: () => _use(w), child: Text(w)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'my list holds all ${_answers.length} words of this '
          'length. a game can use a word that is not on it.',
          style: TextStyle(
            fontSize: 11,
            color: c.onSurface.withValues(alpha: dimAlpha),
          ),
        ),
      ],
    );
  }
}
