import 'dart:math';
import 'dart:typed_data';

/// Ported from lexodle.py: GameWindow.evaluate_guess, choose_word and
/// filter_word_list. Behaviour is the same, with one deliberate change:
/// the eligible-word filter keeps a word only if scoring the guess against it
/// reproduces the feedback exactly. The Python filter rejects every word
/// containing a letter that scored absent, which wrongly drops answers when a
/// guess repeats a letter that is also green or yellow.
enum Mark { correct, present, absent }

/// Two-pass scoring: greens first, then yellows limited by remaining counts.
List<Mark> evaluate(String target, String guess) {
  final t = target.split('');
  final g = guess.split('');
  final counts = <String, int>{};
  for (final c in t) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final out = List<Mark?>.filled(g.length, null);
  for (var i = 0; i < g.length; i++) {
    if (g[i] == t[i]) {
      out[i] = Mark.correct;
      counts[g[i]] = counts[g[i]]! - 1;
    }
  }
  for (var i = 0; i < g.length; i++) {
    if (out[i] != null) continue;
    if ((counts[g[i]] ?? 0) > 0) {
      out[i] = Mark.present;
      counts[g[i]] = counts[g[i]]! - 1;
    } else {
      out[i] = Mark.absent;
    }
  }
  return out.cast<Mark>();
}

/// Words still possible after a guess produced [marks].
List<String> filterEligible(
  List<String> words,
  String guess,
  List<Mark> marks,
) {
  return [
    for (final w in words)
      if (_same(evaluate(w, guess), marks)) w,
  ];
}

