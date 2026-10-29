import 'analysis_worker.dart';
import 'daily.dart';
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
  // a daily's answer was one of its 3,000 words, so only those were possible
  var eligible = List.of(
    g.daily.isEmpty
        ? bank.guessable(g.length)
        : bank.answers(g.length).take(dailyAnswers),
  );
  // a word list that has since changed may not hold the answer any more: it is
  // still the answer, so it is among the possible words
  if (!eligible.contains(answer)) eligible.insert(0, answer);
  final law = g.byFrequency ? bank.weightMap(g.length) : null;
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
        triesLeft: g.tries - i,
        weights: law,
        afterWords: after,
        provisional: true,
        fresh: freshLetters(word, guesses),
        greens: knownGreens(marks),
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
    weights: law,
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
    weights: g.freq ? bank.weightMap(g.length) : null,
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
    weights: game.weights,
  );
}

/// The guess rows of the classic game [g] worked out afresh: every guess is
/// scored against the best real guess in its position, and given its risk and rank.
/// Slow (it looks at every word the game accepts, for every guess).
///
/// The first guess of every game is made against every word, and is the same
/// position for all of them, so its analysis (the slowest) is kept in [opening]
/// when one is given, and used again for the next game of that language and
/// length.
Future<List<GuessRow>> rescoreClassic(
  WordBank bank,
  GameRow g,
  List<GuessRow> rows, {
  Map<String, Landscape>? opening,
}) async {
  final rec = replayClassic(bank, g, rows);
  final guessable = bank.guessable(g.length);
  final out = <GuessRow>[];
  for (var i = 0; i < rec.guesses.length; i++) {
    // the opening position is the same for every game under one law
    final key = i == 0
        ? '${bank.language.code}:${g.length}:'
              '${g.byFrequency
                  ? 'f'
                  : g.daily.isEmpty
                  ? 'u'
                  : 'd'}'
        : null;
    var land = key == null ? null : opening?[key];
    land ??= await analyseOffThread(
      rec.befores[i],
      guessable,
      weights: rec.weights,
    );
    if (key != null) opening?[key] = land;
    out.add(guessRowOf(i, rec.metrics[i].withLandscape(land)));
  }
  return out;
}

/// The same for a quartet or relay race: a step's skill and luck are the means
/// over the boards it was made for, with each board's skill measured against its
/// best real guess. It has no risk.
Future<List<GuessRow>> rescoreMulti(
  WordBank bank,
  GameRow g,
  List<GuessRow> rows,
) async {
  final rec = replayMulti(bank, g, rows);
  final guessable = bank.guessable(g.length);
  final out = <GuessRow>[];
  for (var i = 0; i < rec.steps.length; i++) {
    final land = await analyseMulti(
      rec.steps[i].liveBefore,
      guessable,
      weights: rec.weights,
    );
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
/// another, newest first (the recent ones are what a playstyle and the latest
/// weeks are read from), and returns how many were done. There can be thousands,
/// so it can be stopped between games with [cancelled] and picked up later: each
/// game is replaced as it is done, and [onEach] says after every one so that the
/// caller can save. [bankFor] gives the word list of a language (null if it has
/// gone, which leaves that game as it is). A game that cannot be worked out is
/// left as it was.
Future<int> rescoreStale(
  History h,
  Future<WordBank?> Function(String lang) bankFor, {
  void Function(int done, int total)? onEach,
  bool Function()? cancelled,
}) async {
  final stale = h.stale().reversed.toList();
  final opening = <String, Landscape>{};
  var done = 0;
  for (final g in stale) {
    if (cancelled?.call() ?? false) break;
    try {
      final bank = await bankFor(g.lang);
      if (bank == null) continue;
      final rows = h.guessesOf(g.id);
      final fresh = g.isClassic
          ? await rescoreClassic(bank, g, rows, opening: opening)
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
