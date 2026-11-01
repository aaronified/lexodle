// logic.dart has the function that counts fresh letters, playstyle.dart the
// threshold of the same name
import 'logic.dart' hide freshLetters;
import 'logic.dart' as logic show freshLetters;
import 'playstyle.dart';

/// What the playstyle would make of a guess: the numbers it reads (risk, rank,
/// fresh letters, whether the guess fits, the phase) and the habit they add up
/// to. Worked out for a guess that learn mode shows, with the same rule
/// ([behaviourFor]) the app uses on the guesses a player has made.
class StyleProfile {
  const StyleProfile({
    required this.guess,
    required this.behaviour,
    required this.phase,
    required this.before,
    required this.greens,
    required this.fresh,
    required this.fits,
    required this.risk,
    required this.rank,
    required this.skill,
    required this.luck,
  });

  final String guess;

  /// The habit it counts as, or null when it counts as none.
  final Behaviour? behaviour;

  /// The phase the position is in (null with one word left).
  final Phase? phase;

  /// The words that fitted before it, the greens known, the letters it used
  /// that had not been tried, and whether it fits every clue.
  final int before;
  final int greens;
  final int fresh;
  final bool fits;

  /// Risk (0 to 100) and rank (percent of guesses that gain more; 0 is the
  /// best); null when the position leaves no choice.
  final double? risk;
  final double? rank;

  /// Skill, and luck (-100 to 100): what the answer did for the guess, which is
  /// not a choice.
  final double skill;
  final double luck;
}

/// Profiles [guess], made when [before] words fitted and [after] still do, given
/// the analysis of the position ([landscape]); [earlier] and [earlierMarks] are
/// the guesses of the game so far (for the fresh letters and the greens).
StyleProfile profileGuess({
  required List<String> before,
  required String guess,
  required List<String> after,
  required Landscape landscape,
  Map<String, int>? weights,
  List<String> earlier = const [],
  List<List<Mark>> earlierMarks = const [],
}) {
  final fresh = logic.freshLetters(guess, earlier);
  final greens = knownGreens(earlierMarks);
  final m = scoreGuess(
    before,
    guess,
    after.length,
    weights: weights,
    afterWords: after,
    provisional: true,
    fresh: fresh,
    greens: greens,
  ).withLandscape(landscape);
  return StyleProfile(
    guess: guess,
    behaviour: behaviourFor(
      before: before.length,
      greens: greens,
      risk: m.risk,
      rank: m.rank,
      fresh: fresh,
      fits: m.possible,
    ),
    phase: phaseOf(before.length, greens),
    before: before.length,
    greens: greens,
    fresh: fresh,
    fits: m.possible,
    risk: m.risk,
    rank: m.rank,
    skill: m.skill,
    luck: m.luck,
  );
}

String _n(double? v) => v == null ? 'unknown' : v.round().toString();

/// The line that says which habit a guess counts as and the numbers behind it,
/// or why it counts as none.
String styleLine(StyleProfile p) {
  final b = p.behaviour;
  if (b != null) {
    final why = switch (b) {
      Behaviour.gambler => 'risk ${_n(p.risk)}, ${b.rule}',
      Behaviour.maximiser =>
        'ranks in the top ${_n(p.rank)}% of the guesses scored, ${b.rule}',
      Behaviour.eliminator =>
        '${p.fresh} letters never tried in the game, ${b.rule}',
      Behaviour.closer => 'it fits every clue, so it can win',
      Behaviour.prober =>
        'it cannot win, but ranks in the top ${_n(p.rank)}% with '
            '${p.before} words left',
    };
    return 'style: ${b.label} · $why';
  }
  switch (p.phase) {
    case null:
      return 'style: none · one word left, nothing to choose';
    case Phase.middle:
      return 'style: none · the middle game ($endUpTo to ${earlyFrom - 1} '
          'words, under $endGreens greens) counts for no habit';
    case Phase.early:
      return 'style: none · not a gamble (risk ${_n(p.risk)} under '
          '$gamblerRisk), not in the top $topRank% (rank ${_n(p.rank)}%), '
          'and ${p.fresh} fresh letters is under $freshLetters';
    case Phase.end:
      return 'style: none · it does not fit the clues, and is not in the '
          'top $topRank% with 3 or more words left to split '
          '(rank ${_n(p.rank)}%, ${p.before} words)';
  }
}

/// Luck, explained: what it was, and that it is the answer's doing. Luck cannot
/// be learned, so the line only says what happened.
String luckExplained(double luck) {
  final r = luck.round();
  if (r == 0) {
    return 'luck 0 · the answer fell about where it usually does for this guess';
  }
  final sign = r > 0 ? '+$r' : '−${-r}';
  return r > 0
      ? 'luck $sign · the answer fell in a smaller group than usual, so the '
            'clues gained more. that was the answer, not your choice'
      : 'luck $sign · the answer fell in a bigger group than usual, so the '
            'clues gained less. that was the answer, not your choice';
}