bool _same(List<Mark> a, List<Mark> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Skill and luck of one guess (the maths is in docs/paper).
///
/// With [before] = N words still possible, a guess splits them into groups by
/// the feedback they would produce. The answer follows a law: every possible
/// word equally likely, or each by its weight (how common it is) when the game
/// drew it that way. A group then has a mass m (its words' weights, in words
/// when equal), you land in it with chance q = m / M, and the pool you land in
/// has expected size E = N * sum(q^2): the plain sum(size^2) / N when the
/// weights are equal, and the size of an equally likely pool that would be as
/// hard to tell apart when they are not.
///
/// * skill = ln(N / E) / ln(N / E*) * 100, where E* is the smallest E any real
///   guess can reach against these words: 0 when the guess tells you nothing
///   (E = N), 100 when it splits the words as evenly as the best real word
///   could. On a log scale, because the pool is cut by factors: a guess that
///   leaves 10% of the words and one that leaves 1% are a step apart, not a
///   hair. It is the guess's collision entropy (Renyi order 2) as a share of
///   the best guess's. Until E* is known the skill is provisional (E* = 1,
///   every word alone), and [ready] is false.
/// * luck, from -100 to +100, is the chance of landing in a bigger pool than
///   you did less the chance of landing in a smaller one, a pool being as big
///   as its mass: 0 is the middle outcome, and over every answer, under the
///   law, it averages exactly 0. See [chanceLuck].
class GuessMetrics {
  const GuessMetrics({
    required this.guess,
    required this.skill,
    required this.luck,
    required this.before,
    required this.after,
    this.expected = 0,
    this.groups = 0,
    this.largest = 0,
    this.best = 1,
    this.ready = true,
    this.risk = 0,
    this.daring,
    this.possible = false,
    this.winChance = 0,
    this.triesLeft = 0,
    this.landed,
  });
  final String guess;
  final double skill;
  final double luck;
  final int before;
  final int after;

  /// The size of the pool you landed in as an equally likely pool: its mass over
  /// the total, times the number of words. [after] when the words are equally
  /// likely, or when it was not worked out.
  final double? landed;
  double get landedSize => landed ?? after.toDouble();

  /// How risky the guess is, in bits: its split's Shannon entropy less its
  /// collision entropy, which is the log of the expected pool less the average
  /// log of the pool (see [splitRisk]). 0 for a split with no tail.
  final double risk;

  /// How daring the choice was, 0 to 100: going for the whole word rather than
  /// for the clues (see [daringOf]). Null until the skill is final (the analysis
  /// of the position has landed), and when there was no choice (one word left) or
  /// the tries left are not known.
  final double? daring;

  /// Whether the guess could itself have been the answer: it fits every clue so
  /// far. A guess that cannot is a probe, and is not an attempt at the word.
  final bool possible;

  /// The chance it was the answer, given the clues: its share of the weight of
  /// the words still possible (the same law the skill and luck use), or 1 in n
  /// when they are equally likely. 0 for a guess that cannot be the answer.
  final double winChance;

  /// The tries left, this one included (0 when not known).
  final int triesLeft;

  /// The words expected to be left on average after this guess (E).
  final double expected;

  /// How many groups the guess split the possible words into, and the size of
  /// the biggest one (the worst pool it could have left you in).
  final int groups;
  final int largest;

  /// The smallest expected pool any real guess could leave (E*), which skill is
  /// measured against; 1 until it is known.
  final double best;

  /// Whether [skill] is measured against the real E*. False while that is still
  /// being worked out in the background.
  final bool ready;

  /// The same metrics with skill measured against [best] (E*).
  GuessMetrics withBest(double best) => GuessMetrics(
    guess: guess,
    skill: before <= 1 || triesLeft == 1
        ? skill
        : skillAgainst(before, expected, best),
    luck: luck,
    before: before,
    after: after,
    expected: expected,
    groups: groups,
    largest: largest,
    best: best,
    ready: true,
    risk: risk,
    daring: daring,
    possible: possible,
    winChance: winChance,
    triesLeft: triesLeft,
    landed: landed,
  );

  /// The same metrics once the position has been analysed: skill against the
  /// real best guess, and from it how daring the choice was.
  GuessMetrics withLandscape(Landscape land) {
    final measured = withBest(land.bestExpected);
    return GuessMetrics(
      guess: guess,
      skill: measured.skill,
      luck: luck,
      before: before,
      after: after,
      expected: expected,
      groups: groups,
      largest: largest,
      best: land.bestExpected,
      ready: true,
      risk: risk,
      // with one word left, or none, there is no choice to be daring about
      daring: before <= 1 || triesLeft < 1
          ? null
          : daringOf(
              possible: possible,
              winChance: winChance,
              skill: measured.skill,
              triesLeft: triesLeft,
            ),
      possible: possible,
      winChance: winChance,
      triesLeft: triesLeft,
      landed: landed,
    );
  }
}

/// How daring a guess was, 0 to 100: how much it went for the whole word, and
/// not for the clues. It is the product of four things, each from 0 to 1:
///
/// * whether the guess [possible]-ly could be the answer (a probe is not an
///   attempt at the word, and is 0);
/// * what the attempt cost in what was learned: 1 - [skill] / 100, so going for
///   the word with the guess that also splits the words best costs nothing;
/// * how unlikely the word was: 1 - [winChance], its chance of being the answer
///   by frequency, so a likely word is hardly a gamble;
/// * how many tries there were to spare: 1 - 1 / [triesLeft] (this one
///   counted), so with one left going for the word is the only play, and with
///   six it is a choice.
///
/// It is not about how risky the split is (that is the risk term of the
/// accounting): it says whether the player chased the word instead of reducing
/// the pool, and so, with skill and luck, it is what the number of guesses a
/// game takes can be read from.
double daringOf({
  required bool possible,
  required double winChance,
  required double skill,
  required int triesLeft,
}) {
  if (!possible || triesLeft <= 1) return 0;
  final cost = (1 - skill / 100).clamp(0.0, 1.0);
  final unlikely = (1 - winChance).clamp(0.0, 1.0);
  final spare = 1 - 1 / triesLeft;
  return 100 * cost * unlikely * spare;
}

/// The risk of a split, in bits: the Shannon entropy of the group sizes less
/// their collision (Renyi order 2) entropy. With [n] words split into groups of
/// size c, [sumSquares] = sum c^2 and [sumClogC] = sum c log2 c, it is
/// log2(sumSquares / n) - sumClogC / n: the log of the pool you expect to be
/// left with, less the average log of the pool you are left with. It is 0 when
/// every group is the same size and grows with a tail of a few big groups (a
/// guess that usually does well and sometimes leaves nearly everything).
double splitRisk(int n, int sumSquares, double sumClogC) {
  if (n <= 1) return 0;
  final r = log(sumSquares / n) / ln2 - sumClogC / n;
  return r < 0 ? 0 : r; // rounding can leave -1e-16
}

/// [splitRisk] for groups of unequal weight: the Shannon entropy of the chances
/// less their collision entropy, in bits, from the groups' masses [masses].
double splitRiskMass(Iterable<num> masses) {
  var total = 0.0;
  for (final m in masses) {
    total += m;
  }
  if (total <= 0) return 0;
  var shannon = 0.0, collision = 0.0;
  for (final m in masses) {
    final q = m / total;
    shannon -= q * log(q) / ln2;
    collision += q * q;
  }
  final r = log(collision) / ln2 + shannon;
  return r < 0 ? 0 : r;
}

/// Skill from the expected pool [expected] (E) of [n] words, against the best
/// real guess's [best] (E*): ln(n / E) / ln(n / E*), from 0 to 100. The logarithm
/// is what keeps most guesses from crowding near 100 when many words are left.
double skillAgainst(int n, double expected, double best) {
  if (n <= 1) return 100;
  final room = log(n / best);
  if (room <= 1e-12) return 100; // no guess splits anything: nothing to beat
  return (log(n / expected) / room * 100).clamp(0.0, 100.0).toDouble();
}

/// A luck score as text: +80%, -45%, 0%. Written with a real minus sign.
String luckText(double v) {
  final r = v.round();
  return r == 0 ? '0%' : (r > 0 ? '+$r%' : '\u2212${-r}%');
}

/// Luck as the chance-weighted percentile of the pool you landed in. The group
/// sizes [sizes] (word counts, or the groups' weights when the words are not
/// equally likely) sum to the total N, so a group of size s is landed in with
/// chance s / N. Landing in a group of [landed], luck = P(a bigger pool) - P(a smaller pool), in
/// percent: -100 for the biggest, +100 for the smallest, 0 in the middle.
///
/// It is the mid-distribution transform of the pool size, 2 * F_mid - 1, taken
/// over the chance-weighted pools, so it is bounded (never quite reaching
/// either end) and, over all answers, has mean exactly 0 for every guess. It
/// depends on the pools through their order and through their sizes as
/// chances, so scaling every group by the same factor leaves it unchanged.
double chanceLuck(Iterable<num> sizes, num landed) {
  num n = 0, bigger = 0, smaller = 0;
  for (final s in sizes) {
    n += s;
    if (s > landed) bigger += s;
    if (s < landed) smaller += s;
  }
  return n == 0 ? 0 : (bigger - smaller) / n * 100;
}

/// Scores a guess made when [eligibleBefore] words were possible, leaving
/// [after]. Skill is measured against [best] (E*, the smallest expected pool any
/// real guess leaves) when it is known; without it the skill is provisional
/// (E* taken as the finest split) and not [GuessMetrics.ready] if [provisional]
/// is set. On the [finalTry] only a word that fits the clues can win, so luck is no longer
/// about the pool you landed in but about the pick itself: the outcome (1 if
/// [solved], else 0) less the chance of that outcome, which is 1 in n if the
/// guess is one of the n possible words and 0 if it cannot be the answer, in
/// percent. Three possible words give +67 for the right one and -33 for a wrong
/// one; two give +50 and -50. A guess that cannot win has no chance to be lucky
/// about, so its luck is 0 (the loss is in its skill), which keeps the luck of
/// every guess at mean zero. The skill of a last try is no longer about the
/// split either: it is the guess's chance of winning as a share of the best
/// chance any guess has (100 for the likeliest word that fits, 0 for a word
/// that cannot be the answer).
///
/// [triesLeft] (this try counted) and [weights] (how common each word is, the
/// law the game drew its answer by) are for the whole score: the groups are
/// weighed by them, and so is the chance a guess was the answer. Without them
/// every possible word is as likely as the next. A word with no weight counts
/// as 1. [afterWords] are the words left after the guess, so the group landed
/// in can be weighed; without them it is taken as [after] words of weight 1.
GuessMetrics scoreGuess(
  List<String> eligibleBefore,
  String guess,
  int after, {
  bool finalTry = false,
  bool solved = false,
  double? best,
  bool provisional = false,
  int triesLeft = 0,
  Map<String, int>? weights,
  List<String>? afterWords,
}) {
  final n = eligibleBefore.length;
  final possible = eligibleBefore.contains(guess);
  int weightOf(String w) => weights == null ? 1 : max(weights[w] ?? 1, 1);
  var total = 0;
  var squares =
      0.0; // sum of squared weights: the finest split, every word alone
  final sizes = <int, int>{};
  final masses = <int, int>{};
  for (final w in eligibleBefore) {
    final key = patternCode(w, guess);
    final x = weightOf(w);
    total += x;
    squares += x.toDouble() * x;
    sizes[key] = (sizes[key] ?? 0) + 1;
    masses[key] = (masses[key] ?? 0) + x;
  }
  final winChance = possible && total > 0 ? weightOf(guess) / total : 0.0;
  var massSquares = 0.0;
  for (final m in masses.values) {
    massSquares += m.toDouble() * m;
  }
  final sumSq = sizes.values.fold<int>(0, (a, s) => a + s * s);
  final clogc = sizes.values.fold<double>(0, (a, s) => a + s * log(s) / ln2);
  // E = N * sum(q^2); with equal weights that is sum(size^2) / N exactly
  final expected = n == 0
      ? 0.0
      : weights == null
      ? sumSq / n
      : n * massSquares / (total.toDouble() * total);
  // E* cannot be below the finest split, every word alone: 1 when equal
  final floor = n == 0 || weights == null
      ? 1.0
      : n * squares / (total.toDouble() * total);
  // With one word left a guess cannot split anything; it is either that word
  // (100) or a wasted turn (0). The original gave 100 to both.
  var topWeight = 0;
  for (final w in eligibleBefore) {
    topWeight = max(topWeight, weightOf(w));
  }
  // On the last try nothing is learned that can be used: skill is the chance
  // the guess wins as a share of the best chance any guess has.
  final skill = n == 0
      ? 0.0
      : n == 1
      ? (eligibleBefore.first == guess ? 100.0 : 0.0)
      : finalTry
      ? (possible ? weightOf(guess) / topWeight * 100 : 0.0)
      : skillAgainst(n, expected, best ?? floor);
  var landedMass = after;
  if (weights != null && afterWords != null) {
    landedMass = afterWords.fold<int>(0, (a, w) => a + weightOf(w));
  }
  final luck = finalTry && n > 0
      ? ((solved ? 1.0 : 0.0) - winChance) * 100
      : chanceLuck(masses.values, landedMass);
  return GuessMetrics(
    guess: guess,
    skill: skill,
    luck: luck,
    before: n,
    after: after,
    expected: expected,
    groups: sizes.length,
    largest: sizes.values.fold<int>(0, (a, s) => s > a ? s : a),
    best: best ?? floor,
    ready: !provisional,
    risk: weights == null
        ? splitRisk(n, sumSq, clogc)
        : splitRiskMass(masses.values),
    possible: possible,
    winChance: winChance,
    triesLeft: triesLeft,
    landed: total > 0 ? landedMass * n / total : null,
  );
}

class Recommendation {
  const Recommendation(
    this.word,
    this.skill,
    this.expected,
    this.canWin, {
    this.winChance,
  });
  final String word;

  /// The chance that the tries left are enough to solve it with this guess,
  /// when it was picked for that (see [recommendWithin]); null otherwise. Skill
  /// is then not worked out and is 0.
  final double? winChance;

  /// Skill the guess would score now (see [GuessMetrics]).
  final double skill;

  /// Expected number of words still possible after it.
  final double expected;

  /// Whether the guess is itself one of the possible answers.
  final bool canWin;
}

/// How every guess I scored would have done against the words still possible:
/// the best few, the skill of all of them (best first), and E*, the smallest
/// expected pool any of them leaves, which skill is measured against.
class Landscape {
  const Landscape(this.top, this.skills, [this.bestExpected = 1]);

  /// The best picks, best first.
  final List<Recommendation> top;

  /// The skill of every guess scored, best first; the best is 100.
  final List<double> skills;

  /// E*: the smallest expected pool among the guesses scored.
  final double bestExpected;

  /// The share of the scored guesses that [skill] beats, in percent: the ones
  /// that scored less, plus half of those that scored the same.
  double percentile(double skill) {
    if (skills.isEmpty) return 0;
    var less = 0, same = 0;
    for (final s in skills) {
      if (s < skill - 1e-9) {
        less++;
      } else if ((s - skill).abs() <= 1e-9) {
        same++;
      }
    }
    return (less + same / 2) / skills.length * 100;
  }

  /// How many guesses share the best skill. When the words left are few,
  /// several guesses split them equally well and tie; the one named is the
  /// first of them, a word that could still be the answer ahead of one that
  /// could not, then the more common first, and nothing about the answer
  /// comes in.
  int get tiedForBest => skills.isEmpty
      ? 0
      : skills.where((s) => (s - skills.first).abs() <= 1e-9).length;

  /// Where [skill] stands among the scored guesses, from 0 (as good as the
  /// best): how many scored more.
  int rankOf(double skill) => skills.where((s) => s > skill + 1e-9).length;
}

/// Scores [candidates] against the words still possible, [eligible] (which
/// must be in descending frequency). Skill is measured against the best of
/// them: the smallest expected pool E* any candidate leaves, so pass every word
/// the game accepts as a guess for E* to be the real best. The picks are the
/// candidates leaving the fewest words in expectation; a candidate that could
/// itself be the answer wins ties, and so with two or fewer left the likelier
/// one is named first. Yields to the event loop now and then so a web page
/// stays responsive.
Future<Landscape> analyseGuesses(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
}) async {
  final n = eligible.length;
  if (n == 0) return const Landscape([], []);
  final possible = eligible.toSet();
  Recommendation make(String w, double e, double best) => Recommendation(
    w,
    n <= 1 ? 100.0 : skillAgainst(n, e, best),
    e,
    possible.contains(w),
  );

  if (n <= 2) {
    // every word splits itself from the other, so E* is the finest split's
    final floor = _finestSplit(eligible, weights);
    final top = [
      for (final w in eligible.take(k))
        make(w, _expectedPool(eligible, w, weights), floor),
    ];
    return Landscape(top, [for (final r in top) r.skill], floor);
  }

  final scored = <(String, double)>[];
  for (final w in candidates) {
    scored.add((w, _expectedPool(eligible, w, weights)));
    if (scored.length % 40 == 0) await Future<void>.delayed(Duration.zero);
  }
  if (scored.isEmpty) return const Landscape([], []);
  // fewest left first; among equals a possible answer first; sort is stable,
  // so otherwise the more frequent word stays ahead
  scored.sort((x, y) {
    final c = x.$2.compareTo(y.$2);
    if (c != 0) return c;
    return (possible.contains(y.$1) ? 1 : 0) -
        (possible.contains(x.$1) ? 1 : 0);
  });
  final best = scored.first.$2;
  return Landscape(
    [for (final (w, e) in scored.take(k)) make(w, e, best)],
    [for (final (_, e) in scored) skillAgainst(n, e, best)],
    best,
  );
}

