import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'difficulty.dart';
import 'guess_input.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'ui.dart';
import 'words.dart';

/// What the solver knows about a quartet or a relay race being played
/// elsewhere: the guesses (every board shares them) and the colours each board
/// showed for each. Pure, so it is tested without UI.
///
/// A relay race opens a board when the one before it is solved, with every
/// earlier guess already applied to it, so the colours of those guesses on the
/// new board are entered afterwards: they start blank and are tapped in.
class MultiSolverState {
  MultiSolverState({
    required this.mode,
    required this.answers,
    required this.length,
    required this.tries,
  }) : marks = List.generate(mode.boards, (_) => []);

  final GameMode mode;

  /// The words an answer can be, from the difficulty's pool.
  final List<String> answers;
  final int length;

  /// The tries in all, which the boards share.
  final int tries;

  final guesses = <String>[];

  /// [marks][board][guess]: the colours board showed for that guess. A guess a
  /// board was not live for keeps blank colours, and is not read.
  final List<List<List<Mark>>> marks;

  int get boards => mode.boards;
  int get triesLeft => tries - guesses.length;

  List<Mark> blank() => List.filled(length, Mark.absent);

  /// The guess that solved board [i] (all green), if one has.
  int? solvedAt(int i) {
    for (var r = 0; r < marks[i].length; r++) {
      if (marks[i][r].every((m) => m == Mark.correct)) return r;
    }
    return null;
  }

  bool isSolved(int i) => solvedAt(i) != null;

  /// Whether board [i] is on: every board of a quartet, and a relay race's
  /// boards once the ones before are solved.
  bool isOpen(int i) {
    if (mode != GameMode.relay) return true;
    for (var j = 0; j < i; j++) {
      if (!isSolved(j)) return false;
    }
    return true;
  }

  /// How many guesses board [i] shows: none while it waits, then every guess
  /// made, or up to the one that solved it.
  int visible(int i) {
    if (!isOpen(i)) return 0;
    final s = solvedAt(i);
    return s == null ? guesses.length : s + 1;
  }

  bool get done => List.generate(boards, isSolved).every((s) => s);

  /// Whether the next guess is for board [i].
  bool isLive(int i) =>
      !done &&
      triesLeft > 0 &&
      isOpen(i) &&
      !isSolved(i) &&
      (mode != GameMode.relay ||
          [
                for (var j = 0; j < boards; j++)
                  if (isOpen(j) && !isSolved(j)) j,
              ].first ==
              i);

  /// The boards the next guess is for, in order.
  List<int> get live => [
    for (var i = 0; i < boards; i++)
      if (isLive(i)) i,
  ];

  /// The words still possible on board [i].
  List<String> eligibleOf(int i) {
    final s = solvedAt(i);
    if (s != null) return [guesses[s]];
    var left = answers;
    for (var r = 0; r < visible(i); r++) {
      left = filterEligible(left, guesses[r], marks[i][r]);
    }
    return left;
  }

  /// Adds a guess with the colours [shown] for each live board (by board).
  void addGuess(String word, Map<int, List<Mark>> shown) {
    guesses.add(word);
    for (var i = 0; i < boards; i++) {
      marks[i].add(List.of(shown[i] ?? blank()));
    }
  }

  void undo() {
    if (guesses.isEmpty) return;
    guesses.removeLast();
    for (final m in marks) {
      m.removeLast();
    }
  }

  void cycle(int board, int guess, int tile) {
    marks[board][guess][tile] = nextMark(marks[board][guess][tile]);
  }
}

/// Grey, then yellow, then green, then grey again: the order a tile is tapped.
Mark nextMark(Mark m) => switch (m) {
  Mark.absent => Mark.present,
  Mark.present => Mark.correct,
  Mark.correct => Mark.absent,
};

/// The solver for the quartet and the relay race: type each guess once, tap the
/// colours each live board showed, and it narrows every board and recommends
/// the next guess for them together (see [analyseMulti]). It follows the
/// settings: mode, language, letters, difficulty and the tries.
class MultiSolverPage extends StatefulWidget {
  const MultiSolverPage({super.key, required this.bank});
  final WordBank bank;

  @override
  State<MultiSolverPage> createState() => _MultiSolverPageState();
}

class _MultiSolverPageState extends State<MultiSolverPage> {
  final _focus = FocusNode();
  late final int length = appState.length;
  late final GameMode mode = appState.mode;
  late final int tries = triesFor(mode, appState.tries);
  late final List<String> _answers = widget.bank.answers(
    length,
    poolWords(appState.pool, widget.bank.language.counts[length]),
  );
  late final Set<String> _letters = widget.bank.letters(length);
  late final state = MultiSolverState(
    mode: mode,
    answers: _answers,
    length: length,
    tries: tries,
  );

  late final input = GuessInput(length);
  late final inputMarks = List.generate(
    mode.boards,
    (_) => List.filled(length, Mark.absent),
  );
  String message = '';

