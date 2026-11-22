import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'guess_input.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'split_plot.dart';
import 'typing_keys.dart';
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

  /// The words an answer can be, every word of the length.
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
///
/// [excluded] holds answers the solver must not know (see SolverExclusions):
/// they are neither listed nor recommended. [mode] (quartet or relay) defaults
/// to the mode in view.
class MultiSolverPage extends StatefulWidget {
  const MultiSolverPage({
    super.key,
    required this.bank,
    this.excluded = const {},
    this.mode,
    this.length,
    this.tries,
  });
  final WordBank bank;
  final Set<String> excluded;
  final GameMode? mode;

  /// Overrides for this page only; the saved length and tries when null.
  final int? length;

  /// The tries as the mode counts them (see [triesFor]), not the base.
  final int? tries;

  @override
  State<MultiSolverPage> createState() => _MultiSolverPageState();
}

class _MultiSolverPageState extends State<MultiSolverPage> {
  final _focus = FocusNode();
  late final int length = widget.length ?? appState.length;
  late final GameMode mode = widget.mode ?? appState.mode;
  late final int tries = widget.tries ?? triesFor(mode, appState.tries);
  late final List<String> _answers = [
    for (final w in widget.bank.answers(length))
      if (!widget.excluded.contains(w)) w,
  ];
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
  // up to five next guesses, best first: the recommended, then the rest; each
  // with the number the page reports for it
  List<({String word, String note})> alts = const [];
  int altSel = 0;
  // the board whose split the plot shows
  int plotBoard = 0;
  // each (word, board, guesses) split of that board's words, kept while the
  // history stays
  final _splits = <String, (List<(int, int)>, double)>{};
  late final Set<String> _guessable = {
    for (final w in widget.bank.guessable(length)) w,
    ...widget.bank.answers(length),
  };
  bool busy = false;
  int _run = 0;

