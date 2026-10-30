import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background.dart';
import 'daily.dart';
import 'game_header.dart';
import 'guess_input.dart';
import 'haptics.dart';
import 'history.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'multi_review.dart';
import 'puzzle.dart';
import 'review_text.dart';
import 'routes.dart';
import 'share_puzzle.dart';
import 'store.dart';
import 'ui.dart';
import 'wiktionary.dart';
import 'word_info.dart';
import 'words.dart';

/// Quartet and relay race: four boards that share every guess and one pool of
/// tries. A quartet plays them all at once; a relay race opens them one at a time.
///
/// While it is played, everything the end screen and the review need is worked
/// out in the background: the Wiktionary entry of every answer is looked up
/// and each guess is analysed as soon as it is made.
class MultiGamePage extends StatefulWidget {
  const MultiGamePage({
    super.key,
    required this.bank,
    this.random,
    this.daily,
    this.practice = false,
    this.replay = const [],
  });
  final WordBank bank;

  /// Set to play the daily quartet or relay race: its four words and the fixed
  /// daily difficulty, instead of a game drawn at random.
  final DailyMulti? daily;

  /// A daily opened by a link: played as practice, so nothing is saved or
  /// counted (no streak, history, statistics or achievements).
  final bool practice;

  /// Guesses a link carries, played at once when the page opens.
  final List<String> replay;

  /// Where the answers are drawn from; tests pass a seeded one.
  final Random? random;

  @override
  State<MultiGamePage> createState() => _MultiGamePageState();
}

class _MultiGamePageState extends State<MultiGamePage> {
  late final Random _rng = widget.random ?? Random();
  final _focus = FocusNode();

  late final DailyMulti? _daily = widget.daily;
  late final GameMode mode = _daily?.mode ?? appState.mode;
  late final int length;
  late final int tries;

  /// Whether the daily is drawn by the curve from the whole list (from
  /// [dailyCurveFrom]) rather than the old way: the most common [dailyAnswers]
  /// words, each equally likely. A puzzle a link carries has no date.
  late final bool _curveDaily =
      _daily != null && _daily.date.isNotEmpty && dailyUsesCurve(_daily.date);

  /// How the answers are drawn, and so the chances their scores are worked out
  /// under: the setting, the curve for a daily, and equal chances for the old
  /// daily and for a puzzle from a link.
  late final Draw draw = _daily == null
      ? appState.draw
      : _curveDaily
      ? Draw.sigmoid
      : Draw.equal;

  /// How many words the answers were drawn from: every word of the length, and
  /// for an old daily the most common [dailyAnswers] of them.
  late final int pool = _daily == null || _curveDaily
      ? widget.bank.answers(length).length
      : min(dailyAnswers, widget.bank.answers(length).length);
  late final List<String> _pool;
  late final Set<String> _letters;

  late MultiGame game;
  late final input = GuessInput(length);
  String message = '';

  /// What the finished game earned.
  List<Achievement> unlocked = [];

  /// The analysis of each guess, begun the moment it was made.
  var _jobs = JobQueue();
  final _analysis = <Future<MultiLandscape>?>[];

  /// Counts the games begun, so work for an earlier one is ignored.
  var _epoch = 0;

  @override
  void initState() {
    super.initState();
    length = _daily?.length ?? appState.length;
    tries = _daily?.tries ?? triesFor(mode, appState.tries);
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
      if (game.over || g.length != length || !widget.bank.valid.contains(g)) {
        break;
      }
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
      if (game.over || g.length != length || !widget.bank.valid.contains(g)) {
        break;
      }
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
    _jobs.close(); // work on the last game's guesses is no longer wanted
    _jobs = JobQueue();
    _analysis.clear();
    _epoch++;
    unlocked = [];
    game = MultiGame(
      mode,
      _daily?.answers ??
          chooseTargets(
            _pool,
            widget.bank.drawWeights(length, draw),
            mode.boards,
            appState.share,
            _rng,
          ),
      tries,
      words: widget.bank.guessable(length),
      possible: _daily == null || _curveDaily
          ? null
          : widget.bank.answers(length).take(dailyAnswers).toList(),
      provisional: analyseWhilePlaying,
      weights: _law,
    );
    input.clear();
    message = '';
    // look the answers up now, one at a time, so the end screen has them
    if (prefetchDefinitions) {
      final lang = widget.bank.language;
      for (final b in game.boards) {
        Wiktionary.shared.prefetch(b.answer, lang.code, lang.wikt);
      }
    }
  }

  void _type(String ch) {
    if (game.over) return;
    setState(() {
      if (input.type(ch, _letters) >= 0) message = '';
    });
  }

  void _back() {
    if (game.over) return;
    setState(() {
      if (input.back() >= 0) message = '';
    });
  }

  final _shift = ShiftTap();

