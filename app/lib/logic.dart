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
/// the feedback they would produce. If the answer is equally likely to be any
/// of them, the pool you land in has expected size E = sum(size^2) / N.
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
///   you did less the chance of landing in a smaller one: 0 is the middle
///   outcome, and over every answer it averages exactly 0. See [chanceLuck].
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
  });
  final String guess;
  final double skill;
  final double luck;
  final int before;
  final int after;

  /// How risky the guess is, in bits: its split's Shannon entropy less its
  /// collision entropy, which is the log of the expected pool less the average
  /// log of the pool (see [splitRisk]). 0 for a split with no tail.
  final double risk;

  /// How daring the choice was, 0 to 100: of the guesses that scored strictly
  /// higher skill, the share that were less risky than this one (see
  /// [Landscape.daringOf]). The best guess has nothing better to compare with,
  /// so it has none. Null until the analysis of the position has landed.
  final double? daring;

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
    skill: before <= 1 ? skill : skillAgainst(before, expected, best),
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
  );

  /// The same metrics once the position has been analysed: skill against the
  /// real best guess, and how daring the choice was among the guesses scored.
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
      daring: before <= 1 ? null : land.daringOf(measured.skill, risk),
    );
  }
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
/// sizes [sizes] sum to the number of words N, and the answer is equally likely
/// to be any word, so a group of size s is landed in with chance s / N. Landing
/// in a group of [landed] words, luck = P(a bigger pool) - P(a smaller pool), in
/// percent: -100 for the biggest, +100 for the smallest, 0 in the middle.
///
/// It is the mid-distribution transform of the pool size, 2 * F_mid - 1, taken
/// over the chance-weighted pools, so it is bounded (never quite reaching
/// either end) and, over all answers, has mean exactly 0 for every guess. It
/// depends on the pools through their order and through their sizes as
/// chances, so scaling every group by the same factor leaves it unchanged.
double chanceLuck(Iterable<int> sizes, int landed) {
  var n = 0, bigger = 0, smaller = 0;
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
/// (E* taken as 1) and not [GuessMetrics.ready] if [provisional] is set. On the
/// [finalTry] only a word that fits the clues can win, so luck is no longer
/// about the pool you landed in but about the pick itself: the outcome (1 if
/// [solved], else 0) less the chance of that outcome, which is 1 in n if the
/// guess is one of the n possible words and 0 if it cannot be the answer, in
/// percent. Three possible words give +67 for the right one and -33 for a wrong
/// one; two give +50 and -50. A guess that cannot win has no chance to be lucky
/// about, so its luck is 0 (the loss is in its skill), which keeps the luck of
/// every guess at mean zero.
GuessMetrics scoreGuess(
  List<String> eligibleBefore,
  String guess,
  int after, {
  bool finalTry = false,
  bool solved = false,
  double? best,
  bool provisional = false,
}) {
  final n = eligibleBefore.length;
  final sizes = <int, int>{};
  for (final w in eligibleBefore) {
    final key = patternCode(w, guess);
    sizes[key] = (sizes[key] ?? 0) + 1;
  }
  final sumSq = sizes.values.fold<int>(0, (a, s) => a + s * s);
  final clogc = sizes.values.fold<double>(0, (a, s) => a + s * log(s) / ln2);
  final expected = n == 0 ? 0.0 : sumSq / n;
  // With one word left a guess cannot split anything; it is either that word
  // (100) or a wasted turn (0). The original gave 100 to both.
  final skill = n == 0
      ? 0.0
      : n == 1
      ? (eligibleBefore.first == guess ? 100.0 : 0.0)
      : skillAgainst(n, expected, best ?? 1);
  final luck = finalTry && n > 0
      ? ((solved ? 1.0 : 0.0) -
                (eligibleBefore.contains(guess) ? 1 / n : 0.0)) *
            100
      : chanceLuck(sizes.values, after);
  return GuessMetrics(
    guess: guess,
    skill: skill,
    luck: luck,
    before: n,
    after: after,
    expected: expected,
    groups: sizes.length,
    largest: sizes.values.fold<int>(0, (a, s) => s > a ? s : a),
    best: best ?? 1,
    ready: !provisional,
    risk: splitRisk(n, sumSq, clogc),
  );
}

class Recommendation {
  const Recommendation(this.word, this.skill, this.expected, this.canWin);
  final String word;

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
  const Landscape(
    this.top,
    this.skills, [
    this.bestExpected = 1,
    this.risks = const [],
  ]);

  /// The best picks, best first.
  final List<Recommendation> top;

  /// The skill of every guess scored, best first; the best is 100.
  final List<double> skills;

  /// The risk (see [splitRisk]) of each guess in [skills], in the same order.
  /// Empty when it was not worked out.
  final List<double> risks;

  /// How daring a guess of [skill] and [risk] was in this position, 0 to 100:
  /// of the guesses scored that have strictly higher skill, the share that are
  /// less risky. It says the player chose a bolder guess than they needed to,
  /// rather than showing skill: the best guess has nothing better to compare
  /// with, so it is 0. Null when the risks are not known.
  double? daringOf(double skill, double risk) {
    if (risks.length != skills.length || skills.isEmpty) return null;
    var better = 0, safer = 0;
    for (var i = 0; i < skills.length; i++) {
      if (skills[i] > skill + 1e-9) {
        better++;
        if (risks[i] < risk - 1e-9) safer++;
      }
    }
    return better == 0 ? 0 : safer / better * 100;
  }

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
}) async {
  final n = eligible.length;
  if (n == 0) return const Landscape([], []);
  final possible = eligible.toSet();
  Recommendation make(String w, int sumSq, double best) => Recommendation(
    w,
    n <= 1 ? 100.0 : skillAgainst(n, sumSq / n, best),
    sumSq / n,
    possible.contains(w),
  );

  if (n <= 2) {
    // every word splits itself from the other, so E* is 1
    final top = [
      for (final w in eligible.take(k)) make(w, _sumSquares(eligible, w), 1),
    ];
    // two words in two groups of one: nothing can be risky about that
    return Landscape(
      top,
      [for (final r in top) r.skill],
      1,
      [for (final _ in top) 0.0],
    );
  }

  final scored = <(String, int, double)>[];
  for (final w in candidates) {
    final (sq, clogc) = _splitStats(eligible, w);
    scored.add((w, sq, splitRisk(n, sq, clogc)));
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
  final best = scored.first.$2 / n;
  return Landscape(
    [for (final (w, sq, _) in scored.take(k)) make(w, sq, best)],
    [for (final (_, sq, _) in scored) skillAgainst(n, sq / n, best)],
    best,
    [for (final (_, _, risk) in scored) risk],
  );
}

/// The best next guesses, best first (see [analyseGuesses]).
Future<List<Recommendation>> recommendTop(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
}) async => (await analyseGuesses(eligible, candidates, k: k)).top;

