import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.ach = {};
    appState.stats = Stats();
  });

  test('every achievement has its own icon, and the file exists', () {
    final icons = achievements.map((a) => a.icon).toList();
    expect(icons.toSet().length, icons.length, reason: 'icons must be unique');
    for (final a in achievements) {
      final f = File('assets/icons/${a.icon}.svg');
      expect(f.existsSync(), isTrue, reason: '${a.id}: ${a.icon}.svg');
      expect(
        f.readAsStringSync(),
        contains('icons-tabler-filled'),
        reason: '${a.id} must use a Tabler filled glyph',
      );
    }
  });

  testWidgets('the screen shows icons, counts, bars and the history table', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 7400));
    appState.stats = Stats()
      ..mastery = {
        'en': {'5:6', '4:6', '5:3'},
      };
    appState.ach = {
      'one_shot': AchState(
        times: 3,
        dates: ['2026-10-01', '2026-10-05', '2026-10-09'],
      ),
      'wins_10': AchState(times: 1, dates: ['2026-10-03'], progress: 4),
    };
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementsPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    // SVG assets are read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();

    // one glyph per achievement, plus the odd drawn flag in the mastery list
    expect(find.byType(SvgPicture), findsAtLeastNWidgets(achievements.length));

    // earned more than once: the count and the latest date
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);

    // numbered achievements carry a bar; the earned one restarted from 0 (4/10)
    final numbered = achievements.where((a) => a.numbered).length;
    // (the language mastery list has a bar of its own for every language)
    expect(
      find.byKey(const ValueKey('bar-fill')),
      findsAtLeastNWidgets(numbered),
    );
    expect(find.text('4/10'), findsOneWidget);
    // 100 wins, and the 100-day daily streak
    expect(find.text('0/100'), findsNWidgets(2));

    // language mastery is one achievement, not a list: no badge earned yet
    expect(find.text('language mastery'), findsOneWidget);
    expect(find.byKey(const ValueKey('mastery-row')), findsOneWidget);
    // the mastery badges and the completionist's: neither has one yet
    expect(find.text('no badges yet'), findsNWidgets(2));
    expect(find.text('3/20'), findsNothing, reason: 'the list is on its page');

    // tapping it opens the language by language list: 3 of English's
    // settings, 4 tries levels at each of its 5 lengths (4 to 8) = 20
    await tester.tap(find.byKey(const ValueKey('mastery-row')));
    await tester.pumpAndSettle();
    expect(find.text('3/20'), findsOneWidget);
    expect(find.textContaining('languages mastered'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // the history table lists what was earned, how often, first and latest
    expect(find.text('history'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget); // one shot, first
    expect(find.text('2026-10-09'), findsWidgets); // one shot, latest
    expect(find.text('3'), findsOneWidget); // one shot, times
  });

  testWidgets('the history says so when nothing is earned yet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 7400));
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementsPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.text('nothing earned yet.'), findsOneWidget);
  });

  testWidgets(
    'each language shows its own, with its flag; shared ones show theirs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 7400));
      appState.lang = 'en';
      appState.stats = Stats()..langsWon = {'en', 'fr'};
      appState.setAch('en', {
        'one_shot': AchState(times: 3, dates: ['2026-10-01']),
      });
      appState.setAch('fr', {
        'wins_10': AchState(times: 1, dates: ['2026-10-03']),
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsPage(),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      // English: the one shot, not "regular"
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('×1'), findsNothing);
      // every achievement of the language wears its flag
      expect(find.byKey(const ValueKey('badges-one_shot')), findsOneWidget);
      expect(find.byKey(const ValueKey('badges-wins_10')), findsOneWidget);
      // the one that counts languages wears every flag won in: English draws two
      // (gb and us, each half), French one
      final shared = find.descendant(
        of: find.byKey(const ValueKey('badges-bilingual')),
        matching: find.byType(SvgPicture),
      );
      expect(shared, findsNWidgets(3));
      // picking French shows French's
      await tester.tap(find.byKey(const ValueKey('lang-fr')));
      await tester.pump();
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('×3'), findsNothing);
      appState.lang = 'en';
    },
  );

  testWidgets('all languages: every flag, bright where earned, dim where not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 7400));
    appState.lang = 'en';
    appState.stats = Stats()..langsWon = {'en', 'fr'};
    appState.setAch('en', {
      'one_shot': AchState(times: 3, dates: ['2026-10-01', '2026-10-05']),
    });
    appState.setAch('fr', {
      'one_shot': AchState(times: 2, dates: ['2026-10-03']),
      'wins_10': AchState(times: 1, dates: ['2026-10-04']),
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementsPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lang-all')));
    await tester.pump();
    // the times are added up across the languages
    expect(find.text('×5'), findsOneWidget);
    expect(find.textContaining('in any language'), findsOneWidget);
    double opacity(String id, String code) =>
        tester.widget<Opacity>(find.byKey(ValueKey('badge-$id-$code'))).opacity;
    // one shot was earned in both; regular only in French
    expect(opacity('one_shot', 'en'), 1);
    expect(opacity('one_shot', 'fr'), 1);
    expect(opacity('wins_10', 'fr'), 1);
    expect(opacity('wins_10', 'en'), lessThan(1));
    appState.lang = 'en';
  });

  group('completing a language', () {
    GameResult won(String lang) => GameResult(
      lang: lang,
      length: 5,
      tries: 6,
      used: 3,
      won: true,
      skills: const [90, 90, 90],
    );

    void finish(AppState s, String lang) {
      for (final a in achievements.where((a) => !a.global)) {
        s.achOf(lang)[a.id] = AchState(times: 1, dates: ['2026-10-01']);
      }
    }

    test('the achievements that count languages do not stand in the way', () {
      expect(achievementById(completionistId)!.global, isTrue);
      expect(achievementById(towerOfBabelId)!.global, isTrue);
      expect(achievementById('polyglot_9')!.title, 'nine tongues');
      expect(achievementById(towerOfBabelId)!.title, 'tower of babel');
    });

    test(
      'every achievement of a language earns its completionist badge',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = AppState();
        await s.load();
        expect(s.completedIn('en'), isFalse);
        s.recordGame(won('en'));
        expect(s.achOf('en')[completionistId]?.seen ?? {}, isEmpty);
        finish(s, 'en');
        expect(s.completedIn('en'), isTrue);
        expect(s.completedLanguages(), {'en'});
        final earned = s.recordGame(won('en'));
        expect(earned.map((a) => a.id), contains(completionistId));
        expect(s.achOf('en')[completionistId]!.seen, {'en'});
        // kept, and earned once for that language
        final again = s.recordGame(won('en'));
        expect(again.map((a) => a.id), isNot(contains(completionistId)));
        expect(s.achOf('en')[completionistId]!.times, 1);
      },
    );

    test('the tower of babel waits for every language', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      final langs = (await WordBank.languages()).map((l) => l.code).toList();
      expect(langs.length, greaterThan(2));
      for (final l in langs.take(langs.length - 1)) {
        finish(s, l);
        s.recordGame(won(l));
      }
      expect(s.achOf('en')[towerOfBabelId]?.times ?? 0, 0);
      finish(s, langs.last);
      final earned = s.recordGame(won(langs.last));
      expect(earned.map((a) => a.id), contains(towerOfBabelId));
      expect(s.achOf('en')[towerOfBabelId]!.times, 1);
      expect(s.achOf('en')[completionistId]!.seen, langs.toSet());
      // once
      final more = s.recordGame(won(langs.last));
      expect(more.map((a) => a.id), isNot(contains(towerOfBabelId)));
    });
  });
}
