import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/daily_streak.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameResult dailyResult({
  bool won = true,
  int used = 5,
  int streak = 1,
  List<double> skills = const [50, 50, 50, 50, 50],
}) => GameResult(
  lang: 'en',
  length: 5,
  tries: 6,
  used: used,
  won: won,
  pool: 3000,
  skills: skills,
  daily: true,
  dailyStreak: streak,
);

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));

Future<WordBank> _bank(WidgetTester tester, String code) async =>
    (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == code),
      ),
    ))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    dailyClock = DateTime.now;
  });
  tearDown(() => dailyClock = DateTime.now);

  group('the date', () {
    test(
      'is the date on the player\'s own calendar, changing at local midnight',
      () {
        // local times, so the test means the same in every time zone
        expect(dailyDate(DateTime(2026, 10, 24, 0, 0, 0)), '2026-10-24');
        expect(dailyDate(DateTime(2026, 10, 24, 23, 59, 59)), '2026-10-24');
        expect(dailyDate(DateTime(2026, 10, 25, 0, 0, 0)), '2026-10-25');
        expect(dailyDate(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
        expect(dailyDate(DateTime(2027, 1, 1)), '2027-01-01');
      },
    );

    test('an instant given in UTC is read on the local calendar', () {
      final t = DateTime.utc(2026, 10, 24, 20, 30);
      final l = t.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(dailyDate(t), '${l.year}-${two(l.month)}-${two(l.day)}');
    });

    test('the date a daily is on is read from the clock it goes by', () {
      dailyClock = () => DateTime(2026, 10, 24, 23, 59, 30);
      expect(dailyDate(), '2026-10-24');
      dailyClock = () => DateTime(2026, 10, 25, 0, 0, 5);
      expect(dailyDate(), '2026-10-25');
    });

    test('shifts across month and year ends', () {
      expect(dailyShift('2026-03-01', -1), '2026-02-28');
      expect(dailyShift('2028-03-01', -1), '2028-02-29');
      expect(dailyShift('2026-12-31', 1), '2027-01-01');
      expect(dailyShift('nonsense', 3), 'nonsense');
    });

    test('the week is the last seven days, today last', () {
      expect(dailyRolling('2026-10-24'), [
        '2026-10-18',
        '2026-10-19',
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
        '2026-10-24',
      ]);
      // whatever the weekday, today is the last, and there are seven
      for (var d = 0; d < 14; d++) {
        final today = dailyShift('2026-10-19', d);
        final week = dailyRolling(today);
        expect(week.length, 7, reason: today);
        expect(week.last, today);
        expect(week.first, dailyShift(today, -6));
      }
      // across the end of a month and of a year
      expect(dailyRolling('2026-11-02').first, '2026-10-27');
      expect(dailyRolling('2027-01-03'), [
        '2026-12-28',
        '2026-12-29',
        '2026-12-30',
        '2026-12-31',
        '2027-01-01',
        '2027-01-02',
        '2027-01-03',
      ]);
      expect(dailyRolling('2026-10-24', 3), [
        '2026-10-22',
        '2026-10-23',
        '2026-10-24',
      ]);
      expect(dailyRolling('nonsense'), isEmpty);
    });

    test('each day has the letter of its weekday', () {
      // 2026-10-24 is a Saturday
      expect(
        [for (final d in dailyRolling('2026-10-24')) dailyLetter(d)],
        ['s', 'm', 't', 'w', 't', 'f', 's'],
      );
      expect(dailyLetter('nonsense'), '');
    });
  });

  group('the pick', () {
    test('the hash is fixed: the same on every device and release', () {
      // these numbers must never change, or the daily word changes under
      // everyone's feet (and the web build, with its doubles, must agree)
      expect(dailyHash('lexodle-daily|en|2026-10-24'), 1153185177);
      expect(dailyHash('lexodle-daily|en|2026-10-25'), 629203083);
      expect(dailyHash('lexodle-daily|fr|2026-10-24'), 1398704324);
      expect(dailyHash('lexodle-daily|de|2027-01-01'), 1605736768);
      expect(dailyIndex('en', '2026-10-24', 3000), 177);
      expect(dailyIndex('fr', '2026-10-24', 3000), 2324);
    });

    test('an index is always inside the pool', () {
      for (final n in [1, 2, 2383, 3000]) {
        for (var d = 0; d < 400; d++) {
          final i = dailyIndex('en', dailyShift('2026-01-01', d), n);
          expect(i, inInclusiveRange(0, n - 1));
        }
      }
    });

    test('days a year apart or a day apart do not land on neighbours', () {
      final idx = [
        for (var d = 0; d < 365; d++)
          dailyIndex('en', dailyShift('2026-01-01', d), 3000),
      ];
      // spread over the pool, not marching through it
      expect(idx.toSet().length, greaterThan(300));
      final steps = [
        for (var i = 1; i < idx.length; i++) (idx[i] - idx[i - 1]).abs(),
      ];
      expect(steps.where((s) => s <= 1).length, lessThan(10));
      expect(idx.reduce(min), lessThan(150));
      expect(idx.reduce(max), greaterThan(2850));
    });

    test('no word comes back within 90 days, whenever the app is opened', () {
      const start = '2026-10-26';
      final idx = [
        for (var d = 0; d < 1500; d++)
          dailyIndex('en', dailyShift(start, d), 3000),
      ];
      for (var i = 0; i < idx.length; i++) {
        for (var j = i + 1; j < idx.length && j < i + dailyNoRepeat; j++) {
          expect(idx[j], isNot(idx[i]), reason: 'days $i and $j');
        }
      }
      // a device opened for the first time on a late day gets the same word
      expect(dailyIndex('en', dailyShift(start, 1200), 3000), idx[1200]);
      expect(dailyIndex('en', dailyShift(start, 7), 3000), idx[7]);
    });

    test('a short list still never repeats inside the window', () {
      final idx = [
        for (var d = 0; d < 300; d++)
          dailyIndex('xx', dailyShift('2026-10-26', d), 100),
      ];
      for (var i = 0; i + 1 < idx.length; i++) {
        for (var j = i + 1; j < idx.length && j < i + dailyNoRepeat; j++) {
          expect(idx[j], isNot(idx[i]));
        }
      }
    });

    test('the languages get different words on one day', () {
      final idx = {
        for (final l in ['en', 'fr', 'de', 'es', 'it', 'nl', 'pl', 'sv'])
          dailyIndex(l, '2026-10-24', 3000),
      };
      expect(idx.length, greaterThan(5));
    });

    testWidgets('the daily word is one word of the pool, the same every call', (
      tester,
    ) async {
      final bank = await _bank(tester, 'fr');
      final a = Daily.of(bank, '2026-10-24')!;
      final b = Daily.of(bank, '2026-10-24')!;
      expect(a.answer, b.answer);
      expect(a.date, '2026-10-24');
      expect(a.answer.length, dailyLength);
      expect(bank.answers(dailyLength).take(dailyAnswers), contains(a.answer));
      final others = {
        for (var d = 0; d < 20; d++)
          Daily.of(bank, dailyShift('2026-10-24', d))!.answer,
      };
      expect(others.length, greaterThan(15));
    });

    testWidgets('every language has a daily, even the ones with a short list', (
      tester,
    ) async {
      final langs = (await tester.runAsync(WordBank.languages))!;
      for (final l in langs) {
        final bank = (await tester.runAsync(() => WordBank.load(l)))!;
        final d = Daily.of(bank, '2026-10-24');
        expect(d, isNotNull, reason: l.code);
        expect(bank.valid, contains(d!.answer), reason: l.code);
      }
    });
  });

  group('the streak', () {
    test('counts the days in a row up to today', () {
      final log = {
        '2026-10-21': dailySolved,
        '2026-10-22': dailyDouble,
        '2026-10-23': dailySolved,
        '2026-10-24': dailySolved,
      };
      expect(dailyStreakOf(log, '2026-10-24'), 4);
    });

    test('a day not played yet does not break it, a day missed does', () {
      final log = {'2026-10-22': dailySolved, '2026-10-23': dailySolved};
      expect(dailyStreakOf(log, '2026-10-24'), 2); // today still to play
      log['2026-10-24'] = dailyMissed;
      expect(dailyStreakOf(log, '2026-10-24'), 0);
    });

    test('a gap ends it, and an empty log has none', () {
      final log = {
        '2026-10-20': dailySolved,
        '2026-10-21': dailySolved,
        '2026-10-23': dailySolved,
        '2026-10-24': dailySolved,
      };
      expect(dailyStreakOf(log, '2026-10-24'), 2);
      expect(dailyStreakOf({}, '2026-10-24'), 0);
      expect(dailyStreakOf(log, '2026-10-26'), 0, reason: 'two days unplayed');
    });
  });

  group('the double fire', () {
    test('three guesses or fewer', () {
      expect(dailyResult(used: 3).isDouble, isTrue);
      expect(dailyResult(used: 1).isDouble, isTrue);
      expect(dailyResult(used: 4).isDouble, isFalse);
    });

    test('every guess at 80 skill or more, however many', () {
      expect(
        dailyResult(used: 5, skills: const [80, 90, 100, 85, 80]).isDouble,
        isTrue,
      );
      expect(
        dailyResult(used: 5, skills: const [80, 79.9, 100, 85, 80]).isDouble,
        isFalse,
      );
      expect(dailyResult(used: 5, skills: const []).isDouble, isFalse);
    });

    test('a loss is never a fire, however sharp', () {
      final lost = dailyResult(won: false, used: 6, skills: const [99, 99]);
      expect(lost.isDouble, isFalse);
      expect(lost.dailyTier, dailyMissed);
      expect(dailyResult(used: 4).dailyTier, dailySolved);
      expect(dailyResult(used: 2).dailyTier, dailyDouble);
    });
  });

  group('the achievements', () {
    Achievement byId(String id) => achievements.firstWhere((a) => a.id == id);

    test('there is a classic streak ladder, each level earned once', () {
      expect(byId('daily_streak').levels.map((l) => l.target), [
        3,
        14,
        60,
        365,
      ]);
      expect(byId('daily_streak').separate, isTrue);
      final states = <String, AchState>{};
      final earned = <String>[];
      for (var day = 1; day <= 15; day++) {
        earned.addAll([
          for (final a in advanceAchievements(
            states,
            dailyResult(streak: day),
            'd$day',
          ))
            a.id,
        ]);
      }
      expect(earned.where((id) => id == 'daily_streak'), hasLength(2));
      expect(states['daily_streak']!.times, 2);
      expect(states['daily_streak']!.value, 15);
    });

    test('a streak earned once is not earned again', () {
      final states = <String, AchState>{};
      advanceAchievements(states, dailyResult(streak: 3), 'a');
      advanceAchievements(states, dailyResult(streak: 4), 'b');
      // a miss and a fresh run to 3
      advanceAchievements(states, dailyResult(won: false, streak: 0), 'c');
      expect(states['daily_streak']!.value, 4, reason: 'the best is kept');
      final again = advanceAchievements(states, dailyResult(streak: 3), 'd');
      expect(again.map((a) => a.id), isNot(contains('daily_streak')));
      expect(states['daily_streak']!.times, 1);
    });

    test('an ordinary game does not touch the daily streak', () {
      final states = <String, AchState>{};
      final plain = GameResult(
        lang: 'en',
        length: 5,
        tries: 6,
        used: 2,
        won: true,
        pool: 3000,
        skills: const [90, 90],
        dailyStreak: 50,
      );
      final earned = advanceAchievements(states, plain, 'x');
      expect(earned.map((a) => a.id), isNot(contains('daily_streak')));
      expect(states['daily_streak']?.value ?? 0, 0);
      expect(earned.map((a) => a.id), isNot(contains('double_fire')));
    });

    test('a double fire is earned by a daily, and counted up the ladder', () {
      final states = <String, AchState>{};
      final first = advanceAchievements(
        states,
        dailyResult(used: 2, streak: 1),
        'a',
      );
      expect(first.map((a) => a.id), contains('double_fire'));
      expect(byId('double_fire').numbered, isTrue);
      for (var i = 0; i < 9; i++) {
        advanceAchievements(states, dailyResult(used: 2, streak: 2), 'b$i');
      }
      expect(states['double_fire']!.times, 2);
      final plain = advanceAchievements(
        states,
        dailyResult(used: 5, streak: 3),
        'c',
      );
      expect(plain.map((a) => a.id), isNot(contains('double_fire')));
      expect(states['double_fire']!.value, 10);
    });
  });

  group('the saved log', () {
    test('records days, keeps the best, and survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.recordDaily('2026-10-22', dailySolved), 1);
      expect(s.recordDaily('2026-10-23', dailyDouble), 2);
      expect(s.recordDaily('2026-10-24', dailySolved), 3);
      expect(s.dailyBest, 3);
      // a miss in another language the same day cannot undo a solve
      expect(s.recordDaily('2026-10-24', dailyMissed), 3);
      expect(s.dailyLog['2026-10-24'], dailySolved);

      final again = AppState();
      await again.load();
      expect(again.dailyLog, s.dailyLog);
      expect(again.dailyBest, 3);
    });

    test('forgets days more than a year back, keeps the best', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.recordDaily('2025-01-01', dailySolved);
      s.recordDaily('2026-10-24', dailySolved);
      expect(s.dailyLog.keys, ['2026-10-24']);
      expect(s.dailyBest, 1);
    });

    test(
      'a damaged log is ignored, and does not stop the rest loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'dailyLog': 'not json',
          'daily': '{"x": 5}',
          'lang': 'fr',
        });
        final s = AppState();
        await s.load();
        expect(s.lang, 'fr');
        expect(s.dailyLog, isEmpty);
        expect(s.daily, isEmpty);
      },
    );

    test('progress on a daily keeps a week and no more', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.saveDaily('en', '2026-10-10', ['crane']);
      s.saveDaily('en', '2026-10-24', ['crane', 'slate'], won: true);
      expect(s.dailyFor('en', '2026-10-10'), isNull);
      final e = s.dailyFor('en', '2026-10-24')!;
      expect(e.guesses, ['crane', 'slate']);
      expect(e.won, isTrue);
      expect(e.over, isTrue);
      expect(s.dailyFor('fr', '2026-10-24'), isNull);
    });
  });

  group('playing the daily', () {
    testWidgets('fixed difficulty, solve it, and it stays solved', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      // the settings say something else; the daily ignores them
      appState.setup(lang: 'fr', length: 7, tries: 3);
      dailyClock = () => DateTime(2026, 10, 24, 12);
      final bank = await _bank(tester, 'fr');
      final daily = Daily.of(bank)!;
      expect(daily.date, '2026-10-24');

      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(bank: bank, daily: daily),
            onGenerateRoute: onGenerateRoute,
          ),
        );
        await tester.pump();
      }

      await open();
      expect(find.text('6 tries left'), findsOneWidget);
      expect(find.textContaining('2026-10-24'), findsOneWidget);

      // a wrong word first, then the answer
      final wrong = bank
          .answers(dailyLength)
          .take(dailyAnswers)
          .firstWhere((w) => w != daily.answer);
      for (final w in [wrong, daily.answer]) {
        for (final ch in w.split('')) {
          await tester.sendKeyEvent(_key(ch), character: ch);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('solved in 2 of 6'), findsOneWidget);
      expect(
        find.text('replay'),
        findsNothing,
        reason: 'a daily is played once',
      );
      expect(
        find.textContaining('the next word comes at midnight, your time'),
        findsOneWidget,
      );
      // the answer is said as the answer, not left bare
      expect(find.text('the word was ${daily.answer}'), findsOneWidget);

      // two guesses is a double fire, and the day is logged
      expect(appState.dailyLog['2026-10-24'], dailyDouble);
      expect(appState.dailyStreak, greaterThanOrEqualTo(1));
      final entry = appState.dailyFor('fr', '2026-10-24')!;
      expect(entry.guesses, [wrong, daily.answer]);
      expect(entry.won, isTrue);
      final played = appState.stats.played;

      // leaving and coming back shows the finished game, recorded only once
      await tester.pumpWidget(const SizedBox());
      await open();
      await tester.pumpAndSettle();
      expect(find.text('solved in 2 of 6'), findsOneWidget);
      expect(appState.stats.played, played);
      expect(find.text('replay'), findsNothing);
    });

    testWidgets('a half-played daily resumes where it was left', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'fr');
      dailyClock = () => DateTime(2026, 10, 24, 12);
      final bank = await _bank(tester, 'fr');
      final daily = Daily.of(bank)!;
      final wrong = bank
          .answers(dailyLength)
          .take(dailyAnswers)
          .firstWhere((w) => w != daily.answer);
      appState.saveDaily('fr', daily.date, [wrong]);

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, daily: daily),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.textContaining('5 tries left'), findsOneWidget);
    });

    testWidgets('a damaged save is ignored rather than breaking the game', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'fr');
      final bank = await _bank(tester, 'fr');
      final daily = Daily.of(bank, '2026-10-24')!;
      appState.saveDaily('fr', '2026-10-24', ['zz', 'qqqqq', daily.answer]);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, daily: daily),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.text('6 tries left'), findsOneWidget);
    });

    testWidgets('home shows the daily state on its button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'fr', length: 5);
      dailyClock = () => DateTime(2026, 10, 24, 12);
      appState.saveDaily('fr', '2026-10-24', ['crane']);
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
      expect(find.text('daily'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);

      appState.saveDaily('fr', '2026-10-24', ['crane', 'slate'], won: true);
      await tester.pumpAndSettle();
      expect(find.text('daily'), findsOneWidget);
      expect(find.text('solved in 2'), findsOneWidget);

      appState.saveDaily(
        'fr',
        '2026-10-24',
        List.filled(6, 'crane'),
        won: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('daily'), findsOneWidget);
      expect(find.text('missed'), findsOneWidget);
    });
  });

  testWidgets('the streak card sits below the language and above play', (
    tester,
  ) async {
    // (the cards carry no header text, so they are found by what they are)
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 5);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    final language = tester
        .getTopLeft(find.byKey(const ValueKey('language-button')))
        .dy;
    final card = tester
        .getTopLeft(find.byKey(const ValueKey('daily-streak')))
        .dy;
    final play = tester
        .getTopLeft(find.widgetWithText(FilledButton, 'play'))
        .dy;
    expect(language, lessThan(card));
    expect(card, lessThan(play));
    // and no header text over the cards
    for (final header in ['language', 'letters']) {
      expect(find.text(header), findsNothing, reason: header);
    }
    expect(find.textContaining('tries across'), findsNothing);
  });

  testWidgets('the streak card follows the daily while the home page is open', (
    tester,
  ) async {
    // the home page builds the card as a const, which Flutter does not rebuild
    // with the page: the card must listen for itself, or a daily finished in
    // front of it leaves it showing the old streak
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    dailyClock = () => DateTime(2026, 10, 24, 9);
    appState.dailyLog = {};
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    String streak() =>
        tester.widget<Text>(find.byKey(const ValueKey('streak-count'))).data!;
    expect(streak(), '0');
    expect(find.byKey(const ValueKey('flame-2026-10-24-1')), findsNothing);

    appState.recordDaily('2026-10-24', dailyDouble);
    await tester.pumpAndSettle();
    expect(streak(), '1');
    expect(
      find.byKey(const ValueKey('flame-2026-10-24-1')),
      findsOneWidget,
      reason: 'a double fire shows two flames',
    );
  });

  group('the home streak', () {
    Future<void> show(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: const ColorScheme.light()),
          home: const Scaffold(body: Center(child: DailyStreak())),
        ),
      );
    }

    testWidgets(
      'shows the streak and the last seven days, double fires doubled',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await appState.load();
        dailyClock = () => DateTime(2026, 10, 24, 9); // a Saturday
        appState.dailyLog = {
          '2026-10-19': dailySolved, // the day after the week's first
          '2026-10-20': dailyDouble,
          '2026-10-21': dailySolved,
          '2026-10-22': dailyMissed,
          '2026-10-23': dailySolved,
          '2026-10-24': dailyDouble,
        };
        await show(tester);
        expect(find.byKey(const ValueKey('daily-streak')), findsOneWidget);
        // 23rd and 24th solved, the 22nd missed
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('streak-count'))).data,
          '2',
        );
        // a rolling week: the seven days up to today, today last, none after it
        for (final d in ['18', '19', '20', '21', '22', '23', '24']) {
          expect(
            find.byKey(ValueKey('daily-day-2026-10-$d')),
            findsOneWidget,
            reason: d,
          );
        }
        expect(
          find.byKey(const ValueKey('daily-day-2026-10-25')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('daily-day-2026-10-17')),
          findsNothing,
        );
        final lefts = [
          for (final d in ['18', '19', '20', '21', '22', '23', '24'])
            tester.getTopLeft(find.byKey(ValueKey('daily-day-2026-10-$d'))).dx,
        ];
        expect(
          lefts,
          orderedEquals([...lefts]..sort()),
          reason: 'oldest first',
        );
        // each day is headed by the letter of its weekday: s m t w t f s
        String letterOf(String d) => tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(ValueKey('daily-day-2026-10-$d')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(
          [
            for (final d in ['18', '19', '20', '21', '22', '23', '24'])
              letterOf(d),
          ],
          ['s', 'm', 't', 'w', 't', 'f', 's'],
        );
        // one flame a day, two on a double fire (the 20th and the 24th)
        for (final d in ['18', '19', '21', '22', '23']) {
          expect(find.byKey(ValueKey('flame-2026-10-$d-0')), findsOneWidget);
          expect(find.byKey(ValueKey('flame-2026-10-$d-1')), findsNothing);
        }
        for (final d in ['20', '24']) {
          expect(find.byKey(ValueKey('flame-2026-10-$d-0')), findsOneWidget);
          expect(find.byKey(ValueKey('flame-2026-10-$d-1')), findsOneWidget);
        }
        expect(
          find.bySemanticsLabel('2026-10-24: double fire'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('2026-10-22: missed'), findsOneWidget);
        expect(find.bySemanticsLabel('2026-10-18: not played'), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets('the next day the week moves on, and the oldest drops off', (
      tester,
    ) async {
      await appState.load();
      appState.dailyLog = {
        '2026-10-18': dailySolved,
        '2026-10-24': dailySolved,
      };
      dailyClock = () => DateTime(2026, 10, 24, 9);
      await show(tester);
      expect(
        find.byKey(const ValueKey('daily-day-2026-10-18')),
        findsOneWidget,
      );
      dailyClock = () => DateTime(2026, 10, 25, 9);
      appState.refresh(); // what coming back to the app does
      await tester.pump();
      expect(find.byKey(const ValueKey('daily-day-2026-10-18')), findsNothing);
      expect(
        find.byKey(const ValueKey('daily-day-2026-10-25')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-day-2026-10-24')),
        findsOneWidget,
      );
    });

    testWidgets('no history is a streak of 0 and an unlit week', (
      tester,
    ) async {
      await appState.load();
      dailyClock = () => DateTime(2026, 10, 24, 9);
      appState.dailyLog = {};
      await show(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('streak-count'))).data,
        '0',
      );
      expect(find.byKey(const ValueKey('flame-2026-10-24-1')), findsNothing);
    });
  });
}
