import 'dart:math';

import 'logic.dart';

/// The endgame: few words fit, and the tries left decide what to play. A guess
/// that fits the clues can win now; one that does not may split the rest better
/// and win a try later. This is the exact chance of winning in time, so the
/// choice can be graded.

/// How many probe words (words that need not fit) are tried at each step of
/// the search, besides the words that fit.
const closingProbes = 40;

double _weight(Map<String, int>? weights, String w) =>
    weights == null ? 1.0 : max(weights[w] ?? 1, 1).toDouble();

/// The most weight of [fit] that a player who plays the best word each time can
/// win in [tries] guesses, choosing from the words of [fit] and the [probes].
/// One try: the likeliest word. More: for a guess, its own weight if it fits,
/// plus what the best play wins in each group the colours leave, in one try
/// less.
double bestWinMass(
  List<String> fit,
  int tries,
  List<String> probes,
  Map<String, int>? weights,
) {
  if (fit.isEmpty || tries <= 0) return 0;
  if (fit.length == 1) return _weight(weights, fit.first);
  if (tries == 1) return fit.fold(0.0, (m, w) => max(m, _weight(weights, w)));
  var best = 0.0;
  for (final g in {...fit, ...probes}) {
    best = max(best, winMass(fit, g, tries, probes, weights));
  }
  return best;
}

/// The weight of [fit] won in [tries] guesses by playing [guess] first and then
/// the best word each time (see [bestWinMass]).
double winMass(
  List<String> fit,
  String guess,
  int tries,
  List<String> probes,
  Map<String, int>? weights,
) {
  if (fit.isEmpty || tries <= 0) return 0;
  var won = 0.0;
  final groups = <int, List<String>>{};
  for (final w in fit) {
    if (w == guess) {
      won += _weight(weights, w);
    } else {
      (groups[patternCode(w, guess)] ??= []).add(w);
    }
  }
  if (tries == 1) return won;
  for (final g in groups.values) {
    won += bestWinMass(g, tries - 1, probes, weights);
  }
  return won;
}

/// The chance, 0 to 1, that [guess] wins within [tries] guesses (itself
/// included) when the answer is one of [fit], weighted by [weights].
double winChance(
  List<String> fit,
  String guess,
  int tries,
  List<String> probes,
  Map<String, int>? weights,
) {
  final total = fit.fold(0.0, (m, w) => m + _weight(weights, w));
  if (total <= 0) return 0;
  return winMass(fit, guess, tries, probes, weights) / total;
}

/// The probe words worth trying for a position: the [candidates] that split the
/// words in [fit] best, [closingProbes] of them (words of [fit] are always
/// tried, so are left out). Cheap: one split of the words per candidate.
List<String> closingProbeWords(
  List<String> fit,
  Iterable<String> candidates,
  Map<String, int>? weights,
) {
  if (fit.length < 2) return const [];
  final context = SplitContext(fit, weights);
  final fitSet = fit.toSet();
  final scored = <(String, double)>[
    for (final c in candidates)
      if (!fitSet.contains(c)) (c, context.stats(c).h),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (w, _) in scored.take(closingProbes)) w];
}
