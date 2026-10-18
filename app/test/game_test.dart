import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  testWidgets('home to play opens a game with the chosen tries', (
    tester,
  ) async {
    // tall: the home list builds lazily
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();

    expect(find.text('lexodle'), findsOneWidget);
    await tester.tap(find.text('play'));
    await tester.pumpAndSettle();
    // the word file is read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(find.text('3 tries left'), findsOneWidget);
  });

  testWidgets('lose a game, then review it step by step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3, pool: 500);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    // A seeded game, so the answer is known and the three guesses can all be
    // wrong; the game draws its answer from the same seed the same way.
    final answer = chooseWord(
      bank.answers(4, 500),
      bank.answerWeights(4, 500),
      Random(7),
    );
    final guesses = bank
        .answers(4, 500)
        .where((w) => w != answer)
        .take(3)
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
      ),
    );
    await tester.pump();
    expect(find.text('3 tries left'), findsOneWidget);

    for (final w in guesses) {
      for (final ch in w.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('replay'), findsOneWidget);
    expect(find.text('the word was  $answer'), findsOneWidget);

    // the end of a game offers a step-by-step review...
    expect(find.text('review'), findsOneWidget);
    expect(find.textContaining('average skill'), findsOneWidget);
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();
    expect(find.text('your first guess'), findsOneWidget);
    expect(find.text('the pool'), findsOneWidget);
    expect(find.text('my picks'), findsOneWidget);

    // ...where the helper has gone back over the step: picks and a reading
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('working it out…'), findsNothing);
    expect(find.text('you landed in'), findsOneWidget);

    // browse one by one: next, then back with the arrow key
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.text('your second guess'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('your first guess'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget); // the last of three guesses
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(appState.stats.played, greaterThanOrEqualTo(1));
  });
}

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));
