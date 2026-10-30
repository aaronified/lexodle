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
/// With [blind] the marks are only counted: the same marks, greens first, then
/// yellows, then absents, so two guesses with as many right and as many
/// elsewhere give the same marks whichever letters they are on.
List<Mark> evaluate(String target, String guess, {bool blind = false}) {
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
  final marks = out.cast<Mark>();
  if (blind) marks.sort((a, b) => a.index - b.index);
  return marks;
}

/// Words still possible after a guess produced [marks].
List<String> filterEligible(
  List<String> words,
  String guess,
  List<Mark> marks, {
  bool blind = false,
}) {
  return [
    for (final w in words)
      if (_same(evaluate(w, guess, blind: blind), marks)) w,
  ];
}

bool _same(List<Mark> a, List<Mark> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Bits in a chance: the information of an event that has chance [q].
double bitsOf(double q) => q <= 0 ? 0 : -log(q) / ln2;

/// Skill, luck, risk and bits of one guess (the maths is in docs/paper).
///
/// With [before] words still possible, a guess splits them into groups by the
/// feedback they would give. The answer follows a law: every possible word
/// equally likely, or each by its weight (how common it is) when the game drew
/// it that way. A group then has a mass m, you land in it with chance
/// q = m / M, and landing there gains -log2 q bits: the more unlikely the group,
/// the more it tells you. Everything below is about that distribution of gains.
///
/// * the expected gain H = sum(q * -log2 q) is the Shannon entropy of the split:
///   what the guess is worth on average, before the answer is known;
/// * skill = H / H* * 100, where H* is the largest H any real guess can reach
///   against these words: 100 is as informative as the best guess, 0 tells you
///   nothing. Until H* is known the skill is provisional (H* taken as the
///   finest split, every word alone), and [ready] is false;
/// * risk is how much the guess gambles on the tail: the chance of gaining less
///   than H less the chance of gaining more, at least 0, as a share of the same
///   number for the riskiest guess (D*). A risky guess usually gains less than
///   expected and now and then much more. It belongs to the guess, not to the
///   result;
/// * luck, from -100 to +100, is the chance of gaining less than you did less
///   the chance of gaining more: 0 is the middle outcome, and over every answer,
///   under the law, it averages exactly 0. See [chanceLuck];
/// * bits: the gain of the outcome you got. Expected gain plus luck in bits
///   (gain - H, which averages 0) is the gain, and over a game the gains add up
///   to the information that was needed: -log2 of the chance of the answer.
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
    this.best = 0,
    this.ready = true,
    this.risk,
    this.gain = 0,
    this.expectedGain = 0,
    this.rawRisk = 0,
    this.rank,
    this.possible = false,
    this.winChance = 0,
    this.triesLeft = 0,
    this.landed,
    this.fresh = 0,
    this.greens = 0,
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

  /// Risk, 0 to 100: see above. Null until the position has been analysed
  /// (D* is needed), and when there was no choice to take a risk on (one word
  /// left) or it was the last try.
  final double? risk;

  /// The bits the outcome you got gained, and the bits the guess is expected to
  /// gain (H).
  final double gain;
  final double expectedGain;

  /// The chance of gaining less than H less that of gaining more, in percent
  /// (negative when the other way): what [risk] is made from.
  final double rawRisk;

  /// How many of the guesses scored in the position gain more, in percent: 0 is
  /// the best expected gain of all. Null until the position has been analysed.
  final double? rank;

  /// Whether the guess could itself have been the answer: it fits every clue so
  /// far. A guess that cannot is a probe, and is not an attempt at the word.
  final bool possible;

  /// The chance it was the answer, given the clues: its share of the weight of
  /// the words still possible (the same law the skill and luck use), or 1 in n
  /// when they are equally likely. 0 for a guess that cannot be the answer.
  final double winChance;

  /// The tries left, this one included (0 when not known).
  final int triesLeft;

  /// How many of the guess's letters had not been tried before in the game, and
  /// how many positions were known to be green from the earlier guesses.
  final int fresh;
  final int greens;

  /// The words expected to be left on average after this guess (E).
  final double expected;

  /// How many groups the guess split the possible words into, and the size of
  /// the biggest one (the worst pool it could have left you in).
  final int groups;
  final int largest;

  /// The largest expected gain any real guess could reach (H*), which skill is
  /// measured against; 0 until it is known.
  final double best;

  /// Whether [skill] is measured against the real H*. False while that is still
  /// being worked out in the background.
  final bool ready;

  /// Luck in bits: the gain less the expected gain. It averages 0 over answers.
  double get luckBits => gain - expectedGain;

  GuessMetrics _with({
    double? skill,
    double? best,
    bool? ready,
    double? risk,
    double? rank,
  }) => GuessMetrics(
    guess: guess,
    skill: skill ?? this.skill,
    luck: luck,
    before: before,
    after: after,
    expected: expected,
    groups: groups,
    largest: largest,
    best: best ?? this.best,
    ready: ready ?? this.ready,
    risk: risk ?? this.risk,
    gain: gain,
    expectedGain: expectedGain,
    rawRisk: rawRisk,
    rank: rank ?? this.rank,
    possible: possible,
    winChance: winChance,
    triesLeft: triesLeft,
    landed: landed,
    fresh: fresh,
    greens: greens,
  );

  /// The same metrics with skill measured against [best] (H*).
  GuessMetrics withBest(double best) => _with(
    skill: before <= 1 || triesLeft == 1 ? skill : skillOf(expectedGain, best),
    best: best,
    ready: true,
  );

  /// The same metrics once the position has been analysed: skill against the
  /// real best guess, the risk against the riskiest, and where the guess ranks.
  GuessMetrics withLandscape(Landscape land) {
    final measured = withBest(land.bestGain);
    // with one word left, or none, there is no choice to take a risk on
    final r = before <= 1 || triesLeft == 1
        ? null
        : land.bestRisk > 0
        ? (max(0.0, rawRisk) / land.bestRisk * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;
    return measured._with(
      risk: r,
      rank: before <= 1 || triesLeft == 1
          ? null
          : land.rankPercent(expectedGain),
    );
  }
}

/// Skill from the expected gain [h] against the best real guess's [best] (H*),
/// from 0 to 100.
double skillOf(double h, double best) {
  if (best <= 1e-12) return 100; // no guess gains anything: nothing to beat
  return (h / best * 100).clamp(0.0, 100.0).toDouble();
}

/// A luck score as text: +80%, -45%, 0%. Written with a real minus sign.
String luckText(double v) {
  final r = v.round();
  return r == 0 ? '0%' : (r > 0 ? '+$r%' : '\u2212${-r}%');
}

/// Luck as the chance-weighted percentile of the gain you got. The group
/// masses [sizes] (word counts, or the groups' weights when the words are not
/// equally likely) sum to the total, so a group of mass s is landed in with
/// chance s / total, and gains -log2 of that: the bigger the group, the less it
/// gains. Landing in a group of [landed], luck = P(gaining less than you did) -
/// P(gaining more), in percent: -100 for the biggest group, +100 for the
/// smallest, 0 in the middle.
///
/// It is the mid-distribution transform of the gain, 2 * F_mid - 1, taken over
/// the chance-weighted outcomes, so it is bounded (never quite reaching either
/// end) and, over all answers, has mean exactly 0 for every guess. It depends
/// on the groups through their order and through their masses as chances, so
/// scaling every group by the same factor leaves it unchanged.
double chanceLuck(Iterable<num> sizes, num landed) {
  num n = 0, bigger = 0, smaller = 0;
  for (final s in sizes) {
    n += s;
    if (s > landed) bigger += s;
    if (s < landed) smaller += s;
  }
  return n == 0 ? 0 : (bigger - smaller) / n * 100;
}

/// How one guess splits the words still possible, from the masses of its groups.
class SplitStats {
  const SplitStats({
    required this.e,
    required this.h,
    required this.d,
    required this.groups,
    required this.largest,
    required this.total,
    required this.masses,
    this.landedMass,
    this.codes = const [],
  });

  /// The pattern of each group, in the order of [masses] (see [patternCode]).
  final List<int> codes;

  /// The mass of the group [answer] falls in when [guess] is played, or null
  /// when the patterns were not kept.
  double? landedOf(String guess, String answer) {
    if (codes.isEmpty) return landedMass;
    final at = codes.indexOf(patternCode(answer, guess));
    return at < 0 ? null : masses[at];
  }

  /// E, the expected pool: n * sum(q^2).
  final double e;

  /// H, the expected gain in bits: the Shannon entropy of the chances.
  final double h;

  /// The chance of gaining less than H less that of gaining more, in percent.
  final double d;

  /// How many groups, and how many words in the biggest.
  final int groups;
  final int largest;

  /// The total mass, and the mass of every group.
  final double total;
  final List<double> masses;

  /// The mass of the group a given answer falls in, when one was given.
  final double? landedMass;

  /// Luck for landing in a group of mass [landed]: see [chanceLuck].
  double luckOf(double landed) => chanceLuck(masses, landed);
}

/// The finest split H could be: every word in a group of its own, in bits.
double finestGain(List<String> eligible, Map<String, int>? weights) {
  final n = eligible.length;
  if (n <= 1) return 0;
  if (weights == null) return log(n) / ln2;
  var total = 0.0;
  for (final w in eligible) {
    total += max(weights[w] ?? 1, 1);
  }
  var h = 0.0;
  for (final w in eligible) {
    final q = max(weights[w] ?? 1, 1) / total;
    h -= q * log(q) / ln2;
  }
  return h;
}

/// The words guesses are scored against, prepared once: their letters as bytes
/// and the weight of each. Scoring a guess then does no map lookups and no
/// string reads, which is most of the time of analysing every word the game
/// accepts against a large list. Same numbers as scoring each pair with
/// [patternCode].
class SplitContext {
  SplitContext(
    List<String> eligible,
    Map<String, int>? weights, {
    this.blind = false,
  }) : n = eligible.length,
       len = eligible.isEmpty ? 0 : eligible.first.length,
       _alpha = {} {
    _t = Uint8List(n * len);
    _x = Float64List(n);
    var total = 0.0;
    for (var e = 0; e < n; e++) {
      final w = eligible[e];
      for (var j = 0; j < len; j++) {
        _t[e * len + j] = _alpha.putIfAbsent(
          w.codeUnitAt(j),
          () => _alpha.length,
        );
      }
      final x = weights == null ? 1.0 : max(weights[w] ?? 1, 1).toDouble();
      _x[e] = x;
      total += x;
    }
    this.total = total;
    _left = Int16List(_alpha.length + 1);
  }

  final int n;
  final int len;

  /// Whether a guess tells only how many letters are right and in place and
  /// how many right elsewhere (a blind game): groups are those counts.
  final bool blind;
  late final double total;
  final Map<int, int> _alpha;
  late final Uint8List _t;
  late final Float64List _x;
  late final Int16List _left;

  /// The stats of [guess] against the words. With an [answer], also the mass
  /// of the group it is in.
  SplitStats stats(String guess, {String? answer}) {
    final none = _alpha.length; // a letter no word has
    final g = Uint8List(len);
    for (var j = 0; j < len; j++) {
      g[j] = _alpha[guess.codeUnitAt(j)] ?? none;
    }
    const correct = 0, present = 1, absent = 2;
    assert(Mark.correct.index == correct && Mark.present.index == present);
    assert(Mark.absent.index == absent);
    final t = _t, left = _left, x = _x;
    final counts = _counts, touched = _touched, mass = _mass;
    var seen = 0;
    for (var e = 0; e < n; e++) {
      final o = e * len;
      for (var j = 0; j < len; j++) {
        if (t[o + j] != g[j]) left[t[o + j]]++;
      }
      var k = 0, greens = 0, yellows = 0;
      for (var i = 0; i < len; i++) {
        int digit;
        if (t[o + i] == g[i]) {
          digit = correct;
          greens++;
        } else if (left[g[i]] > 0) {
          left[g[i]]--;
          digit = present;
          yellows++;
        } else {
          digit = absent;
        }
        k = k * 3 + digit;
      }
      if (blind) k = greens * (len + 1) + yellows;
      for (var j = 0; j < len; j++) {
        left[t[o + j]] = 0;
      }
      if (counts[k]++ == 0) touched[seen++] = k;
      mass[k] += x[e];
    }
    return _finish(seen, guess, answer);
  }

  SplitStats _finish(int seen, String guess, String? answer) {
    final masses = Float64List(seen);
    final codes = Int32List(seen);
    var sumSq = 0.0, largest = 0;
    for (var i = 0; i < seen; i++) {
      final k = _touched[i];
      codes[i] = k;
      masses[i] = _mass[k];
      sumSq += _mass[k] * _mass[k];
      if (_counts[k] > largest) largest = _counts[k];
    }
    double? landedMass;
    if (answer != null) {
      var a = patternCode(answer, guess);
      if (blind) {
        final m = evaluate(answer, guess);
        a =
            m.where((x) => x == Mark.correct).length * (len + 1) +
            m.where((x) => x == Mark.present).length;
      }
      landedMass = _mass[a];
    }
    for (var i = 0; i < seen; i++) {
      _counts[_touched[i]] = 0;
      _mass[_touched[i]] = 0;
    }
    var h = 0.0;
    for (final m in masses) {
      final q = m / total;
      h -= q * log(q) / ln2;
    }
    var less = 0.0, more = 0.0;
    for (final m in masses) {
      final gain = log(total / m) / ln2;
      if (gain < h - 1e-9) {
        less += m;
      } else if (gain > h + 1e-9) {
        more += m;
      }
    }
    return SplitStats(
      e: n == 0 ? 0 : n * sumSq / (total * total),
      h: h,
      d: total <= 0 ? 0 : (less - more) / total * 100,
      groups: seen,
      largest: largest,
      total: total,
      masses: masses,
      landedMass: landedMass,
      codes: codes,
    );
  }
}

/// The stats of [guess] against [eligible] under [weights] (null: every word as
/// likely as the next). With an [answer], also the mass of the group it is in.
/// To score many guesses against the same words, make one [SplitContext].
SplitStats splitStats(
  List<String> eligible,
  String guess,
  Map<String, int>? weights, {
  String? answer,
  SplitContext? context,
  bool blind = false,
}) => (context ?? SplitContext(eligible, weights, blind: blind)).stats(
  guess,
  answer: answer,
);

/// Scores a guess made when [eligibleBefore] words were possible, leaving
/// [after]. Skill is measured against [best] (H*, the largest expected gain any
/// real guess has) when it is known; without it the skill is provisional (H*
/// taken as the finest split) and not [GuessMetrics.ready] if [provisional] is
/// set. Risk and the rank come with the landscape (see
/// [GuessMetrics.withLandscape]). On the [finalTry] only a word that fits the
/// clues can win, so luck is no longer about the pool you landed in but about
/// the pick itself: the outcome (1 if [solved], else 0) less the chance of that
/// outcome, which is 1 in n if the guess is one of the n possible words and 0
/// if it cannot be the answer, in percent. Three possible words give +67 for
/// the right one and -33 for a wrong one; two give +50 and -50. A guess that
/// cannot win has no chance to be lucky about, so its luck is 0 (the loss is in
/// its skill), which keeps the luck of every guess at mean zero. The skill of a
/// last try is no longer about the split either: it is the guess's chance of
/// winning as a share of the best chance any guess has (100 for the likeliest
/// word that fits, 0 for a word that cannot be the answer).
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
  int fresh = 0,
  int greens = 0,
  bool blind = false,
}) {
  final n = eligibleBefore.length;
  final possible = eligibleBefore.contains(guess);
  int weightOf(String w) => weights == null ? 1 : max(weights[w] ?? 1, 1);
  final st = splitStats(eligibleBefore, guess, weights, blind: blind);
  final winChance = possible && st.total > 0 ? weightOf(guess) / st.total : 0.0;
  // With one word left a guess cannot split anything; it is either that word
  // (100) or a wasted turn (0).
  var topWeight = 0;
  for (final w in eligibleBefore) {
    topWeight = max(topWeight, weightOf(w));
  }
  var landedMass = after.toDouble();
  if (weights != null && afterWords != null) {
    landedMass = afterWords.fold<int>(0, (a, w) => a + weightOf(w)).toDouble();
  }
  final hstar = best ?? finestGain(eligibleBefore, weights);
  // On the last try nothing is learned that can be used: skill is the chance
  // the guess wins as a share of the best chance any guess has.
  final skill = n == 0
      ? 0.0
      : n == 1
      ? (eligibleBefore.first == guess ? 100.0 : 0.0)
      : finalTry
      ? (possible ? weightOf(guess) / topWeight * 100 : 0.0)
      : skillOf(st.h, hstar);
  final luck = finalTry && n > 0
      ? ((solved ? 1.0 : 0.0) - winChance) * 100
      : st.luckOf(landedMass);
  return GuessMetrics(
    guess: guess,
    skill: skill,
    luck: luck,
    before: n,
    after: after,
    expected: st.e,
    groups: st.groups,
    largest: st.largest,
    best: hstar,
    ready: !provisional,
    gain: landedMass > 0 && st.total > 0 ? bitsOf(landedMass / st.total) : 0,
    expectedGain: st.h,
    rawRisk: st.d,
    possible: possible,
    winChance: winChance,
    triesLeft: triesLeft,
    landed: st.total > 0 ? landedMass * n / st.total : null,
    fresh: fresh,
    greens: greens,
  );
}