/// The single best next guess, for the solver.
Future<Recommendation?> recommend(
  List<String> eligible,
  Iterable<String> candidates,
) async {
  final top = await recommendTop(eligible, candidates, k: 1);
  return top.isEmpty ? null : top.first;
}

/// Share of the starting uncertainty removed, as in WordleBot's "info gained":
/// 1 - ln(words left) / ln(words at the start), in percent. Cumulative: it
/// reaches 100 when one word is left.
double infoGained(int initial, int wordsLeft) {
  if (initial <= 1) return 100;
  final v = (1 - log(max(wordsLeft, 1)) / log(initial)) * 100;
  return v.clamp(0, 100).toDouble();
}

String _num(double v) => v < 10 ? v.toStringAsFixed(1) : v.round().toString();

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

/// A short plain-English reading of one step, for the review screen.
/// [picks] is empty while the alternatives are still being worked out.
String stepComment({
  required GuessMetrics m,
  required List<Recommendation> picks,
  required List<String> after,
  required bool solved,
  bool finalTry = false,
  bool guessFits = true,
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
    out.add(
      guessFits
          ? 'This was your last try, so only a word that fits the clues could '
                'win, and all $n were equally likely. ${m.guess} was one of '
                'them: a 1 in $n chance.'
          : 'This was your last try, but ${m.guess} does not fit the clues, so '
                'it could not win. Any of the $n possible words had a 1 in $n '
                'chance.',
    );
  } else if (picks.isNotEmpty) {
    final top = picks.first;
    final gap = top.skill - m.skill;
    final yours = _num(m.expected);
    final theirs = _num(top.expected);
    if (picks.any((p) => p.word == m.guess) || gap <= 0.5) {
      out.add(
        'Terrific choice. ${m.guess} would have been one of my top picks.',
      );
    } else if (gap <= 4) {
      out.add(
        'Good choice. ${top.word} was a touch sharper: about $theirs '
        'words left on average, against about $yours for ${m.guess}.',
      );
    } else if (gap <= 12) {
      out.add(
        'Decent, but a better split was available. ${top.word} leaves '
        'about $theirs words on average; ${m.guess} leaves about $yours.',
      );
    } else {
      out.add(
        'A missed chance. ${top.word} would have cut the field to about '
        '$theirs words on average; ${m.guess} leaves about $yours.',
      );
    }
  }
  // (on the last try luck is the chance of the pick, already said above)
  if (!finalTry && m.luck >= 25) {
    out.add('You got lucky: you landed in a smaller pool than expected.');
  } else if (!finalTry && m.luck <= -25) {
    out.add('Unlucky: you landed in a larger pool than expected.');
  }
  if (solved) {
    out.add('You solved it.');
  } else if (finalTry) {
    // the game is over: nothing is coming next turn
  } else if (after.length == 1) {
    out.add(
      "There's only one possible solution left, so you should solve it "
      'on your next turn.',
    );
  } else if (after.length > 1 && after.length <= 4) {
    out.add('Only ${after.length} words are left: ${after.join(', ')}.');
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

/// The sum of the squared sizes of the groups [guess] splits [eligible] into.
int splitSumSquares(List<String> eligible, String guess) =>
    _sumSquares(eligible, guess);

/// Scratch space for [_sumSquares]: a count per feedback pattern (at most 3^8)
/// and the patterns seen, so each guess costs one pass and no allocation.
final _counts = Int32List(6561);
final _touched = Int32List(6561);

/// [_sumSquares] and the sum of c log2 c over the groups, in one pass: what the
/// risk of a split needs (see [splitRisk]).
(int, double) _splitStats(List<String> eligible, String guess) {
  var seen = 0;
  for (final w in eligible) {
    final k = patternCode(w, guess);
    if (_counts[k]++ == 0) _touched[seen++] = k;
  }
  var sum = 0;
  var clogc = 0.0;
  for (var i = 0; i < seen; i++) {
    final c = _counts[_touched[i]];
    sum += c * c;
    clogc += c * log(c) / ln2;
    _counts[_touched[i]] = 0;
  }
  return (sum, clogc);
}

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