/// E, the expected pool, of [guess] against [eligible]: N * sum(q^2) with the
/// chances q of the groups under [weights]; the plain sum(size^2) / N when they
/// are null.
double _expectedPool(
  List<String> eligible,
  String guess,
  Map<String, int>? weights,
) {
  final n = eligible.length;
  if (weights == null) return _sumSquares(eligible, guess) / n;
  var seen = 0;
  var total = 0.0;
  for (final w in eligible) {
    final k = patternCode(w, guess);
    final x = max(weights[w] ?? 1, 1).toDouble();
    total += x;
    if (_mass[k] == 0) _touched[seen++] = k;
    _mass[k] += x;
  }
  var sum = 0.0;
  for (var i = 0; i < seen; i++) {
    final m = _mass[_touched[i]];
    sum += m * m;
    _mass[_touched[i]] = 0;
  }
  return n * sum / (total * total);
}

/// The smallest E any guess could reach against [eligible]: every word in a
/// group of its own, N * sum(q^2) over the words' chances; 1 when equal.
double _finestSplit(List<String> eligible, Map<String, int>? weights) {
  if (weights == null) return 1;
  var total = 0.0, squares = 0.0;
  for (final w in eligible) {
    final x = max(weights[w] ?? 1, 1).toDouble();
    total += x;
    squares += x * x;
  }
  return eligible.length * squares / (total * total);
}

