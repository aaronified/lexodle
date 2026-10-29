import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_worker.dart';
import 'guess_input.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'ui.dart';
import 'words.dart';

/// How a guess did in learn mode: its skill and the best guess there was.
class LearnFeedback {
  const LearnFeedback(this.skill, this.best, this.bestWords);
  final double skill;

  /// The best skill is always 100; this is the expected gain, in bits, it has.
  final double best;

  /// The best guesses of that position, best first.
  final List<String> bestWords;
}

/// Learn mode: the answer is shown, and the job is to find the best guess at
/// each step. After every guess it says how good it was and what the best was,
/// and the words that still fit are listed at the bottom. It uses the settings
/// (language, letters, pool) but is not scored, has no tries and is not kept in
/// the history.
class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.bank, this.seed});
  final WordBank bank;

  /// Fixes the words drawn, for a test; null draws at random.
  final int? seed;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  final _focus = FocusNode();
  late final _rng = Random(widget.seed);
  late final int length = appState.length;
  late final List<String> _pool = widget.bank.answers(length);
  late final Set<String> _letters = widget.bank.letters(length);
  late final input = GuessInput(length);

  late String answer;
  late List<String> eligible;
  final guesses = <String>[];
  final marks = <List<Mark>>[];
  final feedback = <LearnFeedback?>[];
  String message = '';
  int _game = 0;

  bool get solved => guesses.isNotEmpty && guesses.last == answer;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    answer = chooseWord(
      _pool,
      widget.bank.drawWeights(length, appState.draw),
      _rng,
    );
    // every word the game accepts could be the answer as far as a clue goes
    eligible = List.of(widget.bank.guessable(length));
    guesses.clear();
    marks.clear();
    feedback.clear();
    input.clear();
    message = '';
    _game++;
  }

  void _type(String ch) {
    if (solved) return;
    setState(() {
      input.type(ch, _letters);
      message = '';
    });
  }

  void _back() => setState(() {
    input.back();
    message = '';
  });

  void _submit() {
    if (solved) return;
    if (!input.complete) {
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    final word = input.word;
    if (!widget.bank.valid.contains(word)) {
      setState(() => message = 'not in the word list');
      return;
    }
    final m = evaluate(answer, word);
    final before = eligible;
    final after = filterEligible(before, word, m);
    final index = guesses.length;
    final game = _game;
    setState(() {
      guesses.add(word);
      marks.add(m);
      feedback.add(null);
      eligible = after;
      input.clear();
      message = '';
    });
    _grade(game, index, before, word, after);
  }

  Future<void> _grade(
    int game,
    int index,
    List<String> before,
    String word,
    List<String> after,
  ) async {
    final law = widget.bank.law(length, appState.draw);
    final land = await analyseOffThread(
      before,
      widget.bank.guessable(length),
      k: 3,
      weights: law,
    );
    if (!mounted || game != _game || index >= feedback.length) return;
    final measured = scoreGuess(
      before,
      word,
      after.length,
      weights: law,
      afterWords: after,
      provisional: true,
    ).withBest(land.bestGain);
    setState(() {
      feedback[index] = LearnFeedback(measured.skill, land.bestGain, [
        for (final r in land.top) r.word,
      ]);
    });
  }

  void _use(String word) => setState(() {
    if (!solved) input.setWord(word);
    message = '';
  });

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _submit();
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() => input.move(-1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() => input.move(1));
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
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
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
                  'learn · $lang · $length',
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
                      padding: const EdgeInsets.fromLTRB(19, 4, 19, 12),
                      children: [
                        const Caption(
                          'you know the answer. find the guess that cuts '
                          'the words that fit down the most',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'the answer: $answer',
                          key: const ValueKey('learn-answer'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            const gap = 6.0;
                            final size = min(
                              44.0,
                              (box.maxWidth - gap * (length - 1)) / length,
                            );
                            Widget row(
                              List<String> chars,
                              List<Mark>? ms, {
                              int? cursor,
                            }) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  for (var i = 0; i < length; i++) ...[
                                    if (i > 0) const SizedBox(width: gap),
                                    MarkTile(
                                      chars[i],
                                      mark: ms == null || chars[i].isEmpty
                                          ? null
                                          : ms[i],
                                      size: size,
                                      cursor: i == cursor,
                                    ),
                                  ],
                                ],
                              ),
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var g = 0; g < guesses.length; g++) ...[
                                  row(guesses[g].split(''), marks[g]),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: metricLine(
                                      context,
                                      _feedbackText(g),
                                      'skill',
                                      key: ValueKey('learn-feedback-$g'),
                                      style: dim,
                                    ),
                                  ),
                                ],
                                if (!solved)
                                  row(input.slots, null, cursor: input.cursor),
                              ],
                            );
                          },
                        ),
                        if (message.isNotEmpty)
                          Text(message, style: TextStyle(color: c.error)),
                        if (solved) ...[
                          const SizedBox(height: 8),
                          Text(
                            'solved in ${guesses.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            key: const ValueKey('learn-next'),
                            onPressed: () => setState(_reset),
                            child: const Text('another word'),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),
                        _words(c, dim),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
                    onEnter: _submit,
                    onBack: _back,
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

  String _feedbackText(int g) {
    final f = feedback[g];
    if (f == null) return 'working out how it did…';
    final top = f.bestWords.take(3).join(', ');
    if (f.skill >= 99.99) return 'skill 100 · as good as any guess ($top)';
    return 'skill ${f.skill.toStringAsFixed(0)} · the best: $top';
  }

  /// The words that still fit, at the bottom: tap one to use it.
  Widget _words(ColorScheme c, TextStyle dim) {
    final n = eligible.length;
    return Column(
      key: const ValueKey('learn-words'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption('$n ${n == 1 ? 'word fits' : 'words fit'} the clues so far'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final w in eligible.take(120))
              InkWell(
                onTap: () => _use(w),
                child: Text(
                  w,
                  style: w == answer && solved
                      ? TextStyle(color: c.primary, fontWeight: FontWeight.bold)
                      : null,
                ),
              ),
          ],
        ),
        if (n > 120) ...[
          const SizedBox(height: 6),
          Text('the 120 most common of them', style: dim),
        ],
      ],
    );
  }
}
