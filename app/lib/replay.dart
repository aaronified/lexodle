import 'analysis_worker.dart';
import 'daily.dart';
import 'history.dart';
import 'geography.dart';
import 'logic.dart';
import 'modes.dart';
import 'multi_analysis.dart';
import 'multi_review.dart';
import 'review.dart';
import 'review_text.dart';
import 'words.dart';

/// Rebuilding a finished game from the history, which keeps only its facts: the
/// answers and the guesses, in order. Everything else a review shows (the marks,
/// the words left, how each guess scored) is worked out from them again, in the
/// same way a game works it out as it is played, so a game from last month is
/// reviewed with today's maths.

/// The words that could have been the answer of [g], and the chances they had,
/// as the scores of the game are worked out under them: a daily from
/// [dailyCurveFrom] is drawn by the curve from the whole list, an earlier one
/// was one of its 3,000 words each equally likely, and any other game by the
/// way it was drawn. [key] names the law, for what is kept per law.
({List<String> eligible, Map<String, int>? law, String key}) lawOfGame(
  WordBank bank,
  GameRow g,
) {
  if (g.daily.isNotEmpty) {
    return dailyUsesCurve(g.daily)
        ? (
            eligible: List.of(bank.guessable(g.length)),
            law: bank.law(g.length, Draw.sigmoid),
            key: 's',
          )
        : (
            eligible: List.of(bank.answers(g.length).take(dailyAnswers)),
            law: null,
            key: 'd',
          );
  }
  return (
    eligible: List.of(bank.guessable(g.length)),
    law: bank.law(g.length, g.draw),
    key: switch (g.draw) {
      Draw.sigmoid => 's',
      Draw.equal => 'u',
      Draw.frequency => 'f',
    },
  );
}

/// The record a [ReviewPage] shows for the classic game [g] and its guess rows.
/// The scores in it are provisional until the review has analysed each step,
/// which it does itself when no analysis is given.
GameRecord replayClassic(WordBank bank, GameRow g, List<GuessRow> rows) {
  final answer = g.answers.first;
  final blind = g.mode == GameMode.blind;
  final drawn = lawOfGame(bank, g);
  var eligible = drawn.eligible;
  // a word list that has since changed may not hold the answer any more: it is
  // still the answer, so it is among the possible words
  if (!eligible.contains(answer)) eligible.insert(0, answer);
  final law = drawn.law;
  final guesses = <String>[];
  final marks = <List<Mark>>[];
  final metrics = <GuessMetrics>[];
  final befores = <List<String>>[];
  for (var i = 0; i < rows.length; i++) {
    final word = rows[i].word;
    final m = evaluate(answer, word, blind: blind);
    final after = filterEligible(eligible, word, m, blind: blind);
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
        // the places of a blind game's greens are not shown
        greens: blind ? 0 : knownGreens(marks),
        blind: blind,
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
    kind: drawKindOf(g.draw, daily: g.daily, mode: g.mode),
    daily: g.daily.isNotEmpty,
    blind: blind,
    lockdown: g.mode == GameMode.lockdown,
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
    weights: lawOfGame(bank, g).law,
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
    kind: drawKindOf(g.draw, daily: g.daily),
    daily: g.daily.isNotEmpty,
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
        ? '${bank.language.code}:${g.length}:${lawOfGame(bank, g).key}'
              '${g.mode == GameMode.blind ? 'b' : ''}${g.mode == GameMode.themed ? 't' : ''}'
        : null;
    var land = key == null ? null : opening?[key];
    land ??= await analyseOffThread(
      rec.befores[i],
      rec.lockdown
          ? lockedGuesses(
              guessable,
              rec.guesses.take(i).toList(),
              rec.marks.take(i).toList(),
            )
          : guessable,
      weights: rec.weights,
      blind: rec.blind,
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
      final bank = g.mode == GameMode.themed
          ? await _placesBank(bankFor, g.lang)
          : await bankFor(g.lang);
      if (bank == null) continue;
      final rows = h.guessesOf(g.id);
      final fresh = !g.mode.multi
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

/// The places of the themed wordle, as the bank of the language [lang] (they
/// are English only).
Future<WordBank?> _placesBank(
  Future<WordBank?> Function(String code) bankFor,
  String lang,
) async {
  final en = await bankFor(lang);
  return en == null ? null : Geography.load(en.language);
}
