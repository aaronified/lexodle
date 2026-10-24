import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
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
        'en': {'5:6:1500', '4:6:1500', '5:3:500'},
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
    expect(find.text('no badges yet'), findsOneWidget);
    expect(find.text('3/76'), findsNothing, reason: 'the list is on its page');

    // tapping it opens the language by language list: 3 of English's
    // 4 tries x 19 pools = 76 settings: English has the words for 3 pools at 4
    // letters, and all 4 at 5, 6, 7 and 8
    await tester.tap(find.byKey(const ValueKey('mastery-row')));
    await tester.pumpAndSettle();
    expect(find.text('3/76'), findsOneWidget);
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
      // the one that counts languages wears every flag won in
      final shared = find.descendant(
        of: find.byKey(const ValueKey('badges-bilingual')),
        matching: find.byType(SvgPicture),
      );
      expect(shared, findsNWidgets(2));
      // picking French shows French's
      await tester.tap(find.byKey(const ValueKey('lang-fr')));
      await tester.pump();
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('×3'), findsNothing);
      appState.lang = 'en';
    },
  );
}
