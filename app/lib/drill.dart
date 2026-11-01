import 'dart:math';

import 'analysis_worker.dart';
import 'learn_text.dart';
import 'logic.dart';
import 'modes.dart';
import 'words.dart';

/// One word offered in a drill, with how good a guess it is here.
class DrillOption {
  const DrillOption(this.word, this.skill, this.gain);
  final String word;

  /// Skill, 0 to 100: its expected gain against the best guess's.
  final double skill;

  /// The bits it is expected to gain.
  final double gain;
}

/// A position to choose a guess in: the guesses made so far with the colours
/// they got, the words that still fit, and four words to choose between, one
/// of them the best guess there is.
class DrillQuestion {
  const DrillQuestion({
    required this.answer,
    required this.guesses,
    required this.marks,
    required this.eligible,
    required this.options,
    required this.landscape,
    required this.weights,
  });

  /// The word the clues came from. It is not shown: it only fixes the colours.
  final String answer;
  final List<String> guesses;
  final List<List<Mark>> marks;
  final List<String> eligible;

  /// The four words, in the order shown.
  final List<DrillOption> options;
  final Landscape landscape;
  final Map<String, int>? weights;

  /// The best skill among the options (100: the best guess is always offered).
  double get topSkill => options.fold(0.0, (a, o) => max(a, o.skill));

  /// Whether choosing [o] was right: nothing offered was better.
  bool isRight(DrillOption o) => o.skill >= topSkill - 1e-9;

  /// What the explanation of choosing [o] says (see [learnWhy]).
  GuessReport report(DrillOption o) => reportGuess(
    before: eligible,
    guess: o.word,
    after: filterEligible(eligible, o.word, evaluate(answer, o.word)),
    landscape: landscape,
    weights: weights,
  );
}

/// What a finished question comes to.
class DrillAnswer {
  const DrillAnswer(this.word, this.skill, this.right);
  final String word;
  final double skill;
  final bool right;
}

/// Picks the four words to offer from [candidates], given the best guess [best]
/// of the position: the best itself, and three worse ones whose skills are
/// spread out, so that the choice is between clearly different guesses. Pure:
/// [rng] only decides which of equally good words, and the order. Fewer than
/// four are returned when the position does not have that many different words.
List<DrillOption> pickOptions({
  required List<String> eligible,
  required Iterable<String> candidates,
  required String best,
  required double bestGain,
  required Map<String, int>? weights,
  required Random rng,
  int count = 4,
  int sample = 80,
}) {
  final context = SplitContext(eligible, weights);
  DrillOption score(String w) {
    final h = context.stats(w).h;
    return DrillOption(w, skillOf(h, bestGain), h);
  }

  final pool = {...candidates}..remove(best);
  final picked = pool.toList()..shuffle(rng);
  final scored = [for (final w in picked.take(sample)) score(w)]
    ..sort((a, b) => a.skill.compareTo(b.skill));
  final chosen = <DrillOption>[];
  // the worse ones are spread across the range of skills seen: the targets are
  // evenly spaced from the worst to the best below 100
  final worse = scored.where((o) => o.skill < 99.5).toList();
  if (worse.isNotEmpty) {
    final need = count - 1;
    for (var i = 0; i < need; i++) {
      final at = need == 1
          ? 0
          : ((worse.length - 1) * i / (need - 1)).round().clamp(
              0,
              worse.length - 1,
            );
      // the nearest one not already taken, and not a near copy of one
      for (var step = 0; step < worse.length; step++) {
        final o = worse[(at + step) % worse.length];
        if (chosen.any((c) => c.word == o.word)) continue;
        if (chosen.any((c) => (c.skill - o.skill).abs() < 2) &&
            step < worse.length - 1) {
          continue;
        }
        chosen.add(o);
        break;
      }
    }
  }
  final options = [score(best), ...chosen]..shuffle(rng);
  return options;
}

/// Builds a position to choose in: a word of the language is drawn as the
/// answer, one or two plausible guesses are played against it, and the words
/// that still fit are analysed for the best guess. Positions with too few
/// words to be a choice, or too many to analyse quickly, are drawn again.
/// Null when none was found in [attempts] tries (a tiny word list).
Future<DrillQuestion?> buildDrillQuestion({
  required WordBank bank,
  required int length,
  required Draw draw,
  required Random rng,
  int attempts = 30,
  int minWords = 8,
  int maxWords = 1500,
}) async {
  final pool = bank.answers(length);
  final guessable = bank.guessable(length);
  if (pool.isEmpty || guessable.isEmpty) return null;
  final weights = bank.law(length, draw);
  final drawn = bank.drawWeights(length, draw);
  for (var attempt = 0; attempt < attempts; attempt++) {
    final answer = chooseWord(pool, drawn, rng);
    var eligible = List.of(guessable);
    final guesses = <String>[];
    final marks = <List<Mark>>[];
    final depth = 1 + rng.nextInt(2);
    for (var i = 0; i < depth; i++) {
      // a plausible guess: a common word, then one that still fits
      final from = i == 0 ? guessable : eligible;
      final g = from[rng.nextInt(min(from.length, i == 0 ? 300 : 100))];
      if (g == answer) break;
      final m = evaluate(answer, g);
      eligible = filterEligible(eligible, g, m);
      guesses.add(g);
      marks.add(m);
    }
    if (guesses.isEmpty ||
        eligible.length < minWords ||
        eligible.length > maxWords) {
      continue;
    }
    final land = await analyseOffThread(
      eligible,
      guessable,
      k: 3,
      weights: weights,
    );
    if (land.top.isEmpty) continue;
    final options = pickOptions(
      eligible: eligible,
      candidates: recommendationCandidates(eligible, guessable),
      best: land.top.first.word,
      bestGain: land.bestGain,
      weights: weights,
      rng: rng,
    );
    if (options.length < 4) continue;
    return DrillQuestion(
      answer: answer,
      guesses: guesses,
      marks: marks,
      eligible: eligible,
      options: options,
      landscape: land,
      weights: weights,
    );
  }
  return null;
}

/// How many questions a round of a drill has.
const drillRoundLength = 10;

/// A finished round: the language and length it was played in, and each
/// answer in order.
class DrillRound {
  const DrillRound(this.language, this.length, this.answers);
  final String language;
  final int length;
  final List<DrillAnswer> answers;

  int get right => answers.where((a) => a.right).length;

  /// The mean skill of the words chosen, 0 to 100.
  double get averageSkill => answers.isEmpty
      ? 0
      : answers.fold(0.0, (s, a) => s + a.skill) / answers.length;

  bool get complete => answers.length >= drillRoundLength;
}
