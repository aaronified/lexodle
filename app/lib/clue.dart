import 'dart:math';

import 'logic.dart';
import 'modes.dart';
import 'words.dart';

/// The questions in a round of read the clue.
const clueRoundLength = 10;

/// A position to read: the guesses made with their clues, and four words of
/// which exactly one still fits every clue.
class ClueQuestion {
  const ClueQuestion({
    required this.guesses,
    required this.marks,
    required this.options,
    required this.fit,
  });
  final List<String> guesses;
  final List<List<Mark>> marks;

  /// The four words, in the order shown.
  final List<String> options;

  /// The index in [options] of the word that fits.
  final int fit;

  /// The colours [option] would show for the guess [g], to explain a wrong pick.
  List<Mark> would(String option, int g) => evaluate(option, guesses[g]);

  /// The first guess whose clue [option] would not give, or null when it fits.
  int? broken(String option) {
    for (var g = 0; g < guesses.length; g++) {
      final m = would(option, g);
      for (var i = 0; i < m.length; i++) {
        if (m[i] != marks[g][i]) return g;
      }
    }
    return null;
  }
}

/// Builds a position to read: a word is drawn as the answer, one or two guesses
/// are played against it, one word that still fits is offered with three that
/// do not (the ones that share the most letters with the guesses, so each looks
/// right until a clue is read). Null when none was found in [attempts].
ClueQuestion? buildClueQuestion({
  required WordBank bank,
  required int length,
  required Draw draw,
  required Random rng,
  int attempts = 50,
}) {
  final pool = bank.answers(length);
  final guessable = bank.guessable(length);
  if (pool.isEmpty || guessable.length < 8) return null;
  final drawn = bank.drawWeights(length, draw);
  for (var attempt = 0; attempt < attempts; attempt++) {
    final answer = chooseWord(pool, drawn, rng);
    var eligible = List.of(guessable);
    final guesses = <String>[];
    final marks = <List<Mark>>[];
    final depth = 1 + rng.nextInt(2);
    for (var i = 0; i < depth; i++) {
      final from = i == 0 ? guessable : eligible;
      final g = from[rng.nextInt(min(from.length, i == 0 ? 300 : 100))];
      if (g == answer) break;
      final m = evaluate(answer, g);
      eligible = filterEligible(eligible, g, m);
      guesses.add(g);
      marks.add(m);
    }
    if (guesses.isEmpty || eligible.length < 2) continue;
    final fit = eligible[rng.nextInt(eligible.length)];
    final fitSet = eligible.toSet();
    int overlap(String w) {
      var n = 0;
      for (final g in guesses) {
        for (final ch in g.split('').toSet()) {
          if (w.contains(ch)) n++;
        }
      }
      return n;
    }

    final others = <String>{};
    for (var t = 0; t < 400 && others.length < 40; t++) {
      final w = guessable[rng.nextInt(guessable.length)];
      if (!fitSet.contains(w) && !guesses.contains(w)) others.add(w);
    }
    if (others.length < 3) continue;
    final wrong = others.toList()
      ..sort((a, b) => overlap(b).compareTo(overlap(a)));
    final options = [fit, ...wrong.take(3)]..shuffle(rng);
    return ClueQuestion(
      guesses: guesses,
      marks: marks,
      options: options,
      fit: options.indexOf(fit),
    );
  }
  return null;
}