/// The best next guesses, best first (see [analyseGuesses]).
Future<List<Recommendation>> recommendTop(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
}) async =>
    (await analyseGuesses(eligible, candidates, k: k, weights: weights)).top;

/// The single best next guess, for the solver.
Future<Recommendation?> recommend(
  List<String> eligible,
  Iterable<String> candidates, {
  Map<String, int>? weights,
}) async {
  final top = await recommendTop(eligible, candidates, k: 1, weights: weights);
  return top.isEmpty ? null : top.first;
}

/// The best next guess for the tries left, [triesLeft] counting this one.
///
/// With three or more it is [recommend]'s: the split that leaves fewest words.
/// With two, the guess that gives the best chance of solving it by the last try
/// (its own chance of being the answer, plus the chance that the likeliest word
/// of the group the answer falls in is it; with every word as likely as the
/// next, that is the guess with the most groups). With one, the likeliest word
/// that fits: only a word that can be the answer can win, so nothing else is
/// worth a try. [weights] is how common each word is, to weigh the chances;
/// without it they are equal.
Future<Recommendation?> recommendWithin(
  List<String> eligible,
  Iterable<String> candidates,
  int triesLeft, {
  Map<String, int>? weights,
}) async {
  if (eligible.isEmpty) return null;
  if (triesLeft >= 3) {
    return recommend(eligible, candidates, weights: weights);
  }
  int weightOf(String w) => max(weights?[w] ?? 1, 1);
  var total = 0;
  for (final w in eligible) {
    total += weightOf(w);
  }
  final n = eligible.length;
  if (triesLeft <= 1) {
    var pick = eligible.first;
    for (final w in eligible) {
      if (weightOf(w) > weightOf(pick)) pick = w;
    }
    return Recommendation(
      pick,
      0,
      _sumSquares(eligible, pick) / n,
      true,
      winChance: weightOf(pick) / total,
    );
  }
  final possible = eligible.toSet();
  String? pick;
  var bestChance = -1.0;
  var scored = 0;
  for (final g in candidates) {
    var seen = 0;
    for (final w in eligible) {
      final k = patternCode(w, g);
      final x = weightOf(w);
      if (_maxWeight[k] == 0) _touched[seen++] = k;
      if (x > _maxWeight[k]) _maxWeight[k] = x;
    }
    var sum = 0;
    for (var i = 0; i < seen; i++) {
      sum += _maxWeight[_touched[i]];
      _maxWeight[_touched[i]] = 0;
    }
    final chance = sum / total;
    // a word that could be the answer wins a tie; otherwise the first (the
    // more common) stays
    if (chance > bestChance + 1e-12 ||
        (chance > bestChance - 1e-12 &&
            pick != null &&
            !possible.contains(pick) &&
            possible.contains(g))) {
      bestChance = chance;
      pick = g;
    }
    if (++scored % 40 == 0) await Future<void>.delayed(Duration.zero);
  }
  if (pick == null) return null;
  return Recommendation(
    pick,
    0,
    _sumSquares(eligible, pick) / n,
    possible.contains(pick),
    winChance: bestChance,
  );
}

