import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WordBank bank;

  setUpAll(() async {
    bank = await WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
    );
  });

  group('the daily quartet and relay race words', () {
    test('from the curve date the words come from the whole list, mostly the '
        'commonest', () {
      expect(dailyUsesCurve('2026-10-29'), isFalse);
      expect(dailyUsesCurve(dailyCurveFrom), isTrue);
      final all = bank.answers(dailyLength);
      var ranks = <int>[];
      for (final mode in [GameMode.quartet, GameMode.relay]) {
        for (var day = 0; day < 60; day++) {
          final date = dailyShift(dailyCurveFrom, day);
          final d = DailyMulti.of(bank, mode, date)!;
          for (final w in d.answers) {
            expect(w.length, dailyLength);
            ranks.add(all.indexOf(w));
          }
          for (var i = 0; i < 4; i++) {
            for (var j = i + 1; j < 4; j++) {
              expect(sharesLetter(d.answers[i], d.answers[j]), isFalse);
            }
          }
        }
      }
      // the curve is at half at 3,000 and almost nothing past 3,500
      ranks = ranks.where((r) => r >= 0).toList();
      expect(
        ranks.where((r) => r < 3500).length,
        greaterThan(ranks.length * .95),
      );
    });

    test('four five-letter words that share no letter, from the common 3,000 '
        'before the curve date', () {
      final common = bank.answers(dailyLength).take(dailyAnswers).toSet();
      for (final mode in [GameMode.quartet, GameMode.relay]) {
        for (var day = 0; day < 30; day++) {
          final date = dailyShift('2026-10-01', day);
          final d = DailyMulti.of(bank, mode, date)!;
          expect(d.answers.length, 4, reason: '$mode $date');
          expect(d.answers.toSet().length, 4);
          for (final w in d.answers) {
            expect(w.length, dailyLength);
            expect(common, contains(w));
          }
          for (var i = 0; i < 4; i++) {
            for (var j = i + 1; j < 4; j++) {
              expect(
                sharesLetter(d.answers[i], d.answers[j]),
                isFalse,
                reason: '${d.answers} $date',
              );
            }
          }
        }
      }
    });

    test('the same for everyone, and each mode and day has its own', () {
      final a = DailyMulti.of(bank, GameMode.quartet, '2026-11-01')!;
      final b = DailyMulti.of(bank, GameMode.quartet, '2026-11-01')!;
      expect(a.answers, b.answers);
      expect(
        DailyMulti.of(bank, GameMode.relay, '2026-11-01')!.answers,
        isNot(a.answers),
      );
      expect(
        DailyMulti.of(bank, GameMode.quartet, '2026-11-02')!.answers,
        isNot(a.answers),
      );
    });

    test('the tries are the daily ones, plus the mode\'s', () {
      expect(dailyTriesOf(GameMode.classic), 6);
      expect(dailyTriesOf(GameMode.quartet), 9);
      expect(dailyTriesOf(GameMode.relay), 10);
    });
  });

  group('a log and a streak for each mode', () {
    test('they are kept apart, saved and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.recordDaily('2026-10-23', dailySolved), 1);
      expect(s.recordDaily('2026-10-24', dailySolved), 2);
      expect(
        s.recordDaily('2026-10-24', dailyDouble, mode: GameMode.quartet),
        1,
      );
      expect(s.dailyBestOf('en'), 2);
      expect(s.dailyBestOf('en', GameMode.quartet), 1);
      expect(s.dailyBestOf('en', GameMode.relay), 0);
      expect(s.dailyLogOf('en', GameMode.relay), isEmpty);
      // a language's list holds languages only
      expect(s.playedLanguages.any((l) => l.contains('|')), isFalse);

      final again = AppState();
      await again.load();
      expect(again.dailyLogOf('en', GameMode.quartet), {
        '2026-10-24': dailyDouble,
      });
      expect(again.dailyBestOf('en', GameMode.quartet), 1);
      expect(again.dailyLogOf('en'), s.dailyLogOf('en'));
    });

    test('the progress of each mode\'s daily is its own', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.saveDaily('en', '2026-10-24', ['crane']);
      s.saveDaily('en', '2026-10-24', ['crane', 'slimy'], mode: GameMode.relay);
      expect(s.dailyFor('en', '2026-10-24')!.guesses, ['crane']);
      expect(s.dailyFor('en', '2026-10-24', GameMode.relay)!.guesses.length, 2);
      expect(s.dailyFor('en', '2026-10-24', GameMode.quartet), isNull);
    });
  });
}
