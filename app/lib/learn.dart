import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_worker.dart';
import 'guess_input.dart';
import 'keyboard.dart';
import 'learn_log.dart';
import 'learn_text.dart';
import 'logic.dart';
import 'main.dart';
import 'ui.dart';
import 'words.dart';

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
  final feedback = <GuessReport?>[];
  String message = '';
  int _game = 0;

  // What the position before each guess looked like, so a guess can be taken
  // back: the words that fitted, and its analysis (one per position, shared by
  // the hints and the grade).
  final _befores = <List<String>>[];
  final _lands = <Future<Landscape>>[];
  final _tokens = <int>[];
  int _serial = 0;
  Future<Landscape>? _land;
  Landscape? _landNow;
  GuessReport? _bestReport;

  /// The rung of the hint ladder the position stands on (0 none, 3 the most),
  /// and how many hints this word has used in all.
  int hint = 0;
  int hintsUsed = 0;

  /// Whether this word has been put in the learn log: once, even if it is
  /// taken back and solved again.
  bool _recorded = false;

  /// Which guesses show their explanation.
  final _open = <int>{};

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
    _befores.clear();
    _lands.clear();
    _tokens.clear();
    _open.clear();
    hint = 0;
    hintsUsed = 0;
    _recorded = false;
    input.clear();
    message = '';
    _game++;
    _startPosition();
  }

  Map<String, int>? get _law => widget.bank.law(length, appState.draw);

  /// Starts the analysis of the position the words that fit now make: the best
  /// guesses, for the hints and for grading the next guess.
  void _startPosition() {
    _landNow = null;
    _bestReport = null;
    final game = _game;
    final words = eligible;
    final land = analyseOffThread(
      words,
      widget.bank.guessable(length),
      k: 3,
      weights: _law,
    );
    _land = land;
    land.then((l) {
      if (!mounted || game != _game || !identical(_land, land)) return;
      setState(() {
        _landNow = l;
        _bestReport = l.top.isEmpty
            ? null
            : reportBest(before: words, landscape: l, weights: _law);
      });
    }, onError: (_) {});
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
    final land = _land!;
    final token = ++_serial;
    setState(() {
      guesses.add(word);
      marks.add(m);
      feedback.add(null);
      _befores.add(before);
      _lands.add(land);
      _tokens.add(token);
      eligible = after;
      hint = 0;
      _open.clear();
      input.clear();
      message = '';
      if (word == answer) {
        _land = null;
        _landNow = null;
        _bestReport = null;
      } else {
        _startPosition();
      }
    });
    _grade(index, token, before, word, after, land);
  }

  Future<void> _grade(
    int index,
    int token,
    List<String> before,
    String word,
    List<String> after,
    Future<Landscape> land,
  ) async {
    final Landscape l;
    try {
      l = await land;
    } catch (_) {
      return;
    }
    if (!mounted || index >= _tokens.length || _tokens[index] != token) return;
    final report = reportGuess(
      before: before,
      guess: word,
      after: after,
      landscape: l,
      weights: _law,
    );
    setState(() {
      feedback[index] = report;
      _open.add(index);
    });
    _record();
  }

  /// Puts the word in the learn log once it is solved and every guess of it has
  /// been graded (the last grade can come after the solve).
  void _record() {
    if (_recorded || !solved || feedback.any((f) => f == null)) return;
    _recorded = true;
    final reports = [for (final f in feedback) f!];
    appState.recordLearn(
      LearnEvent(
        kind: LearnKind.free,
        language: widget.bank.language.code,
        length: length,
        date: DateTime.now().toIso8601String().substring(0, 10),
        questions: reports.length,
        right: reports.where((r) => r.asGoodAsAny).length,
        avgSkill: reports.fold(0.0, (s, r) => s + r.skill) / reports.length,
        hints: hintsUsed,
      ),
    );
  }

  /// Takes the last guess back, with the position it was made in.
  void _undo() {
    if (guesses.isEmpty) return;
    setState(() {
      guesses.removeLast();
      marks.removeLast();
      feedback.removeLast();
      _tokens.removeLast();
      eligible = _befores.removeLast();
      final land = _lands.removeLast();
      _open.clear();
      hint = 0;
      input.clear();
      message = '';
      _landNow = null;
      _bestReport = null;
      _land = land;
      land.then((l) {
        if (!mounted || !identical(_land, land)) return;
        setState(() {
          _landNow = l;
          _bestReport = l.top.isEmpty
              ? null
              : reportBest(before: eligible, landscape: l, weights: _law);
        });
      }, onError: (_) {});
    });
  }

  /// The next rung of the hint ladder: the first letter, the word, then why.
  void _hint() {
    if (solved || hint >= 3) return;
    setState(() {
      hint++;
      hintsUsed++;
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
                                    child: _feedback(g, dim),
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
                        if (!solved || guesses.isNotEmpty) _tools(c, dim),
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

  /// The line under a guess: its skill and the best guesses; tap it to see
  /// why (how the guess and the best one split the words that fitted).
  Widget _feedback(int g, TextStyle dim) {
    final f = feedback[g];
    if (f == null) {
      return metricLine(
        context,
        'working out how it did…',
        'skill',
        key: ValueKey('learn-feedback-$g'),
        style: dim,
      );
    }
    final open = _open.contains(g);
    return InkWell(
      key: ValueKey('learn-feedback-tap-$g'),
      onTap: () => setState(() => open ? _open.remove(g) : _open.add(g)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metricLine(
            context,
            learnVerdict(f),
            'skill',
            key: ValueKey('learn-feedback-$g'),
            style: dim,
          ),
          if (open)
            Padding(
              key: ValueKey('learn-why-$g'),
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in learnWhy(f))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(line, style: dim),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The hint and undo buttons, and the hint when one is asked for.
  Widget _tools(ColorScheme c, TextStyle dim) {
    final best = _landNow?.top.map((r) => r.word).toList() ?? const <String>[];
    final text = hint == 0
        ? ''
        : _landNow == null
        ? 'working out the best guess…'
        : learnHint(hint, best, _bestReport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!solved)
              TextButton(
                key: const ValueKey('learn-hint'),
                onPressed: hint >= 3 ? null : _hint,
                child: Text(hint == 0 ? 'hint' : 'more'),
              ),
            if (guesses.isNotEmpty)
              TextButton(
                key: const ValueKey('learn-undo'),
                onPressed: _undo,
                child: const Text('undo'),
              ),
          ],
        ),
        if (text.isNotEmpty && !solved)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: best.isEmpty || hint < 2 ? null : () => _use(best.first),
              child: Text(
                text,
                key: const ValueKey('learn-hint-text'),
                style: TextStyle(color: c.primary),
              ),
            ),
          ),
      ],
    );
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
