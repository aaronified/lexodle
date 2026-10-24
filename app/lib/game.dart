import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background.dart';
import 'daily.dart';
import 'difficulty.dart';
import 'guess_input.dart';
import 'history.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'modes.dart';
import 'review.dart';
import 'routes.dart';
import 'main.dart';
import 'store.dart';
import 'ui.dart';
import 'wiktionary.dart';
import 'word_info.dart';
import 'words.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.bank, this.random, this.daily});
  final WordBank bank;

  /// Where the answer is drawn from; tests pass a seeded one.
  final Random? random;

  /// Set to play the daily word: its answer, and the fixed difficulty, instead
  /// of a random word at the chosen settings. Read once, when the game begins.
  final Daily? daily;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Random _rng = widget.random ?? Random();
  final _focus = FocusNode();

  late final Daily? _daily = widget.daily;
  late final int length;
  // the saved pool, or the biggest this language has words for at this length
  late final int pool = _daily == null
      ? effectivePool(appState.pool, widget.bank.language.counts[length])
      : dailyPool;
  late final int tries;

  /// How many words the pool really holds: the level's size, or every word the
  /// language has when it is the last level offered (see [poolWords]).
  late final int _poolWords = poolWords(
    pool,
    widget.bank.language.counts[length],
  );
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
  late final input = GuessInput(length);
  String message = '';
  bool over = false;
  bool won = false;
  List<Achievement> unlocked = [];

  /// The review's best picks for each guess, begun the moment it was made.
  var _jobs = JobQueue();
  final _analysis = <Future<Landscape>?>[];

  /// Counts the games begun, so work for an earlier one is ignored.
  var _epoch = 0;

  @override
  void initState() {
    super.initState();
    length = _daily == null ? appState.length : dailyLength;
    tries = _daily == null ? appState.tries : dailyTries;
    _pool = widget.bank.answers(length, _poolWords);
    _letters = widget.bank.letters(length);
    _reset();
    _resume();
  }

  /// A daily left half played, or finished, comes back as it was, so that
  /// closing the page cannot reroll it. Nothing is recorded again: the game was
  /// counted when it ended.
  void _resume() {
    final d = _daily;
    if (d == null) return;
    final saved = appState.dailyFor(widget.bank.language.code, d.date);
    if (saved == null) return;
    for (final g in saved.guesses) {
      // a damaged save stops the replay rather than breaking the game
      if (over || g.length != length || !widget.bank.valid.contains(g)) break;
      _apply(g, restoring: true);
    }
  }

  @override
  void dispose() {
    _jobs.close();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    answer =
        _daily?.answer ??
        chooseWord(_pool, widget.bank.answerWeights(length, _poolWords), _rng);
    // Every word the game accepts counts as possible, not only the common ones
    // the answer is drawn from: a player cannot know that list, and a real
    // word that fits every clue must never be ruled out behind their back.
    eligible = List.of(widget.bank.guessable(length));
    _jobs.close(); // work on the last game's guesses is no longer wanted
    _jobs = JobQueue();
    _epoch++;
    _analysis.clear();
    guesses.clear();
    marks.clear();
    keyMarks.clear();
    metrics.clear();
    befores.clear();
    input.clear();
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
    if (over) return;
    setState(() {
      if (input.type(ch, _letters) >= 0) message = '';
    });
  }

  void _back() {
    if (over) return;
    setState(() {
      if (input.back() >= 0) message = '';
    });
  }

  void _select(int i) {
    if (over) return;
    setState(() => input.select(i));
  }

  void _move(int by) {
    if (over) return;
    setState(() => input.move(by));
  }

  void _submit() {
    if (over) return;
    if (!input.complete) {
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    final word = input.word;
    if (guesses.contains(word)) {
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(word)) {
      setState(() => message = 'not in the word list');
      return;
    }
    setState(() => _apply(word));
  }

  /// Plays [word], which has been checked. [restoring] replays a saved daily
  /// guess: it is not saved or recorded again.
  void _apply(String word, {bool restoring = false}) {
    final m = evaluate(answer, word);
    guesses.add(word);
    marks.add(m);
    for (var i = 0; i < length; i++) {
      final k = word[i];
      final old = keyMarks[k];
      // correct beats present beats absent
      if (old == null || m[i].index < old.index) keyMarks[k] = m[i];
    }
    final after = filterEligible(eligible, word, m);
    metrics.add(
      scoreGuess(
        eligible,
        word,
        after.length,
        finalTry: guesses.length >= tries,
        solved: word == answer,
        // skill is measured against the best real guess, which the
        // background analysis is still finding out
        provisional: analyseWhilePlaying,
      ),
    );
    befores.add(eligible);
    eligible = after;
    // work the guess out now, in the background, one at a time: the best
    // real split (for its skill) and the picks and plots of the review
    final before = befores.last;
    final index = guesses.length - 1;
    final epoch = _epoch;
    if (analyseWhilePlaying) {
      final job = _jobs.add(
        () => analyseGuesses(before, widget.bank.guessable(length)),
      );
      _analysis.add(job);
      job.then<void>((land) {
        if (!mounted || epoch != _epoch) return;
        setState(() {
          metrics[index] = metrics[index].withLandscape(land);
        });
      }, onError: (_) {});
    } else {
      _analysis.add(null);
    }
    final solved = word == answer;
    input.clear();
    message = '';
    if (solved || guesses.length >= tries) {
      over = true;
      won = solved;
      if (!restoring) _finish();
    }
    final d = _daily;
    if (d != null && !restoring) {
      appState.saveDaily(
        widget.bank.language.code,
        d.date,
        guesses,
        won: over ? won : null,
      );
    }
  }

  /// The finished game counts towards the statistics and achievements. Skill
  /// is final only once every guess has been analysed, so that is waited for.
  void _finish() {
    final epoch = _epoch;
    void record() {
      final d = _daily;
      GameResult result([int streak = 0]) => GameResult(
        lang: widget.bank.language.code,
        length: length,
        tries: tries,
        pool: pool,
        used: guesses.length,
        won: won,
        skills: [for (final m in metrics) m.skill],
        daily: d != null,
        dailyStreak: streak,
      );
      var r = result();
      // the game goes in the history as it was played (the guesses are the
      // facts, the scores can be worked out again), and the day goes in the
      // log first, so the streak it leaves is known to the achievements; skill
      // is final here, so the double fire can be judged
      appState.recordHistory(
        lang: widget.bank.language.code,
        mode: GameMode.classic,
        length: length,
        tries: tries,
        pool: pool,
        answers: [answer],
        won: won,
        guesses: [
          for (var i = 0; i < metrics.length; i++) guessRowOf(i, metrics[i]),
        ],
        daily: d?.date ?? '',
      );
      if (d != null) r = result(appState.recordDaily(d.date, r.dailyTier));
      unlocked = appState.recordGame(r);
    }

    final pending = _analysis.nonNulls.toList();
    if (pending.isEmpty) {
      record();
      return;
    }
    void done() {
      if (mounted && epoch == _epoch) setState(record);
    }

    Future.wait(pending).then<void>((_) => done(), onError: (_) => done());
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
                  _daily == null
                      ? '${widget.bank.language.name.toLowerCase()} · '
                            '$length · $tries tries'
                      : '${widget.bank.language.name.toLowerCase()} · '
                            'daily · ${_daily.date}',
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
                                : (r == guesses.length ? input.slot(i) : ''),
                            r < marks.length ? marks[r][i] : null,
                            active: r == guesses.length && !over,
                            cursor:
                                r == guesses.length &&
                                !over &&
                                i == input.cursor,
                            onTap: r == guesses.length && !over
                                ? () => _select(i)
                                : null,
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
    bool cursor = false,
    VoidCallback? onTap,
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
    if (cursor) {
      border = c.primary;
      borderWidth = 2;
    }
    final isBlank = ch == GuessInput.blank;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: borderWidth),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          isBlank ? '_' : ch,
          style: TextStyle(
            fontSize: size * .5,
            fontWeight: FontWeight.bold,
            color: isBlank ? fg.withValues(alpha: dimAlpha) : fg,
          ),
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
      if (h.showSkill) 'skill ${m.ready ? m.skill.toStringAsFixed(1) : '…'}',
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
            'average skill ${metrics.every((m) => m.ready) ? avg(metrics.map((m) => m.skill)).round() : '…'}'
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
                // a daily is played once: the next word comes tomorrow
                if (_daily == null)
                  _smallButton('replay', () => setState(_reset)),
              ],
            ),
            if (_daily != null)
              Caption(
                'daily ${_daily.date} · streak ${appState.dailyStreak} · '
                'the next word comes at 00:00 utc',
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
    onBlank: () => _type(GuessInput.blank),
    onEnter: _submit,
    onBack: _back,
  );
}
