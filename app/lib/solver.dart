import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late final List<String> _answers = widget.bank.answers(length);
  late final Set<String> _letters = widget.bank.letters(length);

  final history = <(String, List<Mark>)>[];
  String input = '';
  final inputMarks = <Mark>[];
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
    final candidates = {
      ...left.take(600),
      ...widget.bank.guessable(length).take(600),
    };
    final r = await recommend(left, candidates);
    if (!mounted || run != _run) return; // a newer guess superseded this one
    setState(() {
      rec = r;
      busy = false;
    });
  }

  void _type(String ch) {
    if (input.length >= length || !_letters.contains(ch)) return;
    setState(() {
      input += ch;
      inputMarks.add(Mark.absent);
      message = '';
    });
  }

  void _back() {
    if (input.isEmpty) return;
    setState(() {
      input = input.substring(0, input.length - 1);
      inputMarks.removeLast();
      message = '';
    });
  }

  void _cycle(int i) => setState(() {
        inputMarks[i] = switch (inputMarks[i]) {
          Mark.absent => Mark.present,
          Mark.present => Mark.correct,
          Mark.correct => Mark.absent,
        };
      });

  void _add() {
    if (input.length != length) {
      setState(() => message = 'need $length letters');
      return;
    }
    history.add((input, List.of(inputMarks)));
    input = '';
    inputMarks.clear();
    message = '';
    _solve();
  }

  void _undo() {
    if (history.isEmpty) return;
    history.removeLast();
    _solve();
  }

  void _use(String word) => setState(() {
        input = word;
        inputMarks
          ..clear()
          ..addAll(List.filled(word.length, Mark.absent));
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
          title: Text('solver · $lang · $length',
              style: const TextStyle(fontSize: 14, letterSpacing: 1.5)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    children: [
                      const Caption('type each guess you played, then tap '
                          'its tiles to match the colours the game showed'),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (context, box) {
                        const gap = 6.0;
                        final size = min(
                            48.0, (box.maxWidth - gap * (length - 1)) / length);
                        Widget row(String word, List<Mark> marks,
                                {void Function(int)? tap}) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: gap),
                              child: Row(children: [
                                for (var i = 0; i < length; i++) ...[
                                  if (i > 0) const SizedBox(width: gap),
                                  MarkTile(
                                    i < word.length ? word[i] : '',
                                    mark: i < marks.length ? marks[i] : null,
                                    size: size,
                                    onTap: tap != null && i < word.length
                                        ? () => tap(i)
                                        : null,
                                  ),
                                ],
                              ]),
                            );
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (g, m) in history) row(g, m),
                              row(input, inputMarks, tap: _cycle),
                            ]);
                      }),
                      if (message.isNotEmpty)
                        Text(message, style: TextStyle(color: c.error)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                              onPressed: history.isEmpty ? null : _undo,
                              child: const Text('undo last')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                              onPressed: _add, child: const Text('add guess')),
                        ),
                      ]),
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
                  onEnter: _add,
                  onBack: _back,
                  enterLabel: 'add',
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(ColorScheme c) {
    final n = eligible.length;
    final head = Caption('$n possible ${n == 1 ? 'word' : 'words'}');
    if (n == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
        const SizedBox(height: 8),
        Text(
            'no word matches. check the colours of the guesses above, or the '
            'game may use a word this list lacks.',
            style: TextStyle(color: c.error, fontSize: 13)),
      ]);
    }
    final r = rec;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      head,
      const SizedBox(height: 10),
      if (n == 1)
        Text('the answer: ${eligible.first}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
      else if (r == null || busy)
        const Caption('working out the best guess…')
      else ...[
        const Caption('recommended guess'),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _use(r.word),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(r.word,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: c.primary)),
          ),
        ),
        Text(
          'skill ${r.skill.toStringAsFixed(1)} · expect about '
          '${r.expected.toStringAsFixed(1)} words left'
          '${r.canWin ? ' · could be the answer' : ''}  (tap to use)',
          style:
              TextStyle(fontSize: 11, color: c.onSurface.withValues(alpha: .6)),
        ),
      ],
      if (n > 1) ...[
        const SizedBox(height: 16),
        Caption(n > 40 ? 'most likely 40' : 'all possible words'),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final w in eligible.take(40))
            InkWell(onTap: () => _use(w), child: Text(w)),
        ]),
      ],
    ]);
  }
}
