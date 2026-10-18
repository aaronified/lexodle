import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'review.dart';
import 'routes.dart';
import 'main.dart';
import 'store.dart';
import 'ui.dart';
import 'wiktionary.dart';
import 'word_info.dart';
import 'words.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.bank, this.random});
  final WordBank bank;

  /// Where the answer is drawn from; tests pass a seeded one.
  final Random? random;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Random _rng = widget.random ?? Random();
  final _focus = FocusNode();

  late final int length;
  late final int pool = appState.pool;
  late final int tries;
  late final List<String> _pool;
  late final Set<String> _letters;

  late String answer;
  late List<String> eligible;
  final guesses = <String>[];
  final marks = <List<Mark>>[];
  final metrics = <GuessMetrics>[];

  /// The words still possible before each guess, for the post-game analysis.
  final befores = <List<String>>[];

  final keyMarks = <String, Mark>{};
  String input = '';
  String message = '';
  bool over = false;
  bool won = false;
  List<Achievement> unlocked = [];

  /// The review's best picks for each guess, begun the moment it was made.
  var _jobs = JobQueue();
  final _analysis = <Future<Landscape>?>[];

  @override
  void initState() {
    super.initState();
    length = appState.length;
    tries = appState.tries;
    _pool = widget.bank.answers(length, pool);
    _letters = widget.bank.letters(length);
    _reset();
  }

  @override
  void dispose() {
    _jobs.close();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    answer = chooseWord(_pool, widget.bank.answerWeights(length, pool), _rng);
    // Every word the game accepts counts as possible, not only the common ones
    // the answer is drawn from: a player cannot know that list, and a real
    // word that fits every clue must never be ruled out behind their back.
    eligible = List.of(widget.bank.guessable(length));
    _jobs.close(); // work on the last game's guesses is no longer wanted
    _jobs = JobQueue();
    _analysis.clear();
    guesses.clear();
    marks.clear();
    keyMarks.clear();
    metrics.clear();
    befores.clear();
    input = '';
    message = '';
    over = won = false;
    unlocked = [];
    // look the answer up now, so the end screen has it
    if (prefetchDefinitions) {
      final lang = widget.bank.language;
      Wiktionary.shared.prefetch(answer, lang.code, lang.wikt);
    }
  }

  void _type(String ch) {
    if (over || input.length >= length || !_letters.contains(ch)) return;
    setState(() {
      input += ch;
      message = '';
    });
  }

  void _back() {
    if (over || input.isEmpty) return;
    setState(() {
      input = input.substring(0, input.length - 1);
      message = '';
    });
  }

  void _submit() {
    if (over) return;
    if (input.length != length) {
      setState(() => message = 'need $length letters');
      return;
    }
    if (guesses.contains(input)) {
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(input)) {
      setState(() => message = 'not in the word list');
      return;
    }
    final m = evaluate(answer, input);
    setState(() {
      guesses.add(input);
      marks.add(m);
      for (var i = 0; i < length; i++) {
        final k = input[i];
        final old = keyMarks[k];
        // correct beats present beats absent
        if (old == null || m[i].index < old.index) keyMarks[k] = m[i];
      }
      final after = filterEligible(eligible, input, m);
      metrics.add(
        scoreGuess(
          eligible,
          input,
          after.length,
          finalTry: guesses.length >= tries,
          solved: input == answer,
        ),
      );
      befores.add(eligible);
      eligible = after;
      // work the review's picks out now, in the background, one guess at a time
      final before = befores.last;
      _analysis.add(
        guesses.length >= tries || !analyseWhilePlaying
            ? null // the last try's picks are only the words that fit
            : _jobs.add(
                () => analyseGuesses(
                  before,
                  recommendationCandidates(
                    before,
                    widget.bank.guessable(length),
                  ),
                ),
              ),
      );
      final solved = input == answer;
      input = '';
      message = '';
      if (solved || guesses.length >= tries) {
        over = true;
        won = solved;
        unlocked = appState.recordGame(
          GameResult(
            lang: widget.bank.language.code,
            length: length,
            tries: tries,
            pool: pool,
            used: guesses.length,
            won: solved,
            skills: [for (final m in metrics) m.skill],
          ),
        );
      }
    });
  }

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
                  '${widget.bank.language.name.toLowerCase()} · $length · '
                  '$tries tries',
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
                  Expanded(child: _grid()),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Center(child: _status(c)),
                  ),
                  if (over) _overPanel(c) else _keyboard(c),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final tile = min(
          56.0,
          (box.maxWidth - 32 - gap * (length - 1)) / length,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: Column(
              children: [
                for (var r = 0; r < tries; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: gap),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          _tile(
                            c,
                            tile,
                            r < guesses.length
                                ? guesses[r][i]
                                : (r == guesses.length && i < input.length
                                      ? input[i]
                                      : ''),
                            r < marks.length ? marks[r][i] : null,
                            active: r == guesses.length && !over,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(
    ColorScheme c,
    double size,
    String ch,
    Mark? m, {
    required bool active,
  }) {
    Color? fill;
    Color fg = c.onSurface;
    Color border = active
        ? c.onSurface.withValues(alpha: .5)
        : c.outlineVariant;
    var borderWidth = 1.0;
    if (m != null) {
      (fill, fg) = markColors(c, m);
      border = markBorder(c, m);
      borderWidth = markBorderWidth(m);
    } else if (ch.isNotEmpty) {
      border = c.onSurface;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: borderWidth),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        ch,
        style: TextStyle(
          fontSize: size * .5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _status(ColorScheme c) {
    if (message.isNotEmpty) {
      return Text(message, style: TextStyle(color: c.error));
    }
    if (over) return const SizedBox();
    final h = appState.helper;
    final left = '${tries - guesses.length} tries left';
    if (guesses.isEmpty) return Caption(left);
    final m = metrics.last;
    final parts = [
      if (h.showSkill) 'skill ${m.skill.toStringAsFixed(1)}',
      if (h.showLuck) 'luck ${luckText(m.luck)}',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parts.isNotEmpty)
          Caption(
            'last guess · ${parts.join(' · ')}',
            textAlign: TextAlign.center,
          ),
        Caption(
          h.showWordsLeft
              ? '${eligible.length} possible '
                    '${eligible.length == 1 ? 'word' : 'words'} · $left'
              : left,
        ),
      ],
    );
  }

  GameRecord _record() => GameRecord(
    bank: widget.bank,
    length: length,
    poolSize: pool,
    answer: answer,
    guesses: List.of(guesses),
    marks: List.of(marks),
    metrics: List.of(metrics),
    befores: List.of(befores),
    finalEligible: eligible,
    won: won,
    tries: tries,
    analysis: List.of(_analysis),
  );

  /// A one-line summary with the review button; the helper's step-by-step
  /// analysis is in the review.
  Widget _summary(ColorScheme c) {
    if (metrics.isEmpty) return const SizedBox();
    double avg(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    return Row(
      children: [
        Expanded(
          child: Caption(
            'average skill ${avg(metrics.map((m) => m.skill)).round()}'
            ' · luck ${luckText(avg(metrics.map((m) => m.luck)))}',
          ),
        ),
        _smallButton(
          'review',
          () =>
              Navigator.pushNamed(context, Routes.review, arguments: _record()),
        ),
      ],
    );
  }

  Widget _smallButton(String label, VoidCallback onPressed) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    ),
    onPressed: onPressed,
    child: Text(label),
  );

  Widget _overPanel(ColorScheme c) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .5,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    won
                        ? 'solved in ${guesses.length} of $tries'
                        : 'the word was  $answer',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _smallButton('replay', () => setState(_reset)),
              ],
            ),
            if (won) Caption(answer),
            const SizedBox(height: 10),
            for (final a in unlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    TablerIcon(a.icon, size: 30, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${a.title}  —  ${a.description}',
                        style: TextStyle(color: c.primary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            _summary(c),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            WordInfoView(word: answer, language: widget.bank.language),
          ],
        ),
      ),
    );
  }

  Widget _keyboard(ColorScheme c) => LetterKeyboard(
    letters: _letters,
    marks: keyMarks,
    onLetter: _type,
    onEnter: _submit,
    onBack: _back,
  );
}
