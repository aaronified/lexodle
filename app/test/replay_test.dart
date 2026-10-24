import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_analysis.dart';
import 'package:lexodle/replay.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordBank bank;
  late List<String> pool;

  setUpAll(() async {
    final langs = await WordBank.languages();
    bank = await WordBank.load(langs.firstWhere((l) => l.code == 'fr'));
    pool = bank.answers(4, 500);
  });

  /// A game row, and guess rows holding garbage scores: only the words matter.
  (GameRow, List<GuessRow>) game(
    List<String> guesses, {
    required String answer,
    int tries = 6,
    GameMode mode = GameMode.classic,
    List<String>? answers,
    int version = metricsVersion,
    String lang = 'fr',
  }) {
    final h = History();
    final row = h.add(
      at: 1000,
      lang: lang,
      mode: mode,
      length: 4,
      tries: tries,
      pool: 500,
      answers: answers ?? [answer],
      won: guesses.isNotEmpty && guesses.last == answer,
      guesses: [
        for (var i = 0; i < guesses.length; i++)
          GuessRow(game: 0, n: i, word: guesses[i], skill: 3.14, luck: 99),
      ],
    );
    return (row.withVersion(version), h.guessesOf(row.id));
  }

  group('a classic game rebuilt', () {
    late String answer;
    late List<String> wrong;
    setUpAll(() {
      answer = pool[10];
      wrong = pool.where((w) => w != answer).take(3).toList();
    });

    test('the marks, the words left and the score of every guess', () {
      final (g, rows) = game([...wrong, answer], answer: answer);
      final r = replayClassic(bank, g, rows);
      expect(r.answer, answer);
      expect(r.guesses, [...wrong, answer]);
      expect(r.won, isTrue);
      expect(r.tries, 6);
      expect(r.length, 4);
      expect(r.poolSize, 500);
      expect(r.bank, same(bank));
      var eligible = List.of(bank.guessable(4));
      for (var i = 0; i < r.guesses.length; i++) {
        final m = evaluate(answer, r.guesses[i]);
        expect(r.marks[i], m, reason: 'guess $i');
        expect(r.befores[i], eligible, reason: 'guess $i');
        final after = filterEligible(eligible, r.guesses[i], m);
        final want = scoreGuess(
          eligible,
          r.guesses[i],
          after.length,
          finalTry: i + 1 >= 6,
          solved: r.guesses[i] == answer,
          provisional: true,
        );
        expect(r.metrics[i].skill, want.skill, reason: 'guess $i');
        expect(r.metrics[i].luck, want.luck, reason: 'guess $i');
        expect(r.metrics[i].before, eligible.length);
        expect(r.metrics[i].after, after.length);
        expect(r.metrics[i].ready, isFalse, reason: 'until the review looks');
        eligible = after;
      }
      expect(r.finalEligible, eligible);
      expect(r.initial, bank.guessable(4).length);
    });

    test('the stored scores are ignored: only the guesses count', () {
      final (g, a) = game([...wrong, answer], answer: answer);
      final (_, b) = game([...wrong, answer], answer: answer);
      final x = replayClassic(bank, g, a);
      final y = replayClassic(bank, g, b);
      expect(x.metrics.map((m) => m.skill), y.metrics.map((m) => m.skill));
      // and 3.14, the stored skill, is not what it replays to
      expect(x.metrics.first.skill, isNot(3.14));
    });

    test('a lost game keeps the last try rule', () {
      final lost = pool.where((w) => w != answer).take(3).toList();
      final (g, rows) = game(lost, answer: answer, tries: 3);
      final r = replayClassic(bank, g, rows);
      expect(r.won, isFalse);
      var eligible = List.of(bank.guessable(4));
      for (var i = 0; i < 2; i++) {
        eligible = filterEligible(eligible, lost[i], evaluate(answer, lost[i]));
      }
      final after = filterEligible(
        eligible,
        lost[2],
        evaluate(answer, lost[2]),
      );
      final want = scoreGuess(
        eligible,
        lost[2],
        after.length,
        finalTry: true,
        solved: false,
        provisional: true,
      );
      expect(r.metrics[2].luck, want.luck);
      expect(r.tries, 3);
    });

    test('a game with no guesses has none to review', () {
      final (g, rows) = game([], answer: answer);
      expect(replayClassic(bank, g, rows).guesses, isEmpty);
    });
  });

  group('scoring a classic game again', () {
    late String answer;
    late List<String> wrong;
    setUpAll(() {
      answer = pool[25];
      wrong = pool.where((w) => w != answer).take(2).toList();
    });

    test(
      'every guess is scored against the best real guess, with its daring',
      () async {
        final (g, rows) = game([...wrong, answer], answer: answer);
        final fresh = await rescoreClassic(bank, g, rows);
        expect(fresh.length, 3);
        final rec = replayClassic(bank, g, rows);
        for (var i = 0; i < 3; i++) {
          final land = await analyseGuesses(rec.befores[i], bank.guessable(4));
          final want = rec.metrics[i].withLandscape(land);
          expect(fresh[i].word, rec.guesses[i]);
          expect(fresh[i].n, i);
          expect(fresh[i].skill, closeTo(want.skill, 1e-9), reason: 'guess $i');
          expect(fresh[i].luck, closeTo(want.luck, 1e-9));
          expect(fresh[i].risk, closeTo(want.risk, 1e-9));
          expect(fresh[i].before, rec.befores[i].length);
          expect(fresh[i].after, want.after);
          if (rec.befores[i].length > 1) {
            expect(fresh[i].daring, closeTo(want.daring!, 1e-9));
            expect(fresh[i].daring, inInclusiveRange(0, 100));
          }
        }
        expect(fresh.first.daring, isNotNull);
        expect(
          fresh.first.skill,
          isNot(3.14),
          reason: 'the stored score is gone',
        );
      },
    );

    test('the best opening is not daring', () async {
      final first = await analyseGuesses(bank.guessable(4), bank.guessable(4));
      final best = first.top.first.word;
      final (g, rows) = game([best], answer: pool[3], tries: 6);
      final fresh = await rescoreClassic(bank, g, rows);
      expect(fresh.single.skill, closeTo(100, 1e-9));
      expect(fresh.single.daring, 0);
    });
  });

  group('a quartet rebuilt and scored again', () {
    late List<String> answers;
    late List<String> guesses;
    setUpAll(() {
      answers = pool.skip(40).take(4).toList();
      guesses = pool.skip(100).take(3).toList();
    });

    test('the steps are the ones a game makes', () {
      final (g, rows) = game(
        guesses,
        answer: answers.first,
        answers: answers,
        mode: GameMode.quartet,
        tries: 9,
      );
      final r = replayMulti(bank, g, rows);
      final live = MultiGame(
        GameMode.quartet,
        answers,
        9,
        words: bank.guessable(4),
      );
      for (final w in guesses) {
        live.guess(w);
      }
      expect(r.mode, GameMode.quartet);
      expect(r.answers, answers);
      expect(r.guesses, guesses);
      expect(r.steps.length, 3);
      expect(r.won, live.won);
      expect(r.tries, 9);
      for (var i = 0; i < 3; i++) {
        expect(r.steps[i].skill, live.steps[i].skill, reason: 'step $i');
        expect(r.steps[i].luck, live.steps[i].luck, reason: 'step $i');
      }
    });

    test('a relay race replays the same way', () {
      final (g, rows) = game(
        guesses,
        answer: answers.first,
        answers: answers,
        mode: GameMode.relay,
        tries: 8,
      );
      final r = replayMulti(bank, g, rows);
      expect(r.mode, GameMode.relay);
      expect(r.steps.length, 3);
    });

    test(
      'scored again, a step is the mean over its boards, with no daring',
      () async {
        final (g, rows) = game(
          guesses,
          answer: answers.first,
          answers: answers,
          mode: GameMode.quartet,
          tries: 9,
        );
        final fresh = await rescoreMulti(bank, g, rows);
        expect(fresh.length, 3);
        final rec = replayMulti(bank, g, rows);
        for (var i = 0; i < 3; i++) {
          final land = await analyseMulti(
            rec.steps[i].liveBefore,
            bank.guessable(4),
          );
          final step = rec.steps[i].withBests(land.bests);
          expect(fresh[i].word, guesses[i]);
          expect(fresh[i].skill, closeTo(step.skill, 1e-9), reason: 'step $i');
          expect(fresh[i].luck, closeTo(step.luck, 1e-9));
          expect(fresh[i].daring, isNull);
        }
      },
    );
  });

  group('scoring the games saved under older maths', () {
    Future<WordBank?> frOnly(String lang) async => lang == 'fr' ? bank : null;

    History stale() {
      final h = History();
      final a = pool[10];
      for (var i = 0; i < 2; i++) {
        final (g, rows) = game([pool[1], a], answer: a);
        final row = h.add(
          at: i,
          lang: g.lang,
          mode: g.mode,
          length: 4,
          tries: 6,
          pool: 500,
          answers: g.answers,
          won: true,
          guesses: rows,
        );
        h.games[h.games.indexWhere((x) => x.id == row.id)] = row.withVersion(0);
      }
      return h;
    }

    test('each is replaced, and none is stale afterwards', () async {
      final h = stale();
      expect(h.stale().length, 2);
      final seen = <(int, int)>[];
      final n = await rescoreStale(
        h,
        frOnly,
        onEach: (d, t) => seen.add((d, t)),
      );
      expect(n, 2);
      expect(seen, [(1, 2), (2, 2)]);
      expect(h.stale(), isEmpty);
      for (final g in h.games) {
        expect(g.version, metricsVersion);
        final rows = h.guessesOf(g.id);
        expect(rows.length, 2);
        expect(rows.every((r) => r.skill != 3.14), isTrue);
        expect(rows.first.daring, isNotNull);
      }
      // the facts of the games are untouched
      expect(h.games.first.answers, [pool[10]]);
      expect(h.guesses.length, 4);
    });

    test('a language that is gone leaves its games as they were', () async {
      final h = stale();
      final (g, rows) = game([pool[1], pool[10]], answer: pool[10], lang: 'xx');
      final row = h.add(
        at: 9,
        lang: 'xx',
        mode: g.mode,
        length: 4,
        tries: 6,
        pool: 500,
        answers: g.answers,
        won: true,
        guesses: rows,
      );
      h.games[h.games.indexWhere((x) => x.id == row.id)] = row.withVersion(0);
      final n = await rescoreStale(h, frOnly);
      expect(n, 2);
      expect(h.stale().map((x) => x.lang), ['xx']);
    });

    test('a game that cannot be scored is skipped, the rest go on', () async {
      final h = stale();
      var calls = 0;
      final n = await rescoreStale(h, (lang) async {
        if (calls++ == 0) throw StateError('disk');
        return bank;
      });
      expect(n, 1);
      expect(h.stale().length, 1);
    });

    test('it can be stopped between games', () async {
      final h = stale();
      var asked = 0;
      final n = await rescoreStale(h, frOnly, cancelled: () => asked++ >= 1);
      expect(n, 1);
      expect(h.stale().length, 1);
    });

    test('nothing stale means nothing to do', () async {
      final h = History();
      final (_, rows) = game([pool[1]], answer: pool[2]);
      h.add(
        at: 1,
        lang: 'fr',
        mode: GameMode.classic,
        length: 4,
        tries: 6,
        pool: 500,
        answers: [pool[2]],
        won: false,
        guesses: rows,
      );
      expect(await rescoreStale(h, frOnly), 0);
    });

    test('quartet games are scored again too', () async {
      final h = History();
      final answers = pool.skip(40).take(4).toList();
      final (g, rows) = game(
        pool.skip(100).take(2).toList(),
        answer: answers.first,
        answers: answers,
        mode: GameMode.quartet,
        tries: 9,
      );
      final row = h.add(
        at: 1,
        lang: 'fr',
        mode: GameMode.quartet,
        length: 4,
        tries: 9,
        pool: 500,
        answers: answers,
        won: false,
        guesses: rows,
      );
      h.games[0] = row.withVersion(0);
      expect(await rescoreStale(h, frOnly), 1);
      expect(h.stale(), isEmpty);
      expect(h.guessesOf(row.id).every((r) => r.skill != 3.14), isTrue);
      expect(g.mode, GameMode.quartet);
    });
  });
}
