import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/medal.dart';
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

  test('every achievement has an icon, and the file exists', () {
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
    await tester.binding.setSurfaceSize(const Size(420, 16000));
    appState.stats = Stats()
      ..mastery = {
        'en': {'5:6', '4:6', '5:3'},
      };
    appState.ach = {
      'quick': AchState(
        times: 3,
        dates: ['2026-10-01', '2026-10-05', '2026-10-09'],
        value: 2,
      ),
      'wins': AchState(
        times: 2,
        dates: ['2026-10-03', '2026-10-04'],
        value: 30,
      ),
      'played': AchState(
        times: 2,
        dates: ['2026-10-06', '2026-10-07'],
        value: 40,
      ),
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

    // one row for each achievement, with a glyph
    expect(find.byType(SvgPicture), findsAtLeastNWidgets(achievements.length));
    for (final a in achievements) {
      expect(find.byKey(ValueKey('${a.id}-row')), findsOneWidget, reason: a.id);
    }

    // the levels earned of the most, and the name of the level reached
    expect(find.byKey(const ValueKey('count-quick')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('count-quick'))).data,
      '3/4',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('name-quick'))).data,
      'two shot',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('name-wins'))).data,
      'regular',
    );
    // not started: the first name; and the next level is what it asks
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('name-luck'))).data,
      'lucky break',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('medal-wins'))).data,
      'gold',
      reason: 'the next level to earn',
    );

    // a counting one carries a bar of how far it is to the next level
    expect(find.text('40/250'), findsOneWidget);
    expect(find.text('30/25'), findsNothing);
    expect(find.text('30/100'), findsOneWidget);
    expect(find.byKey(const ValueKey('bar-fill')), findsAtLeastNWidgets(10));

    // a pip for each level, lit for those earned
    expect(find.byKey(const ValueKey('level-quick-2')), findsOneWidget);
    Color? pip(String id, int i) =>
        (tester
                    .widget<Container>(find.byKey(ValueKey('level-$id-$i')))
                    .decoration!
                as BoxDecoration)
            .color;
    expect(pip('quick', 2), isNotNull);
    expect(pip('quick', 3), isNull);

    // only the streaks show an icon for each level
    expect(
      find.byKey(const ValueKey('streak-icon-daily_streak-3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('streak-icon-wins-0')), findsNothing);

    // the medal chips count the levels earned of each
    expect(find.text('all 7/$levelCount'), findsOneWidget);
    expect(find.text('bronze 3/${achievements.length}'), findsOneWidget);
    expect(find.text('silver 3/${achievements.length}'), findsOneWidget);
    expect(find.text('gold 1/${achievements.length}'), findsOneWidget);

    // a tap lists every level, its name and what it asks
    await tester.tap(find.byKey(const ValueKey('wins-row')));
    await tester.pumpAndSettle();
    for (final n in ['first light', 'regular', 'veteran', 'dustwalker']) {
      expect(find.text(n), findsWidgets, reason: n);
    }
    expect(find.text('win 500 games'), findsOneWidget);
    expect(find.text('2026-10-03'), findsWidgets);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    // mastery lists the languages from its dialog
    await tester.tap(find.byKey(const ValueKey('language_mastery-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('language by language'));
    await tester.pumpAndSettle();
    expect(find.text('3/20'), findsOneWidget);
    expect(find.textContaining('languages mastered'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // the history table lists what was earned, how many levels, first and latest
    expect(find.text('history'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('2026-10-09'), findsWidgets);
  });

  testWidgets('a medal chip shows the achievements whose top level is it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 16000));
    appState.ach = {
      'quick': AchState(times: 3, dates: ['a', 'b', 'c']),
      'wins': AchState(times: 1, dates: ['a']),
    };
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementsPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('medal-filter-gold')));
    await tester.pump();
    expect(find.byKey(const ValueKey('quick-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('wins-row')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('medal-filter-all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wins-row')), findsOneWidget);
  });

  testWidgets('the history says so when nothing is earned yet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 16000));
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
      await tester.binding.setSurfaceSize(const Size(420, 16000));
      appState.lang = 'en';
      appState.stats = Stats()..langsWon = {'en', 'fr'};
      appState.setAch('en', {
        'quick': AchState(times: 3, dates: ['2026-10-01']),
      });
      appState.setAch('fr', {
        'wins': AchState(times: 1, dates: ['2026-10-03']),
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsPage(),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      // English: its fastest win, not French's wins
      expect(find.byKey(const ValueKey('count-quick')), findsOneWidget);
      expect(find.byKey(const ValueKey('count-wins')), findsNothing);
      // every achievement of the language wears its flag
      expect(find.byKey(const ValueKey('badges-quick')), findsOneWidget);
      expect(find.byKey(const ValueKey('badges-wins')), findsOneWidget);
      // the one that counts languages wears every flag won in: English draws two
      // (gb and us, each half), French one
      final shared = find.descendant(
        of: find.byKey(const ValueKey('badges-languages')),
        matching: find.byType(SvgPicture),
      );
      expect(shared, findsNWidgets(3));
      // picking French shows French's
      await tester.tap(find.byKey(const ValueKey('lang-fr')));
      await tester.pump();
      expect(find.byKey(const ValueKey('count-wins')), findsOneWidget);
      expect(find.byKey(const ValueKey('count-quick')), findsNothing);
      appState.lang = 'en';
    },
  );

  testWidgets('all languages: every flag, bright where earned, dim where not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 16000));
    appState.lang = 'en';
    appState.stats = Stats()..langsWon = {'en', 'fr'};
    appState.setAch('en', {
      'quick': AchState(times: 3, dates: ['2026-10-01', '2026-10-05']),
    });
    appState.setAch('fr', {
      'quick': AchState(times: 2, dates: ['2026-10-03']),
      'wins': AchState(times: 1, dates: ['2026-10-04']),
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
    // the furthest level of any language shows
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('count-quick'))).data,
      '3/4',
    );
    expect(find.textContaining('in any language'), findsOneWidget);
    double opacity(String id, String code) =>
        tester.widget<Opacity>(find.byKey(ValueKey('badge-$id-$code'))).opacity;
    // one shot was earned in both; regular only in French
    expect(opacity('quick', 'en'), 1);
    expect(opacity('quick', 'fr'), 1);
    expect(opacity('wins', 'fr'), 1);
    expect(opacity('wins', 'en'), lessThan(1));
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
        s.achOf(lang)[a.id] = AchState(
          times: a.count,
          dates: List.filled(a.count, '2026-10-01'),
        );
      }
    }

    test('the achievements that count languages do not stand in the way', () {
      expect(achievementById(completionistId)!.global, isTrue);
      expect(achievementById('completionist')!.global, isTrue);
      expect(achievementById('languages')!.levels[3].name, 'nine tongues');
      expect(
        achievementById('completionist')!.levels[3].name,
        'tower of babel',
      );
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
      expect(s.achOf('en')['completionist']!.times, 3, reason: '1, 3 and 6');
      finish(s, langs.last);
      final earned = s.recordGame(won(langs.last));
      expect(earned.map((a) => a.id), contains('completionist'));
      expect(s.achOf('en')['completionist']!.times, 4);
      expect(s.achOf('en')[completionistId]!.seen, langs.toSet());
      // once
      final more = s.recordGame(won(langs.last));
      expect(more.map((a) => a.id), isNot(contains('completionist')));
      expect(s.achOf('en')['completionist']!.times, 4);
    });
  });

  testWidgets('learn achievements wear the flags of the languages learned in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 16000));
    appState.learnLog = LearnLog([
      for (final l in ['fr', 'de'])
        LearnEvent(
          kind: LearnKind.choose,
          language: l,
          length: 5,
          date: '2026-11-01',
          questions: 10,
          right: 8,
          avgSkill: 80,
        ),
    ]);
    appState.ach = {
      'learn_rounds': AchState(times: 1, dates: ['2026-11-01'], value: 2),
    };
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementsPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.byKey(const ValueKey('name-learn_rounds')), findsOneWidget);
    expect(find.byKey(const ValueKey('count-learn_rounds')), findsOneWidget);
    // the languages learned in, not those won in (none were)
    expect(find.byKey(const ValueKey('badge-learn_rounds-fr')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-learn_rounds-de')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-learn_rounds-es')), findsNothing);
    // and every learn achievement is listed
    for (final a in achievements.where((a) => a.learn)) {
      expect(
        find.byKey(ValueKey('name-${a.id}')),
        findsOneWidget,
        reason: a.id,
      );
    }
    appState.learnLog = LearnLog();
  });
}