/// Share of the starting uncertainty removed, as in WordleBot's "info gained":
/// 1 - ln(words left) / ln(words at the start), in percent. Cumulative: it
/// reaches 100 when one word is left.
double infoGained(int initial, int wordsLeft) {
  if (initial <= 1) return 100;
  final v = (1 - log(max(wordsLeft, 1)) / log(initial)) * 100;
  return v.clamp(0, 100).toDouble();
}

String ordinal(int n) => const [
  'first',
  'second',
  'third',
  'fourth',
  'fifth',
  'sixth',
  'seventh',
  'eighth',
  'ninth',
  'tenth',
  'eleventh',
  'twelfth',
][n.clamp(1, 12) - 1];

/// A short plain-English reading of one step, for the review screen: one
/// sentence of verdict, then at most one short sentence of fact.
/// [picks] is empty while the alternatives are still being worked out.
String stepComment({
  required GuessMetrics m,
  required List<Recommendation> picks,
  required List<String> after,
  required bool solved,
  bool finalTry = false,
  bool guessFits = true,
  bool equalChances = true,
  bool guessIsPossible = true,
}) {
  final out = <String>[];
  if (m.before <= 1) {
    out.add(
      solved
          ? 'Only one word was possible, and you played it.'
          : 'Only one word was left, and this was not it.',
    );
  } else if (finalTry) {
    // the last try: nothing is left to learn, only a word that fits the clues
    // can win, and each of those is as likely as the next
    final n = m.before;
    final chance = (m.winChance * 100).toStringAsFixed(
      m.winChance < .1 ? 1 : 0,
    );
    out.add(
      guessFits && !guessIsPossible
          ? 'Last try: ${m.guess} fits the clues, but this game never picks '
                'it, so it could not win.'
          : !guessFits
          ? 'Last try: ${m.guess} does not fit the clues, so it could not win.'
          : !equalChances
          ? 'Last try: ${m.guess} fit the clues, a $chance% chance.'
          : 'Last try: ${m.guess} fit the clues, a 1 in $n chance.',
    );
  } else if (picks.isNotEmpty) {
    final top = picks.first;
    final gap = top.skill - m.skill;
    if (picks.any((p) => p.word == m.guess) || gap <= 0.5) {
      out.add('Terrific choice: ${m.guess} is one of my top picks.');
    } else if (gap <= 4) {
      out.add('Good choice, but ${top.word} was a touch sharper.');
    } else if (gap <= 12) {
      out.add('Decent, but ${top.word} was a better split.');
    } else {
      out.add('A missed chance: ${top.word} was a much better split.');
    }
  }
  // one fact at most: the end, the few words left, or the luck
  if (solved) {
    out.add('You solved it.');
  } else if (finalTry) {
    // the game is over: nothing is coming next turn
  } else if (after.length == 1) {
    out.add('Only one word is left: ${after.single}.');
  } else if (after.length > 1 && after.length <= 4) {
    out.add('Only ${after.length} words are left: ${after.join(', ')}.');
  } else if (m.luck >= 25) {
    out.add('You got lucky: the clues were kind.');
  } else if (m.luck <= -25) {
    out.add('Unlucky: the clues were harsh.');
  }
  return out.join(' ');
}

