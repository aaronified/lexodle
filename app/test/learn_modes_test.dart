import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexodle/drill.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the drills build positions from the equations and from the places',
    () async {
      final out = await Future.wait([
        (() async {
          final langs = await WordBank.languages();
          final en = langs.firstWhere((l) => l.code == 'en');
          return (await Equations.load(en), 6);
        })(),
        (() async {
          final langs = await WordBank.languages();
          final en = langs.firstWhere((l) => l.code == 'en');
          final b = await Geography.load(en);
          return (b, Geography.counts.keys.first);
        })(),
      ]);
      for (final (bank, length) in out) {
        final q = await buildDrillQuestion(
          bank: bank,
          length: length,
          draw: Draw.equal,
          rng: Random(1),
          attempts: 200,
          minWords: 4,
        );
        expect(q, isNotNull, reason: '$length');
        expect(q!.options, hasLength(4));
        expect(q.eligible, contains(q.answer));
      }
    },
  );

  testWidgets('blind: the position shows counts, not tile colours', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.blind);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: DrillPage(bank: bank, seed: 3)));
    for (
      var i = 0;
      i < 300 && find.byKey(const ValueKey('drill-fits')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('drill-fits')), findsOneWidget);
    // two count tiles follow the five letters of every guess
    expect(find.byType(MarkTile).evaluate().length % 7, 0);
  });
}
