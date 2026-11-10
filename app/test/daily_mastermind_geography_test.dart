import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WordBank bank;
  late WordBank places;

  setUpAll(() async {
    final langs = await WordBank.languages();
    final en = langs.firstWhere((l) => l.code == 'en');
    bank = await WordBank.load(en);
    places = await Geography.load(en);
  });

  group('the mastermind daily', () {
    test('has no word and no limit on guesses, at the daily length', () {
      final d = Daily.of(bank, '2026-11-12', GameMode.mastermind)!;
      expect(d.answer, isEmpty);
      expect(d.tries, 0);
      expect(d.length, dailyLength);
      expect(dailyTriesOf(GameMode.mastermind), 0);
    });

    /// A game played with [guesses]: what the daily said to each, and the words
    /// still possible at the end.
    (List<List<Mark>>, List<String>) play(String date, List<String> guesses) {
      var eligible = List.of(bank.guessable(dailyLength));
      final said = <List<Mark>>[];
      for (final (i, g) in guesses.indexed) {
        final m = mastermindDailyReply(eligible, g, 'en', date, i);
        said.add(m);
        eligible = [
          for (final w in eligible)
            if (evaluate(w, g).join() == m.join()) w,
        ];
      }
      return (said, eligible);
    }

    const guesses = ['crane', 'sloth', 'pudgy', 'fjord'];

    test('says the same to the same guesses, on every play', () {
      final a = play('2026-11-12', guesses);
      final b = play('2026-11-12', guesses);
      expect(
        [for (final m in a.$1) m.join()],
        [for (final m in b.$1) m.join()],
      );
      expect(a.$2, b.$2);
    });

    test('every reply is one a word still possible would give', () {
      final (said, left) = play('2026-11-12', guesses);
      expect(said.length, guesses.length);
      // the replies fit at least one word of the list, the last pool included
      expect(left, isNotEmpty);
      for (final w in left) {
        for (final (i, g) in guesses.indexed) {
          expect(evaluate(w, g).join(), said[i].join());
        }
      }
    });

    test('is not the same every day', () {
      final seen = <String>{};
      for (var day = 0; day < 30; day++) {
        final date = dailyShift('2026-11-01', day);
        seen.add(play(date, guesses).$1.map((m) => m.join()).join('|'));
      }
      expect(seen.length, greaterThan(20));
    });

    test('an empty list answers as the guess itself', () {
      final m = mastermindDailyReply([], 'crane', 'en', '2026-11-12', 0);
      expect(m.every((x) => x == Mark.correct), isTrue);
    });

    test('a reply to the same guess does not depend on earlier guesses', () {
      // the hash has the number of the guess and the guess, not what was
      // guessed before: two games reaching the same pool agree
      final all = bank.guessable(dailyLength);
      final a = mastermindDailyReply(all, 'crane', 'en', '2026-11-12', 2);
      final b = mastermindDailyReply(all, 'crane', 'en', '2026-11-12', 2);
      expect(a.join(), b.join());
    });
  });

  group('the geography (themed) daily', () {
    test('is a place of five letters, six tries, the same all day', () {
      final d = Daily.of(places, '2026-11-12', GameMode.themed)!;
      expect(d.answer.length, dailyLength);
      expect(d.tries, dailyTriesOf(GameMode.themed));
      expect(Geography.placeOf(d.answer), isNotNull);
      expect(Daily.of(places, '2026-11-12', GameMode.themed)!.answer, d.answer);
    });

    test('changes from day to day, and is not the classic word', () {
      final answers = <String>{};
      for (var day = 0; day < 40; day++) {
        final date = dailyShift('2026-11-01', day);
        final d = Daily.of(places, date, GameMode.themed)!;
        answers.add(d.answer);
        expect(d.answer, isNot(Daily.of(places, date)!.answer));
      }
      expect(answers.length, greaterThan(30));
    });

    test('a place is not repeated within the no-repeat window', () {
      final seen = <String>[];
      for (var day = 0; day < dailyNoRepeat; day++) {
        seen.add(
          Daily.of(
            places,
            dailyShift(dailyCurveFrom, day),
            GameMode.themed,
          )!.answer,
        );
      }
      expect(seen.toSet().length, seen.length);
    });
  });

  group('a clean sweep counts the dailies a language offers', () {
    GameResult solved(GameMode m, String lang, String date) => GameResult(
      lang: lang,
      length: 5,
      tries: 6,
      used: 3,
      won: true,
      mode: m,
      daily: true,
      date: date,
    );

    int sweeps(String lang, Iterable<GameMode> modes) {
      final st = AchState();
      for (final m in modes) {
        st.value = metrics['dailyFullDays']!.step(
          st,
          solved(m, lang, '2026-11-12'),
        );
      }
      return st.value.toInt();
    }

    test('English needs the themed daily too', () {
      final all = GameMode.loopFor('en').where((m) => m.hasDaily).toList();
      expect(all, contains(GameMode.themed));
      expect(all, contains(GameMode.mastermind));
      expect(sweeps('en', all), 1);
      expect(sweeps('en', all.where((m) => m != GameMode.themed)), 0);
    });

    test('another language has no themed daily to solve', () {
      final all = GameMode.loopFor('de').where((m) => m.hasDaily).toList();
      expect(all, isNot(contains(GameMode.themed)));
      expect(all, contains(GameMode.mastermind));
      expect(sweeps('de', all), 1);
    });
  });
}