/// The words worth scoring as a next guess: the 600 likeliest answers and the
/// 600 most frequent words accepted as guesses. Scoring every word would be
/// slow for little gain; the best splitters are common words.
Set<String> recommendationCandidates(
  List<String> eligible,
  List<String> guessable,
) => {...eligible.take(600), ...guessable.take(600)};

/// E, the expected pool, of [guess] against [eligible] under [weights] (null:
/// every word as likely as the next): see [GuessMetrics].
double expectedPool(
  List<String> eligible,
  String guess, {
  Map<String, int>? weights,
}) => _expectedPool(eligible, guess, weights);

/// The sum of the squared sizes of the groups [guess] splits [eligible] into.
int splitSumSquares(List<String> eligible, String guess) =>
    _sumSquares(eligible, guess);

/// Scratch space for [_sumSquares]: a count per feedback pattern (at most 3^8)
/// and the patterns seen, so each guess costs one pass and no allocation.
final _counts = Int32List(6561);
final _touched = Int32List(6561);
final _maxWeight = List<int>.filled(6561, 0);
final _mass = Float64List(6561);

int _sumSquares(List<String> eligible, String guess) {
  var seen = 0;
  for (final w in eligible) {
    final k = patternCode(w, guess);
    if (_counts[k]++ == 0) _touched[seen++] = k;
  }
  var sum = 0;
  for (var i = 0; i < seen; i++) {
    final c = _counts[_touched[i]];
    sum += c * c;
    _counts[_touched[i]] = 0;
  }
  return sum;
}

