import 'logic.dart';

/// What learn mode knows about one guess once the position it was made in has
/// been analysed: how it split the words that fitted, and how the best guess
/// of that position split them. Pure numbers, so the sentences below are
/// tested without any screen.
class GuessReport {
  const GuessReport({
    required this.guess,
    required this.skill,
    required this.before,
    required this.after,
    required this.yourGroups,
    required this.yourLargest,
    required this.yourExpected,
    required this.yourGain,
    required this.bestWord,
    required this.bestWords,
    required this.bestGain,
    required this.bestGroups,
    required this.bestLargest,
    required this.bestExpected,
    required this.bestCanWin,
    required this.yourCanWin,
  });

  final String guess;

  /// Skill, 0 to 100: the guess's expected gain against the best guess's.
  final double skill;

  /// The words that fitted the clues before the guess, and after it.
  final int before;
  final int after;

  /// How the guess split the words that fitted: groups, the words in the
  /// biggest group, the words expected to be left, and the bits expected.
  final int yourGroups;
  final int yourLargest;
  final double yourExpected;
  final double yourGain;

  /// The best guess, the best few (best first), and how the best split them.
  final String bestWord;
  final List<String> bestWords;
  final double bestGain;
  final int bestGroups;
  final int bestLargest;
  final double bestExpected;

  /// Whether each of the two could itself have been the answer.
  final bool bestCanWin;
  final bool yourCanWin;

  /// Whether no guess does better.
  bool get asGoodAsAny => skill >= 99.99;

  /// Whether there was nothing to split (one word fitted, or none).
  bool get trivial => before <= 1;
}

String _words(num n) => '${_trim(n)} ${n == 1 ? 'word' : 'words'}';

String _trim(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toStringAsFixed(1);
}

String _bits(double b) => b.toStringAsFixed(2);

/// The one line under a guess: its skill and, unless it was as good as any,
/// what the best was.
String learnVerdict(GuessReport r) {
  final top = r.bestWords.take(3).join(', ');
  if (r.asGoodAsAny) return 'skill 100 · as good as any guess ($top)';
  return 'skill ${r.skill.toStringAsFixed(0)} · the best: $top';
}

/// The lines that say why: how the guess split the words that fitted, how the
/// best one did, and what the difference was. A few short sentences.
List<String> learnWhy(GuessReport r) {
  if (r.trivial) {
    return r.before == 1
        ? ['one word fitted, so only that word could win']
        : ['no word fitted the clues'];
  }
  final yours = [
    'your ${r.guess}: ${r.yourGroups} '
        '${r.yourGroups == 1 ? 'group' : 'groups'}, the biggest '
        '${_words(r.yourLargest)}; about ${_words(r.yourExpected)} left '
        '(${_bits(r.yourGain)} bits expected)',
  ];
  if (r.asGoodAsAny) {
    return [
      ...yours,
      'no guess splits ${_words(r.before)} better than this',
      if (r.bestWords.length > 1)
        'others as good: ${r.bestWords.where((w) => w != r.guess).take(3).join(', ')}',
    ];
  }
  final best = [
    'the best, ${r.bestWord}: ${r.bestGroups} groups, the biggest '
        '${_words(r.bestLargest)}; about ${_words(r.bestExpected)} left '
        '(${_bits(r.bestGain)} bits expected)',
  ];
  final reasons = <String>[];
  if (r.bestGroups > r.yourGroups) {
    reasons.add(
      'it tells ${_words(r.before)} apart in ${r.bestGroups} groups, '
      'yours in ${r.yourGroups}',
    );
  }
  if (r.bestLargest < r.yourLargest) {
    reasons.add(
      'its worst case is ${_words(r.bestLargest)}, not ${_words(r.yourLargest)}',
    );
  }
  if (r.bestCanWin && !r.yourCanWin) {
    reasons.add('it could also have been the answer, yours could not');
  }
  if (reasons.isEmpty) {
    reasons.add('it leaves fewer words on average');
  }
  return [...yours, ...best, '${reasons.join('; ')}.'];
}

/// How the hint ladder reads at [level]: 1 the first letter, 2 the word, 3
/// the word and why it is the best.
String learnHint(int level, List<String> bestWords, GuessReport? bestSplit) {
  if (bestWords.isEmpty || level < 1) return '';
  final w = bestWords.first;
  if (level == 1) return 'the best guess starts with ${w[0]}';
  if (level == 2) return 'the best guess: $w';
  final s = bestSplit;
  if (s == null) return 'the best guess: $w';
  return 'the best guess: $w. it splits ${_words(s.before)} into '
      '${s.bestGroups} groups, the biggest ${_words(s.bestLargest)}; about '
      '${_words(s.bestExpected)} left (${_bits(s.bestGain)} bits expected).';
}

/// The report for [guess] made when [before] words fitted and [after] did,
/// given the [landscape] of that position (its best picks) and the weights
/// the game uses.
GuessReport reportGuess({
  required List<String> before,
  required String guess,
  required List<String> after,
  required Landscape landscape,
  Map<String, int>? weights,
}) {
  final measured = scoreGuess(
    before,
    guess,
    after.length,
    weights: weights,
    afterWords: after,
    provisional: true,
  ).withBest(landscape.bestGain);
  final best = landscape.top.isEmpty ? null : landscape.top.first;
  final bestStats = best == null
      ? null
      : splitStats(before, best.word, weights);
  return GuessReport(
    guess: guess,
    skill: measured.skill,
    before: before.length,
    after: after.length,
    yourGroups: measured.groups,
    yourLargest: measured.largest,
    yourExpected: measured.expected,
    yourGain: measured.expectedGain,
    bestWord: best?.word ?? guess,
    bestWords: [for (final r in landscape.top) r.word],
    bestGain: landscape.bestGain,
    bestGroups: bestStats?.groups ?? measured.groups,
    bestLargest: bestStats?.largest ?? measured.largest,
    bestExpected: bestStats?.e ?? measured.expected,
    bestCanWin: best?.canWin ?? false,
    yourCanWin: measured.possible,
  );
}

/// The report for the best guess alone (no guess made yet), for the hint that
/// says why it is the best.
GuessReport reportBest({
  required List<String> before,
  required Landscape landscape,
  Map<String, int>? weights,
}) {
  final best = landscape.top.first;
  final st = splitStats(before, best.word, weights);
  return GuessReport(
    guess: best.word,
    skill: 100,
    before: before.length,
    after: before.length,
    yourGroups: st.groups,
    yourLargest: st.largest,
    yourExpected: st.e,
    yourGain: st.h,
    bestWord: best.word,
    bestWords: [for (final r in landscape.top) r.word],
    bestGain: landscape.bestGain,
    bestGroups: st.groups,
    bestLargest: st.largest,
    bestExpected: st.e,
    bestCanWin: best.canWin,
    yourCanWin: best.canWin,
  );
}