/// How many distinct letters of [guess] appear in none of the [earlier] guesses.
int freshLetters(String guess, Iterable<String> earlier) {
  final seen = {for (final g in earlier) ...g.split('')};
  return {
    for (final c in guess.split(''))
      if (!seen.contains(c)) c,
  }.length;
}

/// How many positions the [earlier] marks have shown to be green.
int knownGreens(Iterable<List<Mark>> earlier) {
  final green = <int>{};
  for (final marks in earlier) {
    for (var i = 0; i < marks.length; i++) {
      if (marks[i] == Mark.correct) green.add(i);
    }
  }
  return green.length;
}

class Recommendation {
  const Recommendation(
    this.word,
    this.skill,
    this.expected,
    this.canWin, {
    this.winChance,
    this.gain = 0,
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

  /// Its expected gain, in bits.
  final double gain;

  /// Whether the guess is itself one of the possible answers.
  final bool canWin;
}

/// The riskiest guesses of a position: the word, its raw risk (the chance of
/// gaining less than expected less that of gaining more, in percent) and its
/// skill.
class RiskPick {
  const RiskPick(this.word, this.raw, this.skill);
  final String word;
  final double raw;
  final double skill;
}

/// The luckiest guesses for a given answer: the word and the luck it would
/// have had.
class LuckPick {
  const LuckPick(this.word, this.luck);
  final String word;
  final double luck;
}

/// How every guess I scored would have done against the words still possible:
/// the best few, the expected gain of all of them (best first), H* (the largest
/// expected gain), D* (the largest raw risk), the riskiest picks and, when an
/// answer was given, the luckiest.
class Landscape {
  const Landscape(
    this.top,
    this.gains, {
    this.bestGain = 0,
    this.bestRisk = 0,
    this.riskiest = const [],
    this.luckiest = const [],
  });

  /// The best picks, best first.
  final List<Recommendation> top;

  /// The expected gain of every guess scored, best first; the first is H*.
  final List<double> gains;

  /// H*: the largest expected gain among the guesses scored.
  final double bestGain;

  /// D*: the largest raw risk among the guesses scored (0 when none gambles).
  final double bestRisk;

  /// The three riskiest guesses, riskiest first.
  final List<RiskPick> riskiest;

  /// The three luckiest guesses for the answer, the answer itself first.
  final List<LuckPick> luckiest;

  /// How many of the guesses scored gain more than [h], in percent: 0 for the
  /// best.
  double rankPercent(double h) {
    if (gains.isEmpty) return 0;
    var more = 0;
    for (final g in gains) {
      if (g > h + 1e-9) more++;
    }
    return more / gains.length * 100;
  }

  /// How many guesses share the best gain. When the words left are few, several
  /// guesses split them equally well and tie; the one named is the first of
  /// them, a word that could still be the answer ahead of one that could not,
  /// then the more common first, and nothing about the answer comes in.
  int get tiedForBest => gains.isEmpty
      ? 0
      : gains.where((g) => (g - gains.first).abs() <= 1e-9).length;
}

/// Scores [candidates] against the words still possible, [eligible] (which
/// must be in descending frequency). Skill is measured against the best of
/// them: the largest expected gain H* any candidate has, so pass every word the
/// game accepts as a guess for H* to be the real best. The picks are the
/// candidates with the largest expected gain; a candidate that could itself be
/// the answer wins ties, and so with two or fewer left the likelier one is
/// named first. With the real [answer] the luckiest guesses are found too.
/// Yields to the event loop now and then so a web page stays responsive.
Future<Landscape> analyseGuesses(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
  String? answer,
  bool blind = false,
}) async {
  final n = eligible.length;
  if (n == 0) return const Landscape([], []);
  final possible = eligible.toSet();
  final floor = finestGain(eligible, weights);

  Recommendation make(String w, SplitStats s, double best) => Recommendation(
    w,
    n <= 1 ? 100.0 : skillOf(s.h, best),
    s.e,
    possible.contains(w),
    gain: s.h,
  );

  final words = n <= 2
      ? eligible.take(max(k, 2)).toList()
      : candidates.toList();
  // the opening of a game scores every word against every word and is the same
  // for every game on that list, so the last one is kept
  final key = words.length * eligible.length >= _openingCells
      ? _openingKey(eligible, words, weights, blind)
      : null;
  final scored = <(String, SplitStats)>[];
  if (key != null && key == _openingKeyHeld) {
    // answered from the last game, but still on a later turn of the event loop
    // like every other analysis, so the screen shows its dots first
    await Future<void>.delayed(Duration.zero);
    scored.addAll(_openingHeld!);
  } else {
    final context = SplitContext(eligible, weights, blind: blind);
    for (final w in words) {
      scored.add((w, context.stats(w)));
      if (scored.length % 40 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (key != null) {
      _openingKeyHeld = key;
      _openingHeld = List.of(scored);
    }
  }
  if (scored.isEmpty) return const Landscape([], []);
  // largest gain first; among equals a possible answer first; sort is stable,
  // so otherwise the more frequent word stays ahead
  final byGain = [...scored]
    ..sort((x, y) {
      final c = y.$2.h.compareTo(x.$2.h);
      if (c != 0) return c;
      return (possible.contains(y.$1) ? 1 : 0) -
          (possible.contains(x.$1) ? 1 : 0);
    });
  final best = n <= 2 ? floor : byGain.first.$2.h;
  var bestRisk = 0.0;
  for (final (_, s) in scored) {
    if (s.d > bestRisk) bestRisk = s.d;
  }
  final byRisk = [...scored]
    ..sort((x, y) {
      final c = y.$2.d.compareTo(x.$2.d);
      if (c != 0) return c;
      return y.$2.h.compareTo(x.$2.h);
    });
  final riskiest = bestRisk <= 0
      ? <RiskPick>[]
      : [
          for (final (w, s) in byRisk.take(k))
            RiskPick(w, s.d, n <= 1 ? 100.0 : skillOf(s.h, best)),
        ];
  var luckiest = <LuckPick>[];
  if (answer != null) {
    final luck = <(String, double)>[
      for (final (w, s) in scored)
        if (s.landedOf(w, answer) != null)
          (w, s.luckOf(s.landedOf(w, answer)!).roundToDouble()),
    ];
    final self = luck.where((e) => e.$1 == answer).toList();
    final others = luck.where((e) => e.$1 != answer).toList()
      ..sort((x, y) => y.$2.compareTo(x.$2));
    luckiest = [
      for (final (w, l) in [...self, ...others].take(k)) LuckPick(w, l),
    ];
  }
  return Landscape(
    [for (final (w, s) in byGain.take(k)) make(w, s, best)],
    [for (final (_, s) in byGain) s.h],
    bestGain: best,
    bestRisk: bestRisk,
    riskiest: riskiest,
    luckiest: luckiest,
  );
}

/// Scoring this many (word, guess) pairs or more is kept for the next game.
const _openingCells = 4000000;
String? _openingKeyHeld;
List<(String, SplitStats)>? _openingHeld;

/// A key for an analysis: the words, the guesses and the weights, hashed.
String _openingKey(
  List<String> eligible,
  List<String> guesses,
  Map<String, int>? weights,
  bool blind,
) {
  var h = 0x811c9dc5;
  void mix(int v) => h = ((h ^ v) * 0x01000193) & 0x3fffffff;
  for (final w in eligible) {
    for (var i = 0; i < w.length; i++) {
      mix(w.codeUnitAt(i));
    }
    mix(weights == null ? 1 : (weights[w] ?? 1));
  }
  mix(blind ? 8 : 7);
  for (final w in guesses) {
    for (var i = 0; i < w.length; i++) {
      mix(w.codeUnitAt(i));
    }
  }
  return '${eligible.length}/${guesses.length}/${weights == null}/$h';
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

/// What a finished game says about how it was played: the mean luck and risk of
/// the guesses that had a choice (null when none had), and the most bits one
/// guess gained.
({double? luck, double? risk, double maxBits}) gameTraits(
  List<GuessMetrics> ms,
) {
  var luck = 0.0, risk = 0.0, n = 0, rn = 0;
  var bits = 0.0;
  for (final m in ms) {
    if (m.gain > bits) bits = m.gain;
    if (m.before <= 1) continue;
    luck += m.luck;
    n++;
    final k = m.risk;
    if (k != null) {
      risk += k;
      rn++;
    }
  }
  return (
    luck: n == 0 ? null : luck / n,
    risk: rn == 0 ? null : risk / rn,
    maxBits: bits,
  );
}
