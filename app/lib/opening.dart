import 'analysis_worker.dart';
import 'drill_calc.dart';
import 'logic.dart';
import 'modes.dart';
import 'words.dart';

/// How many outcomes of the first guess the opening lesson goes through.
const openingOutcomeCount = 12;

/// The first guesses worth knowing, best first, for the words of [length]: the
/// analysis of the whole list as the opening of a game, which the app keeps for
/// next time.
Future<Landscape> openingLandscape({
  required WordBank bank,
  required int length,
  required Draw draw,
}) {
  final words = bank.guessable(length);
  return analyseOffThread(words, words, k: 5, weights: bank.law(length, draw));
}

/// What the first guess [first] can show: the groups of every word as the
/// answer, the likeliest first, without the one where it is the answer itself.
/// [limit] of them (all when null). Each is a place to ask what to play next.
List<GroupLine> openingOutcomes(
  List<String> words,
  String first,
  Map<String, int>? weights, {
  int? limit = openingOutcomeCount,
}) {
  final walk = walkGroups(words, first, weights);
  final groups = [
    for (final g in walk.groups)
      if (g.marks.any((m) => m != Mark.correct)) g,
  ];
  return limit == null ? groups : groups.take(limit).toList();
}

/// The best second guesses once the first showed what [group] stands for: the
/// words still possible are the group's, and the best picks of them are worked
/// out over every word the game accepts. Best first; the only word when one is
/// left.
Future<List<Recommendation>> secondGuesses({
  required GroupLine group,
  required List<String> guessable,
  required Map<String, int>? weights,
  int k = 3,
}) async {
  if (group.words.length == 1) {
    return [Recommendation(group.words.first, 100, 1, true)];
  }
  final land = await analyseOffThread(
    group.words,
    guessable,
    k: k,
    weights: weights,
  );
  return land.top;
}
