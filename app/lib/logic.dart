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

/// Skill and luck of one guess. Skill is ported from lexodle_metrics.py.
///
/// With [before] words still possible, a guess splits them into groups by the
/// feedback they would produce. If the answer is equally likely to be any of
/// them, the expected number left is E = sum(size^2) / N.
///
/// * skill = (N - E) / (N - 1) * 100: 100 when the guess splits the field into
///   singletons, 0 when it tells you nothing.
/// * luck = (1 - after / E) * 100, a signed percentage: how much smaller
///   (positive) or larger (negative) than average the pool you landed in was.
///   0 is exactly average, which is also what it is when the guess could not
///   split the words (one left, or no information): there is only one pool.
///   (The original compared words removed with words expected to be removed;
///   that saturates near 100 whenever most words go either way.)
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
  });
  final String guess;
  final double skill;
  final double luck;
  final int before;
  final int after;

  /// The words expected to be left on average after this guess.
  final double expected;

  /// How many groups the guess split the possible words into, and the size of
  /// the biggest one (the worst pool it could have left you in).
  final int groups;
  final int largest;
}

/// A luck score as text: +80%, -45%, 0%. Written with a real minus sign.
String luckText(double v) {
  final r = v.round();
  return r == 0 ? '0%' : (r > 0 ? '+$r%' : '\u2212${-r}%');
}

GuessMetrics scoreGuess(List<String> eligibleBefore, String guess, int after) {
  final n = eligibleBefore.length;
  final sizes = <int, int>{};
  for (final w in eligibleBefore) {
    final key = patternCode(w, guess);
    sizes[key] = (sizes[key] ?? 0) + 1;
  }
  final sumSq = sizes.values.fold<int>(0, (a, s) => a + s * s);
  final expected = n == 0 ? 0.0 : sumSq / n;
  // With one word left a guess cannot split anything; it is either that word
  // (100) or a wasted turn (0). The original gave 100 to both.
  final skill = n == 0
      ? 0.0
      : n == 1
      ? (eligibleBefore.first == guess ? 100.0 : 0.0)
      : (n - expected) / (n - 1) * 100;
  final luck = expected <= 0 ? 0.0 : (expected - after) / expected * 100;
  return GuessMetrics(
    guess: guess,
    skill: skill,
    luck: luck,
    before: n,
    after: after,
    expected: expected,
    groups: sizes.length,
    largest: sizes.values.fold<int>(0, (a, s) => s > a ? s : a),
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

/// The best next guesses, best first: the candidates leaving the fewest words
/// in expectation, which is the same measure skill is scored by. A candidate
/// that could itself be the answer wins ties. [eligible] must be in
/// descending frequency, so with two or fewer left the likelier one is named
/// first. Yields to the event loop now and then so a web page stays
/// responsive.
Future<List<Recommendation>> recommendTop(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
}) async {
  final n = eligible.length;
  if (n == 0) return const [];
  final possible = eligible.toSet();
  Recommendation make(String w, int sumSq) {
    final e = sumSq / n;
    return Recommendation(
      w,
      n <= 1 ? 100.0 : (n - e) / (n - 1) * 100,
      e,
      possible.contains(w),
    );
  }

  if (n <= 2) {
    return [
      for (final w in eligible.take(k)) make(w, _sumSquares(eligible, w)),
    ];
  }

  final scored = <(String, int)>[];
  for (final w in candidates) {
    scored.add((w, _sumSquares(eligible, w)));
    if (scored.length % 40 == 0) await Future<void>.delayed(Duration.zero);
  }
  // fewest left first; among equals a possible answer first; sort is stable,
  // so otherwise the more frequent word stays ahead
  scored.sort((x, y) {
    final c = x.$2.compareTo(y.$2);
    if (c != 0) return c;
    return (possible.contains(y.$1) ? 1 : 0) -
        (possible.contains(x.$1) ? 1 : 0);
  });
  return [for (final (w, sq) in scored.take(k)) make(w, sq)];
}

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

/// The expected words left implied by a skill score over [before] words.
double expectedLeft(int before, double skill) =>
    before <= 1 ? 1 : before - skill / 100 * (before - 1);

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
][n.clamp(1, 10) - 1];

/// A short plain-English reading of one step, for the review screen.
/// [picks] is empty while the alternatives are still being worked out.
String stepComment({
  required GuessMetrics m,
  required List<Recommendation> picks,
  required List<String> after,
  required bool solved,
  bool guessCanBeAnswer = true,
}) {
  final out = <String>[];
  if (m.before <= 1) {
    out.add(
      solved
          ? 'Only one word was possible, and you played it.'
          : 'Only one word was left, and this was not it.',
    );
  } else if (picks.isNotEmpty) {
    final top = picks.first;
    final gap = top.skill - m.skill;
    final yours = _num(expectedLeft(m.before, m.skill));
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
  if (!guessCanBeAnswer && !solved) {
    out.add(
      '${m.guess} is accepted as a guess, but the game never uses it as '
      'an answer, so it could not have won.',
    );
  }
  if (m.luck >= 25) {
    out.add('You got lucky: you landed in a smaller pool than expected.');
  } else if (m.luck <= -25) {
    out.add('Unlucky: you landed in a larger pool than expected.');
  }
  if (solved) {
    out.add('You solved it.');
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
