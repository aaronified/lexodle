import 'dart:math';

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
List<String> filterEligible(List<String> words, String guess, List<Mark> marks) {
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

/// Skill and luck of one guess, ported from lexodle_metrics.py.
///
/// With [before] words still possible, a guess splits them into groups by the
/// feedback they would produce. If the answer is equally likely to be any of
/// them, the expected number left is E = sum(size^2) / N.
///
/// * skill = (N - E) / (N - 1) * 100: 100 when the guess splits the field into
///   singletons, 0 when it tells you nothing.
/// * luck = (N - after) / (N - E) * 100: words actually eliminated against
///   words expected to be. 100 is average; above is lucky, below unlucky.
class GuessMetrics {
  const GuessMetrics({
    required this.guess,
    required this.skill,
    required this.luck,
    required this.before,
    required this.after,
  });
  final String guess;
  final double skill;
  final double luck;
  final int before;
  final int after;
}

GuessMetrics scoreGuess(List<String> eligibleBefore, String guess, int after) {
  final n = eligibleBefore.length;
  final sumSq = _sumSquares(eligibleBefore, guess);
  final expected = n == 0 ? 0.0 : sumSq / n;
  final skill = n == 0 ? 0.0 : (n <= 1 ? 100.0 : (n - expected) / (n - 1) * 100);
  final luck = (n <= 1 || n - expected == 0) ? 0.0 : (n - after) / (n - expected) * 100;
  return GuessMetrics(
      guess: guess, skill: skill, luck: luck, before: n, after: after);
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

/// The best next guess for the solver: the candidate leaving the fewest words
/// in expectation, which is the same measure skill is scored by. A candidate
/// that could itself be the answer wins ties. [eligible] must be in
/// descending frequency, so with two or fewer left the likelier one is named.
/// Yields to the event loop now and then so a web page stays responsive.
Future<Recommendation?> recommend(
    List<String> eligible, Iterable<String> candidates) async {
  final n = eligible.length;
  if (n == 0) return null;
  Recommendation make(String w, int sumSq) {
    final e = sumSq / n;
    return Recommendation(w, n <= 1 ? 100.0 : (n - e) / (n - 1) * 100, e,
        eligible.contains(w));
  }

  if (n <= 2) return make(eligible.first, _sumSquares(eligible, eligible.first));

  final possible = eligible.toSet();
  String? best;
  var bestSq = 0;
  var done = 0;
  for (final w in candidates) {
    final sq = _sumSquares(eligible, w);
    if (best == null ||
        sq < bestSq ||
        (sq == bestSq && possible.contains(w) && !possible.contains(best))) {
      best = w;
      bestSq = sq;
    }
    if (++done % 40 == 0) await Future<void>.delayed(Duration.zero);
  }
  return best == null ? null : make(best, bestSq);
}

int _sumSquares(List<String> eligible, String guess) {
  final groups = <int, int>{};
  for (final w in eligible) {
    final key = patternCode(w, guess);
    groups[key] = (groups[key] ?? 0) + 1;
  }
  var sum = 0;
  for (final s in groups.values) {
    sum += s * s;
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
