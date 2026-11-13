import '../blind_pencil.dart';
import '../equations.dart' show equationProblem;
import '../logic.dart';
import '../modes.dart';
import 'first_game_engine.dart';

/// One submitted guess of a lesson: the word and what each tile showed.
class LessonRow {
  const LessonRow(this.word, this.marks);
  final String word;
  final List<Mark> marks;

  int get green => marks.where((m) => m == Mark.correct).length;
  int get yellow => marks.where((m) => m == Mark.present).length;
}

/// The pure logic of a mode lesson: a small real game of one mode with no
/// tries limit, whose word is chosen as the player plays (see
/// [FirstGameEngine.pick], the way the mastermind mode chooses). No widgets,
/// no storage. Not for classic, which is the first game.
class LessonGame {
  LessonGame(this.mode, this.engine)
    : length = mode.isEquations ? 8 : 5,
      boards = [for (var i = 0; i < (mode.multi ? 4 : 1); i++) <LessonRow>[]],
      solved = List.filled(mode.multi ? 4 : 1, false),
      candidates = mode == GameMode.mastermind
          ? List.of(engine.pool)
          : <String>[],
      hearts = dailyHearts;

  final GameMode mode;
  final FirstGameEngine engine;

  /// The tiles of a word: 8 for an equation, else 5.
  final int length;

  /// The rows of each board: four for the quartet and the relay, else one.
  final List<List<LessonRow>> boards;
  final List<bool> solved;

  /// The words chosen so far: all four after the first guess of a quartet, one
  /// more for each word of a relay, one for the others.
  final List<String> targets = [];

  /// The word of the relay now on.
  int active = 0;

  /// The valid guesses made.
  int made = 0;
  int hearts;
  final int heartsTotal = dailyHearts;
  bool done = false;

  /// What a mastermind game still allows.
  List<String> candidates;

  late final pencil = BlindPencil(length);

  /// The greens found so far, for lockdown's automatic locks: slot to letter.
  final Map<int, String> greens = {};

  bool isValid(String w) => engine.isValid(w);

  /// Why [w] is not a guess, for an equation: the rule it breaks.
  String? whyNot(String w) => mode.isEquations
      ? equationProblem(w) ?? 'not one of the equations.'
      : null;

  /// Whether board [i] takes the row being typed.
  bool isLive(int i) =>
      !done && !solved[i] && (mode != GameMode.relay || i == active);

  /// A guess that is not a word: lockdown takes a heart (never the last one).
  void invalid() {
    if (mode == GameMode.lockdown && hearts > 1) hearts--;
  }

  static bool _noGreenTwoYellow(String p) =>
      count(p, 'g') == 0 && count(p, 'y') >= 2;
  static bool _greenAndYellow(String p) =>
      count(p, 'g') >= 1 && count(p, 'y') >= 1;

  LessonRow _row(String guess, String target) =>
      LessonRow(guess, evaluate(target, guess));

  /// Plays the valid guess [g].
  void guess(String g) {
    made++;
    switch (mode) {
      case GameMode.quartet:
        if (targets.isEmpty) {
          for (final shape in <bool Function(String)>[
            Shape.classic,
            _noGreenTwoYellow,
            _greenAndYellow,
            Shape.any,
          ]) {
            targets.add(engine.pick(g, shape, targets));
          }
        }
        for (var b = 0; b < 4; b++) {
          if (solved[b]) continue;
          boards[b].add(_row(g, targets[b]));
          if (g == targets[b]) solved[b] = true;
        }
        done = solved.every((s) => s);
      case GameMode.relay:
        if (targets.length <= active) {
          targets.add(engine.pick(g, Shape.classic, targets));
        }
        boards[active].add(_row(g, targets[active]));
        if (g == targets[active]) {
          solved[active] = true;
          if (active >= 3) {
            done = true;
          } else {
            active++;
          }
        }
      case GameMode.mastermind:
        final step = engine.filterCandidates(candidates, g);
        candidates = List.of(step.candidates);
        final marks = [
          for (final c in step.pattern.split(''))
            switch (c) {
              'g' => Mark.correct,
              'y' => Mark.present,
              _ => Mark.absent,
            },
        ];
        boards[0].add(LessonRow(g, marks));
        if (step.pattern == 'g' * length) done = true;
      default:
        if (targets.isEmpty) {
          targets.add(
            engine.pick(g, switch (mode) {
              GameMode.lockdown => Shape.lock,
              GameMode.blind => Shape.classic,
              _ => Shape.any,
            }),
          );
        }
        final row = _row(g, targets[0]);
        boards[0].add(row);
        if (g == targets[0]) done = true;
        if (mode == GameMode.lockdown) {
          for (var i = 0; i < length; i++) {
            if (row.marks[i] == Mark.correct) greens[i] = g[i];
          }
        }
    }
  }

  /// The greens of board [b], as (slot, letter), for a double tap.
  List<(int, String)> greensOf(int b) => [
    for (final r in boards[b])
      for (var i = 0; i < length; i++)
        if (r.marks[i] == Mark.correct) (i, r.word[i]),
  ];

  /// The best mark of each letter on board [b], for the keys.
  Map<String, Mark> keyMarks(int b) {
    final out = <String, Mark>{};
    for (final r in boards[b]) {
      for (var i = 0; i < r.word.length; i++) {
        final old = out[r.word[i]];
        if (old == null || r.marks[i].index < old.index) {
          out[r.word[i]] = r.marks[i];
        }
      }
    }
    return out;
  }

  /// Per letter, what each board says about it, for the quartered keys.
  Map<String, List<Mark?>> quadMarks() {
    final out = <String, List<Mark?>>{};
    for (var b = 0; b < boards.length; b++) {
      keyMarks(b).forEach((ch, m) {
        (out[ch] ??= List<Mark?>.filled(boards.length, null))[b] = m;
      });
    }
    return out;
  }

  /// The submitted rows of a blind game as the pencil reads them.
  List<BlindRow> get blindRows => [
    for (final r in boards[0]) BlindRow(r.word, r.green, r.yellow),
  ];
}