  /// The law the answers are drawn by, as weights; null for equal chances.
  Map<String, int>? get _law => widget.bank.law(length, appState.drawOf(mode));

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
      alts = const [];
      altSel = 0;
      _splits.clear();
      if (!live.contains(plotBoard)) plotBoard = live.isEmpty ? 0 : live.first;
      busy = lists.isNotEmpty && lists.every((l) => l.isNotEmpty);
    });
    if (!busy) return;
    try {
      if (state.triesLeft <= 1) {
        // nothing is left to learn: only a word that fits a board can win one
        final picks = finalPicks(lists, k: 5, weights: _law);
        setState(() {
          finalPick = picks.isEmpty ? null : picks.first;
          alts = [
            for (final p in picks)
              (
                word: p.word,
                note: '${p.expectedSolved.toStringAsFixed(1)} solved',
              ),
          ];
          busy = false;
        });
        return;
      }
      final picks = await recommendMulti(
        lists,
        multiCandidates(lists, [
          for (final w in widget.bank.guessable(length))
            if (!widget.excluded.contains(w)) w,
        ]),
        k: 5,
        weights: _law,
      );
      if (!mounted || run != _run) return;
      setState(() {
        pick = picks.isEmpty ? null : picks.first;
        alts = [
          for (final p in picks)
            (word: p.word, note: 'skill ${p.skill.toStringAsFixed(1)}'),
        ];
        busy = false;
      });
    } catch (e) {
      appLog.w('multi solver', 'solve failed ${e.runtimeType}');
      if (!mounted || run != _run) return;
      setState(() {
        pick = null;
        finalPick = null;
        alts = const [];
        busy = false;
      });
    }
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

  void _clearRow() => setState(() {
    input.clearTyped();
  });

  late final _keys = TypingKeys(
    submit: _add,
    back: _back,
    clearRow: _clearRow,
    move: _move,
    type: _type,
  );

  KeyEventResult _onKey(FocusNode _, KeyEvent e) => _keys.handle(e);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
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
                        if (state.guesses.isEmpty)
                          const Caption(
                            'type a guess, tap its tiles to match the game',
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
                            OutlinedButton(
                              onPressed: state.guesses.isEmpty ? null : _undo,
                              child: const Text('undo'),
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
                        const SizedBox(height: 14),
                        _result(c),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
                    onCursor: _move,
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

  (List<(int, int)>, double) _split(String word, int board) =>
      _splits.putIfAbsent('$word|$board|${state.guesses.length}', () {
        final eligible = state.eligibleOf(board);
        final groups = splitGroups(eligible, word);
        var sq = 0;
        for (final g in groups) {
          sq += g.$2 * g.$2;
        }
        return (groups, eligible.isEmpty ? 0.0 : sq / eligible.length);
      });

  Widget _result(ColorScheme c) {
    final left = state.triesLeft;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final fit = [
      for (final i in state.live) 'b${i + 1} ${state.eligibleOf(i).length}',
    ];
    final line = Caption(
      '${fit.isEmpty ? '' : 'fit: ${fit.join(' · ')} · '}'
      '${left > 0 ? '$left ${left == 1 ? 'try' : 'tries'} left' : 'out of tries'}',
    );
    if (state.done) {
      return const Text(
        'every board is solved',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );
    }
    final empty = [
      for (final i in state.live)
        if (state.eligibleOf(i).isEmpty) i + 1,
    ];
    if (empty.isNotEmpty) {
      return Text(
        'no word matches board ${empty.join(' and ')}. check its colours.',
        style: TextStyle(color: c.error, fontSize: 13),
      );
    }
    if (busy || alts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line,
          const SizedBox(height: 10),
          Caption(
            busy ? 'working out the best guesses…' : 'nothing to recommend',
          ),
        ],
      );
    }
    final live = state.live;
    final board = live.contains(plotBoard) ? plotBoard : live.first;
    final typed = input.complete ? input.word : null;
    final typedKnown = typed != null && _guessable.contains(typed);
    final Widget plot;
    if (typedKnown) {
      final (groups, avg) = _split(typed, board);
      plot = SplitPlot(
        key: ValueKey('plot-$board'),
        word: typed,
        groups: groups,
        average: avg,
        length: length,
        highlight: markCode(inputMarks[board]),
      );
    } else if (typed != null) {
      plot = Text(
        '$typed is not in the word list',
        style: TextStyle(fontSize: 12, color: dim),
      );
    } else {
      final word = alts[min(altSel, alts.length - 1)].word;
      final (groups, avg) = _split(word, board);
      plot = SplitPlot(
        key: ValueKey('plot-$board'),
        word: word,
        groups: groups,
        average: avg,
        length: length,
        onUse: () => _use(word),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        const SizedBox(height: 12),
        const Caption('alternatives'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < alts.length; i++)
              _chip(c, i, alts[i], selected: !typedKnown && i == altSel),
          ],
        ),
        if (live.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (final i in live) ...[
                _boardChip(c, i, selected: i == board),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        plot,
      ],
    );
  }

  BoxDecoration _chipBox(ColorScheme c, bool selected) => BoxDecoration(
    color: selected ? c.surfaceContainerHighest : null,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: selected ? c.onSurface : hairlineColor(c),
      width: selected ? 1 : hairlineWidth,
    ),
  );

  Widget _boardChip(ColorScheme c, int i, {required bool selected}) => InkWell(
    key: ValueKey('plot-board-$i'),
    borderRadius: BorderRadius.circular(4),
    onTap: () => setState(() => plotBoard = i),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: _chipBox(c, selected),
      child: Text(
        '${i + 1}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ),
  );

  Widget _chip(
    ColorScheme c,
    int i,
    ({String word, String note}) r, {
    required bool selected,
  }) => InkWell(
    key: ValueKey('alt-${r.word}'),
    borderRadius: BorderRadius.circular(4),
    onTap: () => setState(() => altSel = i),
    child: Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: _chipBox(c, selected),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.word,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            r.note,
            style: TextStyle(
              fontSize: 10,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
      ),
    ),
  );
}