/// The feedback of [guess] against [target] packed into one int (base 3 per
/// position, [Mark.index] as the digit), without allocating. Same result as
/// [evaluate]; it exists because scoring a recommendation runs it millions of
/// times. A yellow takes any target letter not already used by a green or an
/// earlier yellow, which is what the count-based [evaluate] does.
int patternCode(String target, String guess) {
  final n = guess.length;
  var used = 0; // target positions consumed
  var green = 0; // guess positions scored green
  for (var i = 0; i < n; i++) {
    if (guess.codeUnitAt(i) == target.codeUnitAt(i)) {
      green |= 1 << i;
      used |= 1 << i;
    }
  }
  var code = 0;
  for (var i = 0; i < n; i++) {
    var digit = Mark.correct.index;
    if (green & (1 << i) == 0) {
      digit = Mark.absent.index;
      final g = guess.codeUnitAt(i);
      for (var j = 0; j < n; j++) {
        if (used & (1 << j) == 0 && target.codeUnitAt(j) == g) {
          used |= 1 << j;
          digit = Mark.present.index;
          break;
        }
      }
    }
    code = code * 3 + digit;
  }
  return code;
}

/// Frequency-weighted random choice, as choose_word does.
String chooseWord(List<String> words, List<int> weights, Random rng) {
  final total = weights.fold<int>(0, (a, b) => a + b);
  var r = rng.nextDouble() * total;
  for (var i = 0; i < words.length; i++) {
    r -= weights[i];
    if (r <= 0) return words[i];
  }
  return words.last;
}
