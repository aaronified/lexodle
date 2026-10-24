import 'dart:math';

import 'logic.dart';
import 'multi_analysis.dart';

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
///
/// Given the [words] the game accepts, it also keeps the analysis the review
/// needs, step by step as the game is played: per board, the words still
/// possible, and per guess its skill, luck and what it did to each board (see
/// multi_analysis.dart). Without them it is only the rules of the game.
class MultiGame {
  MultiGame(
    this.mode,
    List<String> answers,
    this.tries, {
    List<String>? words,
    this.provisional = false,
  }) : boards = [for (final a in answers) Board(a)],
       _words = words,
       eligible = [
         // the very same list for every board at the start, so the analysis of
         // the first guess is worked out once for all of them
         for (final _ in answers) words ?? <String>[],
       ] {
    if (words != null) {
      // a quartet opens every board at once, a relay race the first
      for (var i = 0; i < (mode == GameMode.quartet ? boards.length : 1); i++) {
        heads.add(HeadStart(i, 0, words.length, words.length));
      }
    }
  }

  final GameMode mode;
  final int tries;
  final List<Board> boards;
  final guesses = <String>[];
  final List<String>? _words;

  /// Whether each guess's skill is provisional until the analysis has found the
  /// best real guess (see [GuessMetrics.ready]).
  final bool provisional;
  int _active = 0;

  /// The words still possible on each board, given every guess it has had
  /// (all the words the game accepts, not only the common ones the answer is
  /// drawn from: a player cannot know that list). Empty lists when the game
  /// was made without [words].
  final List<List<String>> eligible;

  /// Relay race: boards that were solved by the guesses made before they
  /// opened, the moment they opened (a free ride).
  int get freeRides => heads
      .where(
        (h) =>
            h.opensAfter > 0 &&
            boards[h.board].solved &&
            boards[h.board].solvedAt! < h.opensAfter,
      )
      .length;

  /// The analysis of each guess so far, and when each board opened.
  final steps = <MultiStep>[];
  final heads = <HeadStart>[];

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

  /// What board [i] alone says about each letter (the best mark it has shown),
  /// for a keyboard coloured like a single game's. In a relay race that is the
  /// active board's: its colours are the ones that matter, and the earlier
  /// guesses were already applied to it when it opened.
  Map<String, Mark> marksOf(int i) {
    final out = <String, Mark>{};
    final marks = boards[i].marks;
    for (var r = 0; r < marks.length; r++) {
      for (var k = 0; k < marks[r].length; k++) {
        final old = out[guesses[r][k]];
        if (old == null || marks[r][k].index < old.index) {
          out[guesses[r][k]] = marks[r][k];
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

  /// Plays [guess]. In a quartet it goes to every unsolved board. In a relay
  /// race it goes to the active board; when that is solved the next one opens
  /// with every earlier guess already applied, which may solve it at once.
  void guess(String guess) {
    if (over) return;
    guesses.add(guess);
    final words = _words;
    final finalTry = guesses.length >= tries;
    final live = [
      for (var i = 0; i < boards.length; i++)
        if (!boards[i].solved && (mode == GameMode.quartet || i == _active)) i,
    ];
    final before = [for (final i in live) eligible[i]];
    for (final i in live) {
      boards[i].apply(guess);
      if (words != null) {
        eligible[i] = filterEligible(eligible[i], guess, boards[i].marks.last);
      }
    }
    final stepBoards = [
      if (words != null)
        for (var k = 0; k < live.length; k++)
          BoardStep(
            live[k],
            scoreGuess(
              before[k],
              guess,
              eligible[live[k]].length,
              finalTry: finalTry,
              triesLeft: tries - (guesses.length - 1),
              solved: boards[live[k]].solved,
              provisional: provisional,
            ),
            boards[live[k]].solved,
          ),
    ];

    final opened = <HeadStart>[];
    if (mode == GameMode.relay) {
      while (boards[_active].solved && _active < boards.length - 1) {
        _active++;
        for (final g in guesses) {
          final done = boards[_active].apply(g);
          if (words != null) {
            eligible[_active] = filterEligible(
              eligible[_active],
              g,
              boards[_active].marks.last,
            );
          }
          if (done) break;
        }
        if (words != null) {
          opened.add(
            HeadStart(
              _active,
              guesses.length,
              eligible[_active].length,
              words.length,
            ),
          );
        }
      }
    }
    if (words != null) {
      heads.addAll(opened);
      steps.add(
        MultiStep(
          guess,
          stepBoards,
          before,
          finalTry: finalTry,
          opened: opened,
        ),
      );
    }
  }
}
