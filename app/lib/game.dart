import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_worker.dart';
import 'background.dart';
import 'blind_pencil.dart';
import 'daily.dart';
import 'equations.dart';
import 'game_header.dart';
import 'hearts.dart';
import 'modes.dart';
import 'puzzle.dart';
import 'share_puzzle.dart';
import 'geography.dart';
import 'guess_input.dart';
import 'help.dart';
import 'place_info.dart';
import 'haptics.dart';
import 'history.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'resizable_panel.dart';
import 'review.dart';
import 'review_text.dart';
import 'routes.dart';
import 'main.dart';
import 'save_word_button.dart';
import 'sounds.dart';
import 'swipe_clear.dart';
import 'store.dart';
import 'ui.dart';
import 'wiktionary.dart';
import 'word_info.dart';
import 'words.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.bank,
    this.random,
    this.daily,
    this.practice = false,
    this.replay = const [],
    this.mode = GameMode.classic,
    this.chosen = false,
    this.hearts,
  });

  /// The hearts of a lockdown puzzle made by a friend (a link); null for the
  /// player's own setting.
  final int? hearts;

  /// Whether the word was chosen by a friend (a made wordle), not drawn.
  final bool chosen;

  final WordBank bank;

  /// Classic, or lockdown: one word either way.
  final GameMode mode;

  /// Where the answer is drawn from; tests pass a seeded one.
  final Random? random;

  /// Set to play the daily word: its answer, and the fixed difficulty, instead
  /// of a random word at the chosen settings. Read once, when the game begins.
  final Daily? daily;

  /// A daily opened by a link: played as practice, so nothing is saved or
  /// counted (no streak, history, statistics or achievements).
  final bool practice;

  /// Guesses a link carries, played at once when the page opens.
  final List<String> replay;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Random _rng = widget.random ?? Random();
  final _focus = FocusNode();

  late final Daily? _daily = widget.daily;
  late final int length;
  late final int tries;

  GameMode get mode => widget.mode;
  bool get lockdown => mode == GameMode.lockdown;

  /// The themed wordle (the words are places) and the blind one (a guess shows
  /// only how many letters are right).
  bool get themed => mode == GameMode.themed;
  bool get blind => mode == GameMode.blind;

  /// The equations: the tiles are digits and signs, scored and reviewed as
  /// words are. The mastermind is a word that dodges: each guess is scored
  /// against the words still possible, and reviewed against the word it settled
  /// on, which fits every reply it gave.
  bool get equations => mode == GameMode.equations;
  bool get mastermind => mode == GameMode.mastermind;

  /// Neither has a word of the language to look up.
  bool get _noDictionary => equations || mastermind;

  /// The mastermind that always keeps the largest pool, as chosen when it began.
  late final bool largest =
      mastermind && _daily == null && appState.mastermindLargest;

  /// The noun of what is hidden.
  String get _noun => equations ? 'equation' : 'word';

  /// The rows of the board: the tries, or in the endless mastermind one for
  /// each guess made and the one being typed.
  int get _boardRows => mastermind ? guesses.length + (over ? 0 : 1) : tries;
  final _scroll = ScrollController();

  /// The hearts of a lockdown game, and how many are left: a daily has its own
  /// number, any other game the one chosen in the game modes.
  late final int heartsTotal = !lockdown
      ? 0
      : (widget.hearts ??
            (_daily != null && _daily.date.isNotEmpty
                ? dailyHearts
                : appState.hearts));
  late int hearts = heartsTotal;

  /// The shake of the board when a heart breaks: 0 at rest, then 1 to 0.
  late final AnimationController _rumble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Whether the daily is drawn by the curve from the whole list (from
  /// [dailyCurveFrom]) rather than the old way: the most common [dailyAnswers]
  /// words, each equally likely. A puzzle a link carries has no date.
  late final bool _curveDaily =
      _daily != null && _daily.date.isNotEmpty && dailyUsesCurve(_daily.date);

  /// How the answer is drawn, and so the chances its scores are worked out
  /// under: the setting, the curve for a daily, and equal chances for the old
  /// daily and for a puzzle from a link.
  late final Draw draw = equations || mastermind
      ? Draw.equal
      : _daily == null
      ? appState.draw
      : _curveDaily
      ? Draw.sigmoid
      : Draw.equal;

  /// How many words the answer was drawn from: every word of the length, or for
  /// an old daily the most common [dailyAnswers] of them.
  late final int pool = _daily == null || _curveDaily
      ? widget.bank.answers(length).length
      : min(dailyAnswers, widget.bank.answers(length).length);
  late final List<String> _pool;
  late final Set<String> _letters;

  late String answer;
  late List<String> eligible;
  final guesses = <String>[];
  final marks = <List<Mark>>[];

  /// The colours a player of a blind game has pencilled, by tapping letters of
  /// the guesses so far. With the colour logic on, [pencil] keeps them by
  /// letter and position under its rules; off, [notes] keeps one per tile, free.
  /// They are notes: nothing scores by them.
  late final pencil = BlindPencil(length);
  final notes = <List<Mark?>>[];

  /// Whether a blind game marks what the counts settle and keeps the player's
  /// colours possible: the colour logic of the game modes.
  bool get _assist => blind && appState.blindAssist;
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
    length =
        _daily?.length ?? (equations ? appState.eqLength : appState.length);
    tries =
        _daily?.tries ??
        (mastermind
            ? 0
            : lockdown
            ? lockdownTries
            : blind
            ? appState.blindTries
            : appState.tries);
    _pool = widget.bank.answers(length);
    _letters = widget.bank.letters(length);
    _reset();
    _resume();
    _replay();
  }

  /// The guesses a link carried are played at once, as if the page had been
  /// left half played. Nothing is saved or counted: it is practice.
  void _replay() {
    for (final g in widget.replay) {
      if (over || g.length != length || !widget.bank.valid.contains(g)) break;
      _apply(g, restoring: true);
    }
  }

  /// A daily left half played, or finished, comes back as it was, so that
  /// closing the page cannot reroll it. Nothing is recorded again: the game was
  /// counted when it ended.
  void _resume() {
    final key = _saveKey;
    if (key == null) return;
    final d = _daily;
    final extra = appState.progressFor(key);
    List<String> saved;
    List<List<Mark>>? savedMarks;
    DailyEntry? entry;
    if (d != null) {
      entry = appState.dailyFor(widget.bank.language.code, d.date, mode);
      saved = entry?.guesses ?? const [];
    } else {
      // any other game comes back with the answer it was drawn with
      final a = extra?['a'];
      if (extra == null) return;
      saved = [for (final g in extra['g'] ?? []) g as String];
      if (mastermind) {
        // the mastermind has no answer to come back to: what it said to each
        // guess is what is kept
        try {
          savedMarks = [
            for (final row in extra['m'] as List)
              [for (final i in row as List) Mark.values[i as int]],
          ];
        } catch (_) {
          return;
        }
        if (savedMarks.length != saved.length ||
            savedMarks.any((r) => r.length != length)) {
          return;
        }
      } else {
        if (a is! String || a.length != length) return;
        answer = a;
        if (prefetchDefinitions && !_noDictionary) {
          final lang = widget.bank.language;
          Wiktionary.shared.prefetch(answer, lang.code, lang.wikt);
        }
      }
    }
    for (final (i, g) in saved.indexed) {
      // a damaged save stops the replay rather than breaking the game
      if (over || g.length != length || !widget.bank.valid.contains(g)) break;
      _apply(g, restoring: true, given: savedMarks?[i]);
    }
    // the hearts lost to words that are not in the list are not in the guesses
    final left = entry?.hearts ?? extra?['h'];
    if (lockdown && left is int && left >= 0 && left <= heartsTotal) {
      hearts = left;
    }
    // a lockdown daily can be over with tries to spare: no hearts left
    if (!over && entry != null && entry.over) {
      over = true;
      won = entry.won ?? false;
    }
    if (over || extra == null) return;
    // the row, its locks and a blind game's colours as they were left
    try {
      final inp = extra['in'];
      if (inp is Map) input.restore(inp.cast<String, dynamic>());
      final pen = extra['p'];
      if (pen is Map) pencil.restore(pen.cast<String, dynamic>());
      final n = extra['n'];
      if (n is List && n.length == notes.length) {
        for (var r = 0; r < notes.length; r++) {
          final row = n[r] as List;
          if (row.length != length) continue;
          for (var i = 0; i < length; i++) {
            final v = row[i] as int;
            notes[r][i] = v < 0 ? null : Mark.values[v];
          }
        }
      }
    } catch (_) {}
  }

  /// Where this game is kept while it is played, or null when it is not kept (a
  /// practice, a puzzle from a link).
  String? get _saveKey {
    if (widget.practice || widget.chosen || widget.replay.isNotEmpty) {
      return null;
    }
    final lang = widget.bank.language.code;
    final d = _daily;
    if (d != null) {
      return d.date.isEmpty ? null : 'd|$lang|${d.date}|${mode.name}';
    }
    return 'p|$lang|${mode.name}|$length|$tries${largest ? '|L' : ''}';
  }

  /// Keeps the game as it stands, to be resumed; a finished game is not kept.
  void _save() {
    final key = _saveKey;
    if (key == null) return;
    if (over) {
      appState.clearProgress(key);
      return;
    }
    appState.saveProgress(key, {
      'a': answer,
      'g': guesses,
      'h': hearts,
      if (mastermind)
        'm': [
          for (final r in marks) [for (final m in r) m.index],
        ],
      'in': input.toJson(),
      'p': pencil.toJson(),
      'n': [
        for (final row in notes) [for (final m in row) m?.index ?? -1],
      ],
    });
  }

  @override
  void dispose() {
    _jobs.close();
    _rumble.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    // the mastermind has no answer: it is whichever word is left at the end
    answer = mastermind
        ? ''
        : _daily?.answer ??
              chooseWord(_pool, widget.bank.drawWeights(length, draw), _rng);
    // Every word the game accepts counts as possible, so a real word that fits
    // every clue is never ruled out behind the player's back. A daily is the
    // exception: only its 3,000 words can be the answer, and the scores
    // (against the chance of each possible answer) are of those.
    eligible = List.of(
      _daily == null || _daily.date.isEmpty || _curveDaily
          ? widget.bank.guessable(length)
          : widget.bank.answers(length).take(dailyAnswers),
    );
    _jobs.close(); // work on the last game's guesses is no longer wanted
    _jobs = JobQueue();
    _epoch++;
    _analysis.clear();
    guesses.clear();
    marks.clear();
    notes.clear();
    pencil.clear();
    keyMarks.clear();
    metrics.clear();
    befores.clear();
    input.clear();
    message = '';
    over = won = false;
    hearts = heartsTotal;
    unlocked = [];
    // score the opening while the first guess is being chosen
    if (analyseWhilePlaying) {
      warmOpening(
        eligible,
        widget.bank.guessable(length),
        weights: _law,
        blind: blind,
      );
    }
    // look the answer up now, so the end screen has it
    if (prefetchDefinitions && !_noDictionary) {
      final lang = widget.bank.language;
      Wiktionary.shared.prefetch(answer, lang.code, lang.wikt);
    }
  }

  void _type(String ch) {
    if (over) return;
    setState(() {
      if (input.type(ch, _letters) >= 0) message = '';
    });
    _save();
  }

  /// Erases the row being typed (a swipe from right to left over it, or shift
  /// and backspace).
  void _clearRow() {
    if (over) return;
    setState(() {
      if (input.clearTyped()) {
        message = '';
        Haptics.fire(Haptic.erase);
      }
    });
    _save();
  }

  void _back() {
    if (over) return;
    setState(() {
      if (input.back() >= 0) message = '';
    });
    _save();
  }

  final _shift = ShiftTap();
  final _ctrl = ShiftTap.ctrl();

  /// Shift locks the letter under the cursor, or unlocks it.
  void _toggleLockAtCursor() {
    if (over) return;
    setState(() => input.toggleLock(input.cursor));
    Haptics.lockToggled(locked: input.isLocked(input.cursor));
    _save();
  }

  /// Control, in a blind game, cycles the colour of the letter under the
  /// cursor: the one typed there, as it was guessed at that slot, or with the
  /// slot empty the last guess's letter at it.
  void _cycleAtCursor() {
    if (!blind || over || guesses.isEmpty) return;
    Haptics.fire(Haptic.tap);
    final i = input.cursor;
    if (i >= length) return;
    var r = guesses.length - 1;
    if (input.isLetter(i)) {
      while (r >= 0 && guesses[r][i] != input.slot(i)) {
        r--;
      }
      if (r < 0) return;
    }
    _pencil(r, i);
  }

  void _select(int i) {
    if (over) return;
    setState(() {
      // a second tap on a tile locks its letter, or lets it go
      if (input.tap(i)) Haptics.lockToggled(locked: input.isLocked(i));
    });
    _save();
  }

  /// A double tap on the submitted guesses locks every green found so far,
  /// replacing the locks the player had set. A blind game has no board to tap
  /// (its tiles cycle colours), so it is a double tap on the counts, and the
  /// greens are those pencilled.
  void _lockGreens() {
    if (over) return;
    final deduced = _deduced;
    final greens = <(int, String)>[
      for (var r = 0; r < marks.length; r++)
        for (var i = 0; i < length; i++)
          if ((blind
                  ? (_assist
                        ? pencil.shown(guesses[r][i], i, deduced)
                        : notes[r][i])
                  : marks[r][i]) ==
              Mark.correct)
            (i, guesses[r][i]),
    ];
    setState(() => input.lockAll(greens));
    Haptics.fire(Haptic.lock);
    _save();
    showToast(context, 'all greens are locked');
  }

  void _move(int by) {
    if (over) return;
    setState(() => input.move(by));
    _save();
  }

  void _submit() {
    if (over) return;
    if (!input.complete) {
      Haptics.fire(Haptic.reject);
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    final word = widget.bank.resolve(input.word);
    if (guesses.contains(word)) {
      Haptics.fire(Haptic.reject);
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(word)) {
      // in lockdown a word that is not in the list costs a heart
      if (lockdown) {
        setState(_loseHeart);
        return;
      }
      Haptics.fire(Haptic.reject);
      setState(
        () => message = equations
            ? equationProblem(word) ?? 'not an equation of the list'
            : themed
            ? 'not a place name'
            : 'not in the word list',
      );
      return;
    }
    setState(() => _apply(word));
    // an endless board grows: keep the row being typed in view
    if (mastermind) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// A word that is not in the list: it costs a heart, which breaks with a
  /// rumble and a crack. With no hearts left the game is lost.
  void _loseHeart() {
    if (hearts <= 0) return;
    hearts--;
    message = 'not in the word list';
    Haptics.fire(Haptic.heartBreak);
    Sounds.crack();
    if (!MediaQuery.disableAnimationsOf(context)) _rumble.forward(from: 0);
    if (hearts == 0) {
      over = true;
      won = false;
      message = '';
      input.clear();
      _finish();
    }
    _saveDaily();
  }

  /// Keeps a daily's progress, with the hearts it has left.
  void _saveDaily() {
    _save();
    final d = _daily;
    if (d == null || widget.practice) return;
    appState.saveDaily(
      widget.bank.language.code,
      d.date,
      guesses,
      won: over ? won : null,
      mode: mode,
      hearts: lockdown ? hearts : null,
    );
  }

  /// Plays [word], which has been checked. [restoring] replays a saved daily
  /// guess: it is not saved or recorded again.
  void _apply(String word, {bool restoring = false, List<Mark>? given}) {
    final List<Mark> m;
    if (mastermind) {
      // the word dodges: it answers as one of the words still possible would
      // (a saved game gives what it said), and the guess that is that word wins
      m =
          given ??
          (largest
              ? mastermindLargest(eligible, word)
              : _daily != null && _daily.date.isNotEmpty
              // a daily draws its replies from the date: the same for everyone
              ? mastermindDailyReply(
                  eligible,
                  word,
                  widget.bank.language.code,
                  _daily.date,
                  guesses.length,
                )
              : mastermindReply(eligible, word, _rng));
      if (m.every((x) => x == Mark.correct)) answer = word;
    } else {
      m = evaluate(answer, word, blind: blind);
    }
    guesses.add(word);
    marks.add(m);
    if (blind) notes.add(List.filled(length, null));
    for (var i = 0; i < length; i++) {
      final k = word[i];
      final old = keyMarks[k];
      // correct beats present beats absent
      if (old == null || m[i].index < old.index) keyMarks[k] = m[i];
    }
    final after = filterEligible(eligible, word, m, blind: blind);
    final measured = scoreGuess(
      eligible,
      word,
      after.length,
      // (the mastermind has no tries to run out of)
      finalTry: !mastermind && guesses.length >= tries,
      solved: word == answer,
      triesLeft: mastermind ? 99 : tries - (guesses.length - 1),
      weights: _law,
      afterWords: after,
      // skill is measured against the best real guess, which the
      // background analysis is still finding out
      provisional: analyseWhilePlaying,
      fresh: freshLetters(word, guesses.take(guesses.length - 1)),
      // the places of a blind game's greens are not shown
      greens: blind ? 0 : knownGreens(marks.take(marks.length - 1)),
      blind: blind,
    );
    // a reply with no chance in it has no luck
    metrics.add(largest ? measured.withoutLuck() : measured);
    befores.add(eligible);
    eligible = after;
    // the word is known once one is left: look it up before it is guessed
    if (mastermind && eligible.length == 1 && prefetchDefinitions) {
      final lang = widget.bank.language;
      Wiktionary.shared.prefetch(eligible.first, lang.code, lang.wikt);
    }
    // work the guess out now, in the background, one at a time: the best
    // real split (for its skill) and the picks and plots of the review
    final before = befores.last;
    final index = guesses.length - 1;
    final epoch = _epoch;
    if (analyseWhilePlaying) {
      final job = _jobs.add(
        () => analyseOffThread(
          before,
          // in lockdown skill is measured against the guesses that were allowed
          lockdown
              ? lockedGuesses(
                  widget.bank.guessable(length),
                  guesses.take(index).toList(),
                  marks.take(index).toList(),
                )
              : widget.bank.guessable(length),
          weights: _law,
          // (the mastermind's word is not settled until the end)
          answer: mastermind ? null : answer,
          blind: blind,
        ),
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
    _afterGuess(word, m, restoring);
  }

  /// What follows a guess, scored or not: the row moves on, a lockdown locks its
  /// greens and the game may end.
  void _afterGuess(String word, List<Mark> m, bool restoring) {
    final solved = word == answer;
    input.next();
    // in lockdown a letter in the right place is locked for the rest of the game
    if (lockdown && !solved) {
      input.lockFixed([
        for (var i = 0; i < length; i++)
          if (m[i] == Mark.correct) (i, word[i]),
      ]);
    }
    message = '';
    if (solved || (tries > 0 && guesses.length >= tries)) {
      over = true;
      won = solved;
      // nothing is kept once the game is over: no letter stays locked
      input.clear();
      if (!restoring) {
        Haptics.fire(solved ? Haptic.win : Haptic.lose);
        _finish();
      }
    }
    if (!restoring) _saveDaily();
  }

  /// The finished game counts towards the statistics and achievements. Skill
  /// is final only once every guess has been analysed, so that is waited for.
  void _finish() {
    // practice is not counted
    if (widget.practice) return;
    final epoch = _epoch;
    void record() {
      final d = _daily;
      final traits = gameTraits(metrics);
      // an endless game is kept with the tries it took: a record has at least one
      final triesKept = mastermind ? guesses.length.clamp(1, 40) : tries;
      GameResult result({
        int streak = 0,
        String? style,
        bool styleChanged = false,
        int stylesHeld = 0,
      }) => GameResult(
        mode: mode,
        hearts: heartsTotal,
        heartsLeft: hearts,
        lang: widget.bank.language.code,
        length: length,
        tries: triesKept,
        pool: pool,
        used: guesses.length,
        won: won,
        largest: largest,
        skills: [for (final m in metrics) m.skill],
        // (a reply with no chance in it has no luck to average)
        luck: largest ? null : traits.luck,
        risk: traits.risk,
        maxBits: traits.maxBits,
        daily: d != null,
        date: d?.date ?? '',
        dailyStreak: streak,
        style: style,
        styleChanged: styleChanged,
        stylesHeld: stylesHeld,
      );
      final played = result();
      // the game goes in the history as it was played (the guesses are the
      // facts, the scores can be worked out again), then the playstyle is read
      // from the last 100 games with this one in them, and the day goes in the
      // log, so the streak and the style it leaves are known to the
      // achievements; skill is final here, so the double fire can be judged
      // (a lockdown game lost to bad words before any guess has nothing to review)
      int? savedId;
      if (guesses.isNotEmpty) {
        savedId = appState.recordHistory(
          lang: widget.bank.language.code,
          mode: mode,
          length: length,
          tries: triesKept,
          pool: pool,
          answers: [answer],
          won: won,
          guesses: [
            for (var i = 0; i < metrics.length; i++) guessRowOf(i, metrics[i]),
          ],
          daily: d?.date ?? '',
          draw: draw,
          largest: largest,
        );
      }
      final code = widget.bank.language.code;
      final rated = appState.updateStyle(lang: code, mode: mode);
      final streak = d == null
          ? 0
          : appState.recordDaily(
              d.date,
              played.dailyTier,
              lang: code,
              mode: mode,
            );
      unlocked = topLevels(
        appState.recordGame(
          result(
            streak: streak,
            style: rated.style?.id,
            styleChanged: rated.changed,
            stylesHeld: appState.stylesHeldOf(code, mode).length,
          ),
        ),
      );
      // what it earned stays with the game in the history
      if (savedId != null) appState.markEarned(savedId, unlocked);
      // the end panel lists what was earned: a knock for each step of it
      if (unlocked.isNotEmpty) {
        // after the knocks of the win, or the buzz of the loss, are over
        Haptics.fireLater(Haptic.reward, const Duration(milliseconds: 600));
      }
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
    if (_shift.tapped(e)) {
      _toggleLockAtCursor();
      return KeyEventResult.handled;
    }
    if (_ctrl.tapped(e) && blind) {
      _cycleAtCursor();
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _submit();
    } else if (e.logicalKey == LogicalKeyboardKey.backspace ||
        e.logicalKey == LogicalKeyboardKey.delete) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _clearRow();
      } else {
        _back();
      }
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(1);
    } else if (e.character != null) {
      final ch = e.character!.toLowerCase();
      _type(equations ? typedEquationChar(ch) : ch);
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
          actions: [
            // the daily is not shared: anyone can open the app and play it
            if ((_daily == null || _daily.date.isEmpty) && !_noDictionary)
              SharePuzzleButton(
                (withGuesses) => Puzzle.hashed(
                  widget.bank.language.code,
                  mode,
                  length: length,
                  tries: tries,
                  answers: [answer],
                  guesses: withGuesses ? List.of(guesses) : const [],
                ),
              ),
            ModeHelpButton(
              mode: mode,
              daily: _daily != null && _daily.date.isNotEmpty,
            ),
          ],
          centerTitle: true,
          title: gameTitle(
            context,
            language: widget.bank.language,
            mode: mode,
            text: gameTitleText(
              date: _daily?.date ?? '',
              length: length,
              tries: tries,
              endless: mastermind,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(child: _shake(_grid())),
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: over ? 0 : 56),
                        child: Center(
                          child: _shake(
                            lockdown
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HeartsRow(
                                        total: heartsTotal,
                                        left: hearts,
                                      ),
                                      const SizedBox(height: 6),
                                      _status(c),
                                    ],
                                  )
                                : _status(c),
                          ),
                        ),
                      ),
                      // the panel is drawn over the boards, which run on under it
                      // (see [_grid]'s padding), so lowering it shows them
                      if (!over) _keyboard(c),
                      const SizedBox(height: 12),
                    ],
                  ),
                  if (over) Positioned.fill(child: _overPanel(c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [child] shaken while a heart breaks: it jolts from side to side and
  /// settles, with the strength dying away.
  Widget _shake(Widget child) => AnimatedBuilder(
    animation: _rumble,
    child: child,
    builder: (context, child) {
      final t = _rumble.value;
      final k = t == 0 || t == 1 ? 0.0 : (1 - t);
      return Transform.translate(
        offset: Offset(sin(t * 38) * 4 * k, cos(t * 31) * 2 * k),
        child: child,
      );
    },
  );

  Widget _grid() {
    final c = Theme.of(context).colorScheme;
    final deduced = _deduced;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        // the counts of a blind game are two more tiles, to the right of the
        // row, 8 and 6 from it and from each other
        // the info dot of a themed row, with as much room on the left so the
        // tiles stay in the middle
        const dotSlot = 26.0;
        final tile = blind
            ? min(
                56.0,
                (box.maxWidth - 32 - gap * (length - 1) - 14) / (length + 2),
              )
            : min(
                56.0,
                (box.maxWidth -
                        32 -
                        (themed ? 2 * dotSlot : 0) -
                        gap * (length - 1)) /
                    length,
              );
        Widget rowAt(int r) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: _withTrailing(
            r,
            tile,
            _swipeClear(
              r == guesses.length && !over,
              Row(
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
                      r < marks.length
                          ? (blind
                                ? (_assist
                                      ? pencil.shown(guesses[r][i], i, deduced)
                                      : notes[r][i])
                                : marks[r][i])
                          : null,
                      active: r == guesses.length && !over,
                      cursor: r == guesses.length && !over && i == input.cursor,
                      key: ValueKey('tile-$r-$i'),
                      locked: r == guesses.length && input.isLocked(i),
                      fixed: r == guesses.length && input.isFixed(i),
                      onTap: r == guesses.length && !over
                          ? () => _select(i)
                          : blind && r < guesses.length && !over
                          ? () => _pencil(r, i)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return SingleChildScrollView(
          key: const ValueKey('boards-scroll'),
          controller: _scroll,
          // when the game is over the end panel covers the lower half: room
          // under the last row so it can be scrolled above it, while the boards
          // run on beneath for when the panel is lowered
          padding: EdgeInsets.fromLTRB(
            11,
            8,
            11,
            8 + (over ? ResizablePanel.restHeight(context) : 0),
          ),
          child: Center(
            child: Column(
              children: [
                // the submitted guesses, gaps between the rows included, are
                // one place to double tap for the greens
                if (!blind && !over && guesses.isNotEmpty)
                  GestureDetector(
                    key: const ValueKey('greens-area'),
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _lockGreens,
                    child: Column(
                      children: [
                        for (var r = 0; r < guesses.length; r++) rowAt(r),
                      ],
                    ),
                  ),
                for (
                  var r = !blind && !over ? guesses.length : 0;
                  r < _boardRows;
                  r++
                )
                  rowAt(r),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A swipe from right to left over [row], when it is the one being typed
  /// ([typing]), erases it.
  Widget _swipeClear(bool typing, Widget row) =>
      typing ? SwipeClear(onClear: _clearRow, child: row) : row;

  /// A tap on tile [i] of submitted guess [r] in a blind game. With the colour
  /// logic off the tile takes the next colour of none, green, yellow, grey;
  /// on, the next one that keeps the rules, and a toast says why one was
  /// passed over.
  void _pencil(int r, int i) {
    if (!_assist) {
      setState(() => notes[r][i] = _nextNote(notes[r][i]));
      _save();
      return;
    }
    late final String? why;
    setState(() => why = pencil.tap(guesses[r][i], i, _rows, _deduced));
    _save();
    if (why == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(why!),
        ),
      );
  }

  /// The guesses with their counts, for the pencil's rules.
  List<BlindRow> get _rows => [
    for (var r = 0; r < marks.length; r++)
      BlindRow(
        guesses[r],
        marks[r].where((m) => m == Mark.correct).length,
        marks[r].where((m) => m == Mark.present).length,
      ),
  ];

  /// What a blind game's counts settle outright, marked for the player (with
  /// the colour logic on): a guess with no right letters rules all of its
  /// letters out; one whose counts add up to the length has all of its letters
  /// in the word, and every other letter out.
  Map<String, Mark> get _deduced =>
      _assist ? BlindPencil.deduce(_rows, _letters) : const {};

  /// The colour after [m] in the cycle a tap goes through: none, green,
  /// yellow, grey, and round to none.
  static Mark? _nextNote(Mark? m) => switch (m) {
    null => Mark.correct,
    Mark.correct => Mark.present,
    Mark.present => Mark.absent,
    Mark.absent => null,
  };

  Widget _withTrailing(int r, double tile, Widget row) {
    final c = Theme.of(context).colorScheme;
    if (blind) {
      final done = r < marks.length;
      var green = 0, yellow = 0;
      if (done) {
        green = marks[r].where((m) => m == Mark.correct).length;
        yellow = marks[r].where((m) => m == Mark.present).length;
      }
      Widget count(int n, Color fill, Color fg, String kind) => Container(
        key: ValueKey('count-$r-$kind'),
        width: tile,
        height: tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: tile * .5,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          const SizedBox(width: 8),
          GestureDetector(
            key: ValueKey('counts-$r'),
            behavior: HitTestBehavior.opaque,
            onDoubleTap: done ? _lockGreens : null,
            child: Opacity(
              opacity: done ? 1 : 0,
              child: Row(
                children: [
                  count(
                    green,
                    markColors(c, Mark.correct).$1,
                    markColors(c, Mark.correct).$2,
                    'g',
                  ),
                  const SizedBox(width: 6),
                  count(
                    yellow,
                    markColors(c, Mark.present).$1,
                    markColors(c, Mark.present).$2,
                    'y',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (themed) {
      final place = r < guesses.length ? Geography.placeOf(guesses[r]) : null;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 26),
          row,
          SizedBox(
            width: 26,
            child: place == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: PlaceDot(place, key: ValueKey('place-dot-$r')),
                  ),
          ),
        ],
      );
    }
    return row;
  }

  Widget _tile(
    ColorScheme c,
    double size,
    String ch,
    Mark? m, {
    required bool active,
    bool cursor = false,
    bool locked = false,
    bool fixed = false,
    Key? key,
    VoidCallback? onTap,
  }) {
    Color? fill;
    Color fg = c.onSurface;
    Color border = active
        ? c.onSurface.withValues(alpha: .5)
        : c.outlineVariant;
    var borderWidth = 1.0;
    // the game's lock (a green in lockdown) is green; the player's own is pink
    final lockColor = fixed ? markColors(c, Mark.correct).$1 : c.primary;
    if (m != null) {
      (fill, fg) = markColors(c, m);
      border = markBorder(c, m);
      borderWidth = markBorderWidth(m);
    } else if (ch.isNotEmpty) {
      border = locked ? lockColor : c.onSurface;
    }
    // the cursor is the ink colour, the lock the pink accent
    if (cursor) {
      border = c.onSurface;
      borderWidth = 2;
    }
    final isBlank = ch == GuessInput.blank;
    return GestureDetector(
      key: key,
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
        // the whole tile, so the lock sits in its corner, not by the letter
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                isBlank ? '_' : faceOf(ch),
                style: TextStyle(
                  fontSize: size * .5,
                  fontWeight: FontWeight.bold,
                  color: isBlank ? fg.withValues(alpha: dimAlpha) : fg,
                ),
              ),
              if (locked)
                Positioned(
                  top: 3,
                  right: 3,
                  child: TablerIcon(
                    'lock',
                    key: const ValueKey('locked'),
                    size: size * .22,
                    color: lockColor,
                  ),
                ),
            ],
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
    // the daily never shows the helper: only the tries left
    final h = _daily != null || blind || themed || equations
        ? Helper.off
        : appState.helper;
    if (mastermind) {
      return Caption(
        guesses.isEmpty
            ? (largest
                  ? 'no limit · it keeps the largest pool'
                  : 'no limit · it dodges as long as it can')
            : '${guesses.length} ${guesses.length == 1 ? 'guess' : 'guesses'}',
      );
    }
    final triesLeft = '${tries - guesses.length} tries left';
    final left = lockdown
        ? '$hearts ${hearts == 1 ? 'heart' : 'hearts'} · $triesLeft'
        : triesLeft;
    if (guesses.isEmpty) return Caption(left);
    final m = metrics.last;
    final parts = <(String, String?)>[
      if (h.showSkill)
        ('skill ${m.ready ? m.skill.toStringAsFixed(1) : '…'}', 'skill'),
      if (h.showLuck) ('luck ${luckText(m.luck)}', 'luck'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parts.isNotEmpty)
          Caption.rich(
            metricParts(c, [
              ('last guess · ', null),
              for (final (i, p) in parts.indexed) ...[
                if (i > 0) (' · ', null),
                p,
              ],
            ]),
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

  /// The law the answer was drawn by, as weights; null when every possible
  /// word was as likely as the next (frequency off, and every daily).
  Map<String, int>? get _law => widget.bank.law(length, draw);

  GameRecord _record() => GameRecord(
    bank: widget.bank,
    kind: drawKindOf(
      draw,
      daily: _daily?.date ?? '',
      mode: mode,
      chosen: widget.chosen,
    ),
    daily: _daily != null && _daily.date.isNotEmpty,
    blind: blind,
    lockdown: lockdown,
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
    weights: _law,
    analysis: List.of(_analysis),
    luckless: largest,
  );

  /// A one-line summary with the review button; the helper's step-by-step
  /// analysis is in the review.
  Widget _summary(ColorScheme c) {
    if (metrics.isEmpty) return const SizedBox();
    double avg(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    return Row(
      children: [
        Expanded(
          child: Caption.rich(
            metricParts(c, [
              ('average ', null),
              (
                'skill ${metrics.every((m) => m.ready) ? avg(metrics.map((m) => m.skill)).round() : '…'}',
                'skill',
              ),
              // (a reply with no chance in it has no luck)
              if (!largest) ...[
                (' · ', null),
                ('luck ${luckText(avg(metrics.map((m) => m.luck)))}', 'luck'),
              ],
            ]),
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
    return ResizablePanel(
      header: Row(
        children: [
          Expanded(
            child: Text(
              won
                  ? (mastermind
                        ? 'solved in ${guesses.length}'
                        : 'solved in ${guesses.length} of $tries')
                  : 'the $_noun was  ${equations ? answer.split('').map(faceOf).join() : answer}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // a daily is played once: the next word comes tomorrow
          if (_daily == null) _smallButton('replay', () => setState(_reset)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          if (_daily != null)
            Caption(
              widget.practice
                  ? 'practice${_daily.date.isEmpty ? '' : ' ${_daily.date}'} · not counted'
                  : 'daily ${_daily.date} · streak ${appState.dailyStreak} · '
                        'the next word comes at midnight, your time',
            ),
          // the answer, said as such (a win used to show it bare)
          if (won)
            Row(
              children: [
                Expanded(
                  child: Caption(
                    'the $_noun was ${equations ? answer.split('').map(faceOf).join() : answer}',
                  ),
                ),
                if (!equations && !themed)
                  SaveWordButton(word: answer, language: widget.bank.language),
              ],
            ),
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
          if (!equations)
            WordInfoView(word: answer, language: widget.bank.language),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _keyboard(ColorScheme c) => LetterKeyboard(
    letters: _letters,
    numberPad: equations,
    onCursor: _move,
    marks: blind
        ? (_assist ? pencil.keyboard(_deduced, _letters) : const {})
        : keyMarks,
    onLetter: _type,
    onBlank: () => _type(GuessInput.blank),
    onEnter: _submit,
    onBack: _back,
  );
}
