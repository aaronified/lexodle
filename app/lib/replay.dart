import 'history.dart';
import 'logic.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'multi_review.dart';
import 'review.dart';
import 'words.dart';

/// Rebuilding a finished game from the history, which keeps only its facts: the
/// answers and the guesses, in order. Everything else a review shows (the marks,
/// the words left, how each guess scored) is worked out from them again, in the
/// same way a game works it out as it is played, so a game from last month is
/// reviewed with today's maths.

/// The record a [ReviewPage] shows for the classic game [g] and its guess rows.
/// The scores in it are provisional until the review has analysed each step,
/// which it does itself when no analysis is given.
GameRecord replayClassic(WordBank bank, GameRow g, List<GuessRow> rows) {
  final answer = g.answers.first;
  var eligible = List.of(bank.guessable(g.length));
  final guesses = <String>[];
  final marks = <List<Mark>>[];
  final metrics = <GuessMetrics>[];
  final befores = <List<String>>[];
  for (var i = 0; i < rows.length; i++) {
    final word = rows[i].word;
    final m = evaluate(answer, word);
    final after = filterEligible(eligible, word, m);
    metrics.add(
      scoreGuess(
        eligible,
        word,
        after.length,
        finalTry: i + 1 >= g.tries,
        solved: word == answer,
        provisional: true,
      ),
    );
    befores.add(eligible);
    eligible = after;
    guesses.add(word);
    marks.add(m);
  }
  return GameRecord(
    bank: bank,
    length: g.length,
    poolSize: g.pool,
    answer: answer,
    guesses: guesses,
    marks: marks,
    metrics: metrics,
    befores: befores,
    finalEligible: eligible,
    won: g.won,
    tries: g.tries,
  );
}

/// The record a [MultiReviewPage] shows for the quartet or relay race [g].
MultiRecord replayMulti(WordBank bank, GameRow g, List<GuessRow> rows) {
  final game = MultiGame(
    g.mode,
    g.answers,
    g.tries,
    words: bank.guessable(g.length),
    provisional: true,
  );
  for (final r in rows) {
    game.guess(r.word);
  }
  return MultiRecord(
    bank: bank,
    mode: g.mode,
    length: g.length,
    tries: g.tries,
    answers: g.answers,
    guesses: game.guesses,
    steps: game.steps,
    won: game.won,
  );
}

/// The guess rows of the classic game [g] worked out afresh: every guess is
/// scored against the best real guess in its position, and given its daring.
/// Slow (it looks at every word the game accepts, for every guess).
Future<List<GuessRow>> rescoreClassic(
  WordBank bank,
  GameRow g,
  List<GuessRow> rows,
) async {
  final rec = replayClassic(bank, g, rows);
  final guessable = bank.guessable(g.length);
  final out = <GuessRow>[];
  for (var i = 0; i < rec.guesses.length; i++) {
    final land = await analyseGuesses(rec.befores[i], guessable);
    out.add(guessRowOf(i, rec.metrics[i].withLandscape(land)));
  }
  return out;
}

/// The same for a quartet or relay race: a step's skill and luck are the means
/// over the boards it was made for, with each board's skill measured against its
/// best real guess. It has no daring.
Future<List<GuessRow>> rescoreMulti(
  WordBank bank,
  GameRow g,
  List<GuessRow> rows,
) async {
  final rec = replayMulti(bank, g, rows);
  final guessable = bank.guessable(g.length);
  final out = <GuessRow>[];
  for (var i = 0; i < rec.steps.length; i++) {
    final land = await analyseMulti(rec.steps[i].liveBefore, guessable);
    final step = rec.steps[i].withBests(land.bests);
    out.add(
      GuessRow(
        game: 0,
        n: i,
        word: rec.guesses[i],
        skill: step.skill,
        luck: step.luck,
      ),
    );
  }
  return out;
}

/// Works out again every game saved under an older [metricsVersion], one after
/// another, and returns how many were done. [bankFor] gives the word list of a
/// language (null if it has gone, which leaves that game as it is); [onEach] is
/// told after each game; [cancelled] stops it between games. A game that cannot
/// be worked out is left as it was.
Future<int> rescoreStale(
  History h,
  Future<WordBank?> Function(String lang) bankFor, {
  void Function(int done, int total)? onEach,
  bool Function()? cancelled,
}) async {
  final stale = List.of(h.stale());
  var done = 0;
  for (final g in stale) {
    if (cancelled?.call() ?? false) break;
    try {
      final bank = await bankFor(g.lang);
      if (bank == null) continue;
      final rows = h.guessesOf(g.id);
      final fresh = g.isClassic
          ? await rescoreClassic(bank, g, rows)
          : await rescoreMulti(bank, g, rows);
      h.replaceGuesses(g.id, fresh);
      done++;
      onEach?.call(done, stale.length);
    } catch (_) {
      // leave it stale: it is tried again next time
    }
  }
  return done;
}