  /// Shift locks the letter under the cursor, or unlocks it.
  void _toggleLockAtCursor() {
    if (game.over) return;
    setState(() => input.toggleLock(input.cursor));
  }

  void _select(int i) {
    if (game.over) return;
    setState(() => input.tap(i));
  }

  void _move(int by) {
    if (game.over) return;
    setState(() => input.move(by));
  }

  void _submit() {
    if (game.over) return;
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
    if (game.guesses.contains(word)) {
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(word)) {
      Haptics.fire(Haptic.reject);
      setState(() => message = 'not in the word list');
      return;
    }
    setState(() => _apply(word));
  }

  /// Plays [word], which has been checked. [restoring] replays a saved daily
  /// guess: it is not saved or recorded again.
  void _apply(String word, {bool restoring = false}) {
    game.guess(word);
    // nothing is kept once the game is over: no letter stays locked
    if (game.over) {
      input.clear();
    } else {
      input.next();
    }
    message = '';
    // analyse this guess in the background, at once: the best real split on
    // each board (for the skill) and the picks of the review
    final index = game.steps.length - 1;
    final step = game.steps[index];
    final epoch = _epoch;
    if (analyseWhilePlaying) {
      final job = _jobs.add(
        () => analyseMulti(
          step.liveBefore,
          widget.bank.guessable(length),
          weights: _law,
        ),
      );
      _analysis.add(job);
      job.then<void>((land) {
        if (!mounted || epoch != _epoch) return;
        setState(() {
          game.steps[index] = game.steps[index].withBests(land.bests);
        });
      }, onError: (_) {});
    } else {
      _analysis.add(null);
    }
    final d = _daily;
    if (d != null && !restoring && !widget.practice) {
      appState.saveDaily(
        widget.bank.language.code,
        d.date,
        game.guesses,
        won: game.over ? game.won : null,
        mode: mode,
      );
    }
    if (game.over && !restoring) {
      Haptics.fire(game.won ? Haptic.win : Haptic.lose);
      _finish();
    }
  }

