import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lexodle/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill_page.dart';
import 'package:lexodle/learn.dart';
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

  testWidgets('every learn page is titled mode/learn/page for the tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await appState.load();
    final titles = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
          titles.add((call.arguments as Map)['label'] as String);
        }
        return null;
      },
    );
    for (final (mode, route, title) in [
      (GameMode.classic, Routes.learn, 'classic/learn'),
      (GameMode.equations, Routes.learn, 'equations/learn'),
      (GameMode.blind, Routes.learn, 'blind/learn'),
    ]) {
      appState.setup(
        lang: 'en',
        length: mode == GameMode.equations ? 6 : 5,
        mode: mode,
      );
      await tester.runAsync(() async {
        final langs = await WordBank.languages();
        final en = langs.firstWhere((l) => l.code == 'en');
        await WordBank.load(en);
        await Equations.load(en);
      });
      titles.clear();
      await tester.pumpWidget(
        MaterialApp(initialRoute: route, onGenerateRoute: onGenerateRoute),
      );
      for (var i = 0; i < 40 && !titles.contains(title); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(titles, contains(title), reason: route);
    }
    // a page of learn has its own: the guide, with its own address
    titles.clear();
    await tester.tap(find.byKey(const ValueKey('learn-card-guide')));
    await tester.pumpAndSettle();
    expect(titles, contains('blind/learn/guide'));
    expect(
      ModalRoute.of(tester.element(find.byKey(const ValueKey('mode-guide'))))!
          .settings
          .name,
      '/blind${Routes.learnGuide}',
    );
  });

  testWidgets('practise an equation opens on the equations', (tester) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await appState.load();
    appState.setup(lang: 'en', length: 7, mode: GameMode.equations);
    final bank = (await tester.runAsync(
      () async => Equations.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: LearnPage(bank: bank, seed: 2)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(LearnPage), findsOneWidget);
  });

  testWidgets('practise an equation, from learn, by its route', (tester) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await appState.load();
    appState.setup(
      lang: 'en',
      length: 5,
      mode: GameMode.equations,
      eqLength: 7,
    );
    await tester.runAsync(() async {
      final langs = await WordBank.languages();
      await Equations.load(langs.firstWhere((l) => l.code == 'en'));
    });
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: Routes.learn,
        onGenerateRoute: onGenerateRoute,
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('learn-card-free')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(LearnPage), findsOneWidget);
    // the number pad of the equations, as in the game
    expect(find.text('÷'), findsWidgets);
    expect(find.text('q'), findsNothing);
    // its address names the mode
    expect(
      ModalRoute.of(tester.element(find.byType(LearnPage)))!.settings.name,
      '/equations/learn/free',
    );
    // and back
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LearnPage), findsNothing);
  });

  test('a learn address with a mode opens that mode', () async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final routes = onGenerateInitialRoutes('/mastermind/learn/clue');
    expect(appState.mode, GameMode.mastermind);
    expect(routes.last.settings.name, '/mastermind/learn/clue');
    // the plain address is the mode in view
    final plain = onGenerateRoute(const RouteSettings(name: '/learn/free'));
    expect(plain.settings.name, '/mastermind/learn/free');
  });
}
