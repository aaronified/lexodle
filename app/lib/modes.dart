import 'dart:math';

import 'logic.dart';

/// How a game is played. Classic is one word; the others have four boards that
/// share every guess (and one pool of tries).
enum GameMode {
  classic('classic', 'one word', 1, 0),
  quartet('quartet', 'four words at once', 4, 3),
  relay('relay race', 'four words, one after the other', 4, 4);

  const GameMode(this.label, this.sub, this.boards, this.extraTries);
  final String label;
  final String sub;

  /// How many words are hidden.
  final int boards;

  /// Tries added to the difficulty's tries, since one guess serves every board.
  final int extraTries;

  bool get multi => boards > 1;
}

/// The largest chance of target words sharing a letter the slider offers.
const maxShare = 30;

int triesFor(GameMode mode, int base) => base + mode.extraTries;

/// Whether two words have a letter in common.
bool sharesLetter(String a, String b) => a.split('').any(b.contains);

/// Picks [count] different answers from [words] (weighted by [weights]).
///
/// [sharePct] is the chance, 0 to [maxShare], that a word is allowed to share
/// a letter with an answer already picked: a candidate that does is kept only
/// with that chance, and otherwise another is drawn. At 0 the words share no
/// letter whenever the language allows it. A pick can paint itself into a
/// corner (the words so far leave no disjoint candidate), so the whole choice
/// is started again, up to [restarts] times, keeping the one that was forced
/// to share least; when none can avoid it (four 8-letter words cannot avoid
/// repeating a letter in a 26-letter alphabet) that is the result.
List<String> chooseTargets(
  List<String> words,
  List<int> weights,
  int count,
  int sharePct,
  Random rng, {
  int attempts = 200,
  int restarts = 30,
}) {
  final p = sharePct.clamp(0, maxShare) / 100;
  List<String>? bestSet;
  var bestForced = 1 << 30;
  for (var r = 0; r < restarts && bestForced > 0; r++) {
    final chosen = <String>[];
    var forced = 0;
    while (chosen.length < count && chosen.length < words.length) {
      String? best;
      var bestShared = 1 << 30;
      String? pick;
      for (var i = 0; i < attempts && pick == null; i++) {
        final w = chooseWord(words, weights, rng);
        if (chosen.contains(w)) continue;
        final shared = chosen.where((o) => sharesLetter(o, w)).length;
        if (shared == 0 || rng.nextDouble() < p) {
          pick = w;
        } else if (shared < bestShared) {
          best = w;
          bestShared = shared;
        }
      }
      if (pick == null) {
        pick = best ?? words.firstWhere((w) => !chosen.contains(w));
        forced += bestShared == 1 << 30 ? 0 : bestShared;
      }
      chosen.add(pick);
    }
    if (forced < bestForced) {
      bestForced = forced;
      bestSet = chosen;
    }
  }
  return bestSet!;
}

/// One hidden word and what the guesses made so far say about it.
class Board {
  Board(this.answer);
  final String answer;
  final marks = <List<Mark>>[];

  /// The guess number that solved it, or null.
  int? solvedAt;

  bool get solved => solvedAt != null;

  /// Applies [guess] to the board; returns whether it solved it.
  bool apply(String guess) {
    marks.add(evaluate(answer, guess));
    if (guess == answer) solvedAt = marks.length - 1;
    return solved;
  }
}

/// The state of a quartet or relay race game; pure, so it is tested without UI.
class MultiGame {
  MultiGame(this.mode, List<String> answers, this.tries)
    : boards = [for (final a in answers) Board(a)];

  final GameMode mode;
  final int tries;
  final List<Board> boards;
  final guesses = <String>[];
  int _active = 0;

  /// The board a relay race is on; null in a quartet, where all are live.
  int? get active => mode == GameMode.relay ? _active : null;

  bool get won => boards.every((b) => b.solved);
  bool get over => won || guesses.length >= tries;
  int get solvedCount => boards.where((b) => b.solved).length;

  /// What the guesses so far say about each letter on each board, for the
  /// keyboard: per letter, one entry per board, the best mark that board has
  /// shown for it (green over yellow over grey), or null if the board has not
  /// seen the letter yet.
  Map<String, List<Mark?>> letterMarks() {
    final out = <String, List<Mark?>>{};
    for (var b = 0; b < boards.length; b++) {
      final marks = boards[b].marks;
      for (var r = 0; r < marks.length; r++) {
        for (var i = 0; i < marks[r].length; i++) {
          final per = out[guesses[r][i]] ??= List<Mark?>.filled(
            boards.length,
            null,
          );
          final old = per[b];
          if (old == null || marks[r][i].index < old.index) {
            per[b] = marks[r][i];
          }
        }
      }
    }
    return out;
  }

  /// Whether board [i] takes the next guess.
  bool isLive(int i) =>
      !over && !boards[i].solved && (mode == GameMode.quartet || i == _active);

  /// Whether board [i] is still waiting for its turn (relay race only).
  bool isLocked(int i) =>
      mode == GameMode.relay && !boards[i].solved && i != _active;

  /// Plays [guess]. In a quartet it goes to every unsolved board. In a relay race it
  /// goes to the active board; when that is solved the next one opens with
  /// every earlier guess already applied, which may solve it at once.
  void guess(String guess) {
    if (over) return;
    guesses.add(guess);
    if (mode == GameMode.quartet) {
      for (final b in boards) {
        if (!b.solved) b.apply(guess);
      }
      return;
    }
    boards[_active].apply(guess);
    while (boards[_active].solved && _active < boards.length - 1) {
      _active++;
      for (final g in guesses) {
        if (boards[_active].apply(g)) break;
      }
    }
  }
}
