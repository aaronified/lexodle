import 'dart:math';

import 'analysis_worker.dart';
import 'closing.dart';
import 'drill_calc.dart';
import 'learn_log.dart';
import 'learn_styles.dart';
import 'learn_text.dart';
import 'logic.dart';
import 'modes.dart';
import 'words.dart';

export 'learn_log.dart' show drillRoundLength;

/// One word offered in a drill, with how good a guess it is here.
class DrillOption {
  const DrillOption(this.word, this.skill, this.gain, {this.win});
  final String word;

  /// In a closing question, the chance, 0 to 1, that this guess wins within the
  /// tries left; null otherwise.
  final double? win;

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
    this.triesLeft,
  });

  /// In a closing question, the tries left (this guess included): what is asked
  /// is the guess most likely to win in time. Null in choose the best.
  final int? triesLeft;
  bool get closing => triesLeft != null;

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

  /// [o] walked through the words that fit, group by group (see [walkGroups]),
  /// with the group the answer is in marked.
  GroupWalk walk(DrillOption o) =>
      walkGroups(eligible, o.word, weights, answer: answer);

  /// The bits the best guess is expected to gain, which skill is measured
  /// against.
  double get bestBits => landscape.bestGain;

  /// What choosing [o] comes to in a closing question: whether it can win now,
  /// how it splits the words that fit, and the chance it wins in time, then the
  /// same for the best and what the difference is.
  List<String> closingLines(DrillOption o) {
    final tries = triesLeft ?? 1;
    final best = options.firstWhere(isRight);
    String line(DrillOption x) {
      final walk = walkGroups(eligible, x.word, weights);
      final fits = eligible.contains(x.word);
      final others = walk.groups
          .where((g) => !(g.words.length == 1 && g.words.first == x.word))
          .toList();
      final biggest = others.isEmpty
          ? 0
          : others.map((g) => g.words.length).reduce(max);
      final win = ((x.win ?? 0) * 100).round();
      return '${x.word}: ${fits ? 'can be right now' : 'cannot be right now'}'
          '${others.isEmpty ? '' : ', then ${others.length} '
                    '${others.length == 1 ? 'group' : 'groups'} (the biggest '
                    '$biggest ${biggest == 1 ? 'word' : 'words'})'}'
          ' · wins within $tries ${tries == 1 ? 'try' : 'tries'} in $win%';
    }

    // which habit of the playstyle each counts as: a closer fits the clues, a
    // prober does not but is one of the best splits
    StyleProfile profile(DrillOption x) => profileGuess(
      before: eligible,
      guess: x.word,
      after: filterEligible(eligible, x.word, evaluate(answer, x.word)),
      landscape: landscape,
      weights: weights,
      earlier: guesses,
      earlierMarks: marks,
    );
    final styled = landscape.top.isNotEmpty;
    if (isRight(o)) {
      return [
        line(o),
        'nothing here wins in time more often',
        if (styled) styleLine(profile(o)),
      ];
    }
    final bestStyle = styled ? profile(best).behaviour : null;
    return [
      line(o),
      line(best),
      '${best.word} splits the ${eligible.length} words so that the next '
          'guess is more often right',
      if (styled) styleLine(profile(o)),
      if (styled)
        'the best, ${best.word}, counts as '
            '${bestStyle == null ? 'no habit' : 'a ${bestStyle.label}'}',
    ];
  }

  /// What the explanation of choosing [o] says (see [learnWhy]).
  GuessReport report(DrillOption o) => reportGuess(
    before: eligible,
    guess: o.word,
    after: filterEligible(eligible, o.word, evaluate(answer, o.word)),
    landscape: landscape,
    weights: weights,
    earlier: guesses,
    earlierMarks: marks,
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
  // (a word that splits nothing is no choice: it tells nothing at all)
  final worse = scored.where((o) => o.skill < 99.5 && o.gain > 1e-9).toList();
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
      // a word already played here splits nothing, and is no choice
      candidates: recommendationCandidates(
        eligible,
        guessable,
      ).where((w) => !guesses.contains(w)),
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

/// Picks four words for a closing question from the chance each [wins] of
/// winning in time: the best, and three clearly worse ones spread across what
/// the others win. Null when the position is no choice (fewer than three guesses
/// are clearly worse). Pure: [rng] only orders the options.
List<DrillOption>? pickClosingOptions(Map<String, double> wins, Random rng) {
  if (wins.isEmpty) return null;
  final best = wins.values.reduce(max);
  if (best <= 0) return null;
  DrillOption option(String w) {
    final win = wins[w]!;
    return DrillOption(w, win / best * 100, 0, win: win);
  }

  final top = wins.keys.where((w) => wins[w]! >= best - 1e-9).toList()
    ..shuffle(rng);
  final worse = [
    for (final w in wins.keys)
      if (wins[w]! < best - 0.02) w,
  ]..sort((a, b) => wins[a]!.compareTo(wins[b]!));
  if (worse.length < 3) return null;
  final chosen = <String>[];
  for (var i = 0; i < 3; i++) {
    final at = ((worse.length - 1) * i / 2).round();
    for (var step = 0; step < worse.length; step++) {
      final w = worse[(at + step) % worse.length];
      if (chosen.contains(w)) continue;
      // not a near copy of one already taken, while there is a choice
      if (chosen.any((c) => (wins[c]! - wins[w]!).abs() < 0.01) &&
          step < worse.length - 1) {
        continue;
      }
      chosen.add(w);
      break;
    }
  }
  return [option(top.first), for (final w in chosen) option(w)]..shuffle(rng);
}

/// Builds a closing position: a few words fit the clues (three to ten) and two
/// or three tries are left, so the choice is between a word that may be right
/// now and a word that splits the rest so the next guess is. Every guess is
/// scored by the exact chance it wins in time (see [winChance]). Null when none
/// was found in [attempts] tries.
Future<DrillQuestion?> buildClosingQuestion({
  required WordBank bank,
  required int length,
  required Draw draw,
  required Random rng,
  int attempts = 80,
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
    var ok = true;
    for (var step = 0; step < 6 && eligible.length > 10; step++) {
      final from = step == 0 ? guessable : eligible;
      final g = from[rng.nextInt(min(from.length, step == 0 ? 300 : 60))];
      if (g == answer) {
        ok = false;
        break;
      }
      final m = evaluate(answer, g);
      eligible = filterEligible(eligible, g, m);
      guesses.add(g);
      marks.add(m);
    }
    if (!ok || eligible.length < 3 || eligible.length > 10) continue;
    final tries = 2 + rng.nextInt(2);
    final probes = closingProbeWords(
      eligible,
      guessable.take(800).where((w) => !guesses.contains(w)),
      weights,
    );
    // the words that fit and the probes, and a few words picked at random: a
    // word that has nothing to do with the position is a fair wrong answer
    final candidates = {
      ...eligible,
      ...probes,
      for (var i = 0; i < 6; i++) guessable[rng.nextInt(guessable.length)],
    }..removeAll(guesses);
    final wins = {
      for (final c in candidates)
        c: winChance(eligible, c, tries, probes, weights),
    };
    final options = pickClosingOptions(wins, rng);
    if (options == null) continue;
    // the analysis of the position, for the habit each guess counts as
    final land = await analyseOffThread(
      eligible,
      guessable,
      k: 3,
      weights: weights,
    );
    return DrillQuestion(
      answer: answer,
      guesses: guesses,
      marks: marks,
      eligible: eligible,
      options: options,
      landscape: land,
      weights: weights,
      triesLeft: tries,
    );
  }
  return null;
}

/// A finished round: the drill it was of, the language and length it was
/// played in, and each answer in order.
class DrillRound {
  const DrillRound(
    this.language,
    this.length,
    this.answers, {
    this.kind = LearnKind.choose,
  });
  final String language;
  final int length;
  final List<DrillAnswer> answers;
  final LearnKind kind;

  int get right => answers.where((a) => a.right).length;

  /// The mean skill of the words chosen, 0 to 100.
  double get averageSkill => answers.isEmpty
      ? 0
      : answers.fold(0.0, (s, a) => s + a.skill) / answers.length;

  bool get complete => answers.length >= drillRoundLength;

  /// The round as the learn log keeps it.
  LearnEvent toEvent(String date) => LearnEvent(
    kind: kind,
    language: language,
    length: length,
    date: date,
    questions: answers.length,
    right: right,
    avgSkill: averageSkill,
  );
}
