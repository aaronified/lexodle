import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.ach = {};
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
    await tester.binding.setSurfaceSize(const Size(420, 4200));
    appState.ach = {
      'one_shot': AchState(
        times: 3,
        dates: ['2026-10-01', '2026-10-05', '2026-10-09'],
      ),
      'wins_10': AchState(times: 1, dates: ['2026-10-03'], progress: 4),
    };
    await tester.pumpWidget(const MaterialApp(home: AchievementsPage()));
    // SVG assets are read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();

    expect(find.byType(SvgPicture), findsNWidgets(achievements.length));

    // earned more than once: the count and the latest date
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);

    // numbered achievements carry a bar; the earned one restarted from 0 (4/10)
    final numbered = achievements.where((a) => a.numbered).length;
    expect(find.byKey(const ValueKey('bar-fill')), findsNWidgets(numbered));
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);

    // the history table lists what was earned, how often, first and latest
    expect(find.text('history'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget); // one shot, first
    expect(find.text('2026-10-09'), findsWidgets); // one shot, latest
    expect(find.text('3'), findsOneWidget); // one shot, times
  });

  testWidgets('the history says so when nothing is earned yet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 4200));
    await tester.pumpWidget(const MaterialApp(home: AchievementsPage()));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.text('nothing earned yet.'), findsOneWidget);
  });
}
