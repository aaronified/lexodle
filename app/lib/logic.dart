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
