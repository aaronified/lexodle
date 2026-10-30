import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_worker.dart';
import 'background.dart';
import 'daily.dart';
import 'game_header.dart';
import 'hearts.dart';
import 'modes.dart';
import 'puzzle.dart';
import 'share_puzzle.dart';
import 'geography.dart';
import 'guess_input.dart';
import 'place_info.dart';
import 'haptics.dart';
import 'history.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'review.dart';
import 'review_text.dart';
import 'routes.dart';
import 'main.dart';
import 'sounds.dart';
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
  });

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

  /// The hearts of a lockdown game, and how many are left: a daily has its own
  /// number, any other game the one chosen in the game modes.
  late final int heartsTotal = !lockdown
      ? 0
      : (_daily != null && _daily.date.isNotEmpty
            ? dailyHearts
            : appState.hearts);
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
  late final Draw draw = _daily == null
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

  /// The colours a player of a blind game has pencilled on the letters of the
  /// guesses so far, by tapping them: green, yellow, grey, or none. They are
  /// notes: nothing scores by them.
  final notes = <List<Mark?>>[];
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
    length = _daily?.length ?? appState.length;
    tries =
        _daily?.tries ??
        (lockdown
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
    final d = _daily;
    if (d == null || widget.practice) return;
    final saved = appState.dailyFor(widget.bank.language.code, d.date, mode);
    if (saved == null) return;
    for (final g in saved.guesses) {
      // a damaged save stops the replay rather than breaking the game
      if (over || g.length != length || !widget.bank.valid.contains(g)) break;
      _apply(g, restoring: true);
    }
    // the hearts lost to words that are not in the list are not in the guesses
    final left = saved.hearts;
    if (lockdown && left != null && left >= 0 && left <= heartsTotal) {
      hearts = left;
    }
    // a lockdown daily can be over with tries to spare: no hearts left
    if (!over && saved.over) {
      over = true;
      won = saved.won ?? false;
    }
  }

  @override
  void dispose() {
    _jobs.close();
    _rumble.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    answer =
        _daily?.answer ??
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

  final _shift = ShiftTap();

  /// Shift locks the letter under the cursor, or unlocks it.
  void _toggleLockAtCursor() {
    if (over) return;
    setState(() => input.toggleLock(input.cursor));
  }

  void _select(int i) {
    if (over) return;
    setState(() => input.tap(i));
  }

  void _move(int by) {
    if (over) return;
    setState(() => input.move(by));
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
        () => message = themed ? 'not a place name' : 'not in the word list',
      );
      return;
    }
    setState(() => _apply(word));
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
  void _apply(String word, {bool restoring = false}) {
    final m = evaluate(answer, word, blind: blind);
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
    metrics.add(
      scoreGuess(
        eligible,
        word,
        after.length,
        finalTry: guesses.length >= tries,
        solved: word == answer,
        triesLeft: tries - (guesses.length - 1),
        weights: _law,
        afterWords: after,
        // skill is measured against the best real guess, which the
        // background analysis is still finding out
        provisional: analyseWhilePlaying,
        fresh: freshLetters(word, guesses.take(guesses.length - 1)),
        greens: knownGreens(marks.take(marks.length - 1)),
        blind: blind,
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
          answer: answer,
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
    if (solved || guesses.length >= tries) {
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
        tries: tries,
        pool: pool,
        used: guesses.length,
        won: won,
        skills: [for (final m in metrics) m.skill],
        luck: traits.luck,
        risk: traits.risk,
        maxBits: traits.maxBits,
        daily: d != null,
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
      if (guesses.isNotEmpty) {
        appState.recordHistory(
          lang: widget.bank.language.code,
          mode: mode,
          length: length,
          tries: tries,
          pool: pool,
          answers: [answer],
          won: won,
          guesses: [
            for (var i = 0; i < metrics.length; i++) guessRowOf(i, metrics[i]),
          ],
          daily: d?.date ?? '',
          draw: draw,
        );
      }
      final code = widget.bank.language.code;
      final rated = appState.updateStyle(lang: code);
      final streak = d == null
          ? 0
          : appState.recordDaily(
              d.date,
              played.dailyTier,
              lang: code,
              mode: mode,
            );
      unlocked = appState.recordGame(
        result(
          streak: streak,
          style: rated.style?.id,
          styleChanged: rated.changed,
          stylesHeld: appState.stylesHeldOf(code).length,
        ),
      );
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
          actions: [
            // the daily is not shared: anyone can open the app and play it
            if (_daily == null || _daily.date.isEmpty)
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
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Expanded(child: _shake(_grid())),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Center(
                      child: _shake(
                        lockdown
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HeartsRow(total: heartsTotal, left: hearts),
                                  const SizedBox(height: 6),
                                  _status(c),
                                ],
                              )
                            : _status(c),
                      ),
                    ),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Center(
            child: Column(
              children: [
                for (var r = 0; r < tries; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: gap),
                    child: _withTrailing(
                      r,
                      tile,
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
                                  ? (blind ? notes[r][i] : marks[r][i])
                                  : null,
                              active: r == guesses.length && !over,
                              cursor:
                                  r == guesses.length &&
                                  !over &&
                                  i == input.cursor,
                              key: ValueKey('tile-$r-$i'),
                              locked: r == guesses.length && input.isLocked(i),
                              onTap: r == guesses.length && !over
                                  ? () => _select(i)
                                  : blind && r < notes.length && !over
                                  ? () => setState(
                                      () =>
                                          notes[r][i] = _nextNote(notes[r][i]),
                                    )
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A blind row's two counts (right and in place, right elsewhere), kept
  /// beside the tiles; the row is only as wide as the tiles in themed, whose
  /// info dot hangs off its right edge.
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
          Opacity(
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
    Key? key,
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
      border = locked ? c.primary : c.onSurface;
    }
    if (cursor) {
      border = c.primary;
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
                isBlank ? '_' : ch,
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
                    color: c.primary,
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
    final h = _daily != null || blind || themed ? Helper.off : appState.helper;
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
              (' · ', null),
              ('luck ${luckText(avg(metrics.map((m) => m.luck)))}', 'luck'),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .5,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 19),
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
                widget.practice
                    ? 'practice${_daily.date.isEmpty ? '' : ' ${_daily.date}'} · not counted'
                    : 'daily ${_daily.date} · streak ${appState.dailyStreak} · '
                          'the next word comes at midnight, your time',
              ),
            // the answer, said as such (a win used to show it bare)
            if (won) Caption('the word was $answer'),
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
    marks: blind ? const {} : keyMarks,
    onLetter: _type,
    onBlank: () => _type(GuessInput.blank),
    onEnter: _submit,
    onBack: _back,
  );
}