  // the advice for the live boards
  MultiPick? pick;
  FinalPick? finalPick;
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
    final live = state.live;
    final lists = [for (final i in live) state.eligibleOf(i)];
    setState(() {
      pick = null;
      finalPick = null;
      busy = lists.isNotEmpty && lists.every((l) => l.isNotEmpty);
    });
    if (!busy) return;
    if (state.triesLeft <= 1) {
      // nothing is left to learn: only a word that fits a board can win one
      final picks = finalPicks(lists, k: 1);
      setState(() {
        finalPick = picks.isEmpty ? null : picks.first;
        busy = false;
      });
      return;
    }
    final picks = await recommendMulti(
      lists,
      multiCandidates(lists, widget.bank.guessable(length)),
      k: 1,
    );
    if (!mounted || run != _run) return;
    setState(() {
      pick = picks.isEmpty ? null : picks.first;
      busy = false;
    });
  }

  void _type(String ch) {
    setState(() {
      final at = input.type(ch, _letters);
      if (at < 0) return;
      for (final m in inputMarks) {
        m[at] = Mark.absent; // a new letter starts unmarked
      }
      message = '';
    });
  }

  void _back() {
    setState(() {
      final at = input.back();
      if (at < 0) return;
      for (final m in inputMarks) {
        m[at] = Mark.absent;
      }
      message = '';
    });
  }

  void _move(int by) => setState(() => input.move(by));

  void _resetInput() {
    input.clear();
    for (final m in inputMarks) {
      m.fillRange(0, length, Mark.absent);
    }
  }

  void _add() {
    if (state.live.isEmpty) {
      setState(
        () => message = state.done ? 'every board is solved' : 'out of tries',
      );
      return;
    }
    if (!input.complete) {
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    state.addGuess(input.word, {
      for (final i in state.live) i: List.of(inputMarks[i]),
    });
    _resetInput();
    message = '';
    _solve();
  }

  void _undo() {
    if (state.guesses.isEmpty) return;
    state.undo();
    _solve();
  }

  void _use(String word) => setState(() {
    input.setWord(word);
    for (final m in inputMarks) {
      m.fillRange(0, length, Mark.absent);
    }
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
                  'solver · ${mode.label} · $lang · $length · $tries tries',
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
                        Caption(
                          mode == GameMode.relay
                              ? 'type each guess once, then tap the tiles of '
                                    'the board that is on to match the colours '
                                    'the game showed. when a board is solved '
                                    'the next opens: tap in the colours it '
                                    'showed for the guesses so far'
                              : 'type each guess once, then tap the tiles of '
                                    'every unsolved board to match the colours '
                                    'the game showed',
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            const gap = 4.0;
                            final size = min(
                              32.0,
                              (box.maxWidth - gap * (length - 1)) / length,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < state.boards; i++)
                                  _board(c, i, size, gap),
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
                                onPressed: state.guesses.isEmpty ? null : _undo,
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

  Widget _tiles(
    List<String> chars,
    List<Mark> marks,
    double size,
    double gap, {
    void Function(int)? tap,
    int? cursor,
  }) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: Row(
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          MarkTile(
            chars[i],
            mark: chars[i].isEmpty || chars[i] == GuessInput.blank
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

  Widget _board(ColorScheme c, int i, double size, double gap) {
    final solved = state.isSolved(i);
    final open = state.isOpen(i);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final live = state.isLive(i);
    final firstLive = state.live.isNotEmpty && state.live.first == i;
    return Padding(
      key: ValueKey('board-$i'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'board ${i + 1}'
            '${solved
                ? ' · solved: ${state.guesses[state.solvedAt(i)!]}'
                : open
                ? ''
                : ' · waiting'}',
            style: dim,
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < state.visible(i); r++)
            _tiles(
              state.guesses[r].split(''),
              state.marks[i][r],
              size,
              gap,
              // every row can be corrected, and a board a relay race has just
              // opened is filled in this way
              tap: (t) {
                setState(() => state.cycle(i, r, t));
                _solve();
              },
            ),
          if (live)
            _tiles(
              input.slots,
              inputMarks[i],
              size,
              gap,
              tap: (t) =>
                  setState(() => inputMarks[i][t] = nextMark(inputMarks[i][t])),
              cursor: firstLive ? input.cursor : null,
            ),
        ],
      ),
    );
  }

  Widget _result(ColorScheme c) {
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final left = state.triesLeft;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < state.boards; i++)
          if (state.isOpen(i) && !state.isSolved(i))
            Caption(
              '${state.eligibleOf(i).length} '
              '${state.eligibleOf(i).length == 1 ? 'word' : 'words'} on my list '
              'fit board ${i + 1}',
            ),
        const SizedBox(height: 4),
        Caption(
          'answers from the ${_answers.length} most common words · '
          '${left > 0 ? '$left ${left == 1 ? 'try' : 'tries'} left' : 'out of tries'}',
        ),
      ],
    );
    if (state.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 8),
          const Text(
            'every board is solved',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    final empty = [
      for (final i in state.live)
        if (state.eligibleOf(i).isEmpty) i + 1,
    ];
    if (empty.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 8),
          Text(
            'no word matches board ${empty.join(' and ')}. check the colours '
            'of its guesses above, or the game may use a word this list lacks.',
            style: TextStyle(color: c.error, fontSize: 13),
          ),
        ],
      );
    }
    final word = pick?.word ?? finalPick?.word;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        const SizedBox(height: 10),
        if (word == null)
          Caption(busy ? 'working out the best guess…' : 'nothing to recommend')
        else ...[
          Caption(
            finalPick != null
                ? 'last try: the word that fits the most boards'
                : 'recommended guess',
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _use(word),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.primary,
                ),
              ),
            ),
          ),
          Text(
            finalPick != null
                ? 'expect about ${finalPick!.expectedSolved.toStringAsFixed(2)} '
                      'of the ${state.live.length} boards solved  (tap to use)'
                : 'skill ${pick!.skill.toStringAsFixed(1)} across the boards'
                      '${pick!.possibleOn > 0 ? ' · could be the answer on ${pick!.possibleOn}' : ''}'
                      '  (tap to use)',
            style: dim,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'my list holds the ${_answers.length} most common words of this '
          'length. a game can use a word that is not on it.',
          style: dim,
        ),
      ],
    );
  }
}
