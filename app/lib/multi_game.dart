import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'multi_review.dart';
import 'routes.dart';
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
  const MultiGamePage({super.key, required this.bank, this.random});
  final WordBank bank;

  /// Where the answers are drawn from; tests pass a seeded one.
  final Random? random;

  @override
  State<MultiGamePage> createState() => _MultiGamePageState();
}

class _MultiGamePageState extends State<MultiGamePage> {
  late final Random _rng = widget.random ?? Random();
  final _focus = FocusNode();

  late final GameMode mode = appState.mode;
  late final int length;
  late final int tries;
  late final List<String> _pool;
  late final Set<String> _letters;

  late MultiGame game;
  String input = '';
  String message = '';

  /// What the finished game earned.
  List<Achievement> unlocked = [];

  /// The analysis of each guess, begun the moment it was made.
  var _jobs = JobQueue();
  final _analysis = <Future<List<MultiPick>>?>[];

  @override
  void initState() {
    super.initState();
    length = appState.length;
    tries = triesFor(mode, appState.tries);
    _pool = widget.bank.answers(length, appState.pool);
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
    _jobs.close(); // work on the last game's guesses is no longer wanted
    _jobs = JobQueue();
    _analysis.clear();
    unlocked = [];
    game = MultiGame(
      mode,
      chooseTargets(
        _pool,
        widget.bank.answerWeights(length, appState.pool),
        mode.boards,
        appState.share,
        _rng,
      ),
      tries,
      words: widget.bank.guessable(length),
    );
    input = '';
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
    if (game.over || input.length >= length || !_letters.contains(ch)) return;
    setState(() {
      input += ch;
      message = '';
    });
  }

  void _back() {
    if (game.over || input.isEmpty) return;
    setState(() {
      input = input.substring(0, input.length - 1);
      message = '';
    });
  }

  void _submit() {
    if (game.over) return;
    if (input.length != length) {
      setState(() => message = 'need $length letters');
      return;
    }
    if (game.guesses.contains(input)) {
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(input)) {
      setState(() => message = 'not in the word list');
      return;
    }
    setState(() {
      game.guess(input);
      input = '';
      message = '';
      // analyse this guess in the background, at once, so the review is ready
      final step = game.steps.last;
      _analysis.add(
        step.finalTry || !analyseWhilePlaying
            ? null // its picks are the words that fit, worked out when shown
            : _jobs.add(
                () => recommendMulti(
                  step.liveBefore,
                  multiCandidates(
                    step.liveBefore,
                    widget.bank.guessable(length),
                  ),
                ),
              ),
      );
      if (game.over) _finish();
    });
  }

  /// The finished game counts towards the achievements of its mode.
  void _finish() {
    unlocked = appState.recordGame(
      GameResult(
        lang: widget.bank.language.code,
        length: length,
        tries: tries,
        used: game.guesses.length,
        won: game.won,
        pool: appState.pool,
        mode: mode,
        skills: [for (final s in game.steps) s.skill],
        freeRides: game.freeRides,
      ),
    );
  }

  MultiRecord _record() => MultiRecord(
    bank: widget.bank,
    mode: mode,
    length: length,
    tries: tries,
    answers: [for (final b in game.boards) b.answer],
    guesses: List.of(game.guesses),
    steps: List.of(game.steps),
    won: game.won,
    analysis: List.of(_analysis),
  );

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
                  '${mode.label} · ${widget.bank.language.name.toLowerCase()}'
                  ' · $length · $tries tries',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          : (live &&
                                    r == game.guesses.length &&
                                    k < input.length
                                ? input[k]
                                : ''),
                      r < b.marks.length ? b.marks[r][k] : null,
                      active: live && r == game.guesses.length,
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
      border = c.onSurface;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
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

  Widget _keyboard() => LetterKeyboard(
    letters: _letters,
    // a quartet splits each key by board; a relay race colours the keys by the
    // board that is on, as a single game would
    marks: mode == GameMode.relay ? game.marksOf(game.active!) : const {},
    quadMarks: mode == GameMode.relay ? const {} : game.letterMarks(),
    onLetter: _type,
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
          child: Caption(
            'average skill ${avg((s) => s.skill).round()}'
            ' · luck ${luckText(avg((s) => s.luck))}',
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