  /// The finished game counts towards the achievements of its mode. Skill is
  /// final only once every guess has been analysed, so that is waited for.
  void _finish() {
    // practice is not counted
    if (widget.practice) return;
    final epoch = _epoch;
    void record() {
      final d = _daily;
      final code = widget.bank.language.code;
      final result = GameResult(
        lang: code,
        length: length,
        tries: tries,
        used: game.guesses.length,
        won: game.won,
        pool: pool,
        mode: mode,
        skills: [for (final s in game.steps) s.skill],
        freeRides: game.freeRides,
        daily: d != null,
      );
      // a step's skill and luck are the means over the boards it was made for;
      // a quartet or relay race has no daring or pool sizes of its own
      appState.recordHistory(
        lang: widget.bank.language.code,
        mode: mode,
        length: length,
        tries: tries,
        pool: pool,
        draw: draw,
        answers: [for (final b in game.boards) b.answer],
        won: game.won,
        guesses: [
          for (var i = 0; i < game.steps.length; i++)
            GuessRow(
              game: 0,
              n: i,
              word: game.guesses[i],
              skill: game.steps[i].skill,
              luck: game.steps[i].luck,
            ),
        ],
        daily: d?.date ?? '',
      );
      final streak = d == null
          ? 0
          : appState.recordDaily(
              d.date,
              result.dailyTier,
              lang: code,
              mode: mode,
            );
      unlocked = appState.recordGame(
        GameResult(
          lang: code,
          length: length,
          tries: tries,
          used: game.guesses.length,
          won: game.won,
          pool: pool,
          mode: mode,
          skills: [for (final s in game.steps) s.skill],
          freeRides: game.freeRides,
          daily: d != null,
          dailyStreak: streak,
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

  /// The law the answers were drawn by, as weights; null for equal chances.
  Map<String, int>? get _law => widget.bank.law(length, draw);

  MultiRecord _record() => MultiRecord(
    bank: widget.bank,
    mode: mode,
    length: length,
    tries: tries,
    answers: [for (final b in game.boards) b.answer],
    guesses: List.of(game.guesses),
    steps: List.of(game.steps),
    won: game.won,
    weights: _law,
    analysis: List.of(_analysis),
    kind: drawKindOf(draw, daily: _daily?.date ?? ''),
    daily: _daily != null && _daily.date.isNotEmpty,
  );

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
                  answers: [for (final b in game.boards) b.answer],
                  guesses: withGuesses ? List.of(game.guesses) : const [],
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Expanded(child: _boards(c)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Center(child: _status(c)),
                  ),
                  if (game.over) _overPanel(c) else _keyboard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(ColorScheme c) {
    if (message.isNotEmpty) {
      return Text(message, style: TextStyle(color: c.error));
    }
    if (game.over) return const SizedBox();
    final left = '${tries - game.guesses.length} tries left';
    final a = game.active;
    return Caption(
      a == null
          ? '${game.solvedCount} of ${mode.boards} solved · $left'
          : 'word ${a + 1} of ${mode.boards} · $left',
    );
  }

  Widget _boards(ColorScheme c) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 3.0;
        final boardWidth = (box.maxWidth - 32 - 14) / 2;
        final tile = min(40.0, (boardWidth - gap * (length - 1)) / length);
        Widget board(int i) => _board(c, i, tile, gap);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Column(
            children: [
              for (var row = 0; row < mode.boards; row += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      board(row),
                      if (row + 1 < mode.boards) board(row + 1),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _board(ColorScheme c, int i, double tile, double gap) {
    final b = game.boards[i];
    final live = game.isLive(i);
    final locked = game.isLocked(i);
    return Opacity(
      opacity: locked ? .35 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // the caption never widens the board: it shrinks to the tiles' width
          SizedBox(
            width: tile * length + gap * (length - 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Caption(
                  b.solved
                      ? '${i + 1} · solved in ${b.solvedAt! + 1}'
                      : (live && mode == GameMode.relay
                            ? '${i + 1} · now'
                            : '${i + 1}'),
                ),
              ),
            ),
          ),
          for (var r = 0; r < tries; r++)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < length; k++) ...[
                    if (k > 0) SizedBox(width: gap),
                    _tile(
                      c,
                      tile,
                      r < b.marks.length
                          ? game.guesses[r][k]
                          : (live && r == game.guesses.length
                                ? input.slot(k)
                                : ''),
                      r < b.marks.length ? b.marks[r][k] : null,
                      active: live && r == game.guesses.length,
                      cursor:
                          live && r == game.guesses.length && k == input.cursor,
                      locked:
                          live && r == game.guesses.length && input.isLocked(k),
                      onTap: live && r == game.guesses.length
                          ? () => _select(k)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    ColorScheme c,
    double size,
    String ch,
    Mark? m, {
    required bool active,
    bool cursor = false,
    bool locked = false,
    VoidCallback? onTap,
  }) {
    Color? fill;
    Color fg = c.onSurface;
    Color border = active
        ? c.onSurface.withValues(alpha: .5)
        : c.outlineVariant;
    if (m != null) {
      (fill, fg) = markColors(c, m);
      border = markBorder(c, m);
    } else if (ch.isNotEmpty) {
      border = locked ? c.primary : c.onSurface;
    }
    if (cursor) border = c.primary;
    final isBlank = ch == GuessInput.blank;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: cursor ? 2 : 1),
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

  Widget _keyboard() => LetterKeyboard(
    letters: _letters,
    // a quartet splits each key by board; a relay race colours the keys by the
    // board that is on, as a single game would
    marks: mode == GameMode.relay ? game.marksOf(game.active!) : const {},
    quadMarks: mode == GameMode.relay ? const {} : game.letterMarks(),
    onLetter: _type,
    onBlank: () => _type(GuessInput.blank),
    onEnter: _submit,
    onBack: _back,
  );

  /// One line with the review button: the average skill and luck of the
  /// guesses (see multi_analysis.dart for how a guess is scored).
  Widget _summary() {
    if (game.steps.isEmpty) return const SizedBox();
    double avg(double Function(MultiStep s) f) =>
        game.steps.map(f).reduce((a, b) => a + b) / game.steps.length;
    return Row(
      children: [
        Expanded(
          child: Caption.rich(
            metricParts(Theme.of(context).colorScheme, [
              ('average ', null),
              (
                'skill ${game.steps.every((s) => s.ready) ? avg((s) => s.skill).round() : '…'}',
                'skill',
              ),
              (' · ', null),
              ('luck ${luckText(avg((s) => s.luck))}', 'luck'),
            ]),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () =>
              Navigator.pushNamed(context, Routes.review, arguments: _record()),
          child: const Text('review'),
        ),
      ],
    );
  }

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
                    game.won
                        ? 'solved all ${mode.boards} in '
                              '${game.guesses.length} of $tries'
                        : 'solved ${game.solvedCount} of ${mode.boards}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // a daily is played once: the next words come tomorrow
                if (_daily == null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => setState(_reset),
                    child: const Text('replay'),
                  ),
              ],
            ),
            if (_daily != null)
              Caption(
                widget.practice
                    ? 'practice${_daily.date.isEmpty ? '' : ' ${_daily.date}'} · not counted'
                    : 'daily ${_daily.date} · streak '
                          '${appState.dailyStreakFor(widget.bank.language.code, mode)} · '
                          'the next words come at midnight, your time',
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
            const Divider(),
            const SizedBox(height: 10),
            _summary(),
            const SizedBox(height: 10),
            const Divider(),
            for (final b in game.boards)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  b.answer,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: b.solved ? c.secondary : c.error,
                  ),
                ),
                children: [
                  WordInfoView(word: b.answer, language: widget.bank.language),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
