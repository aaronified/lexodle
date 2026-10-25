import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('solver narrows the words and recommends a guess', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4);
    // word files are read with real file IO, which fake-async cannot await
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    // recommend() yields to the event loop; advance the fake clock past it
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('recommended guess'), findsOneWidget);
    expect(find.textContaining('words on my list fit'), findsOneWidget);

    // a guess with every tile left grey rules out all words sharing its letters
    for (final ch in 'mais'.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));

    final undo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'undo last'),
    );
    expect(undo.onPressed, isNotNull); // the guess is in the history
    expect(find.text('recommended guess'), findsOneWidget);
  });

  testWidgets('solver uses the difficulty: its word list and its tries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    // the answer can be any word of the length
    final pool = bank.answers(4).length;
    expect(pool, bank.guessable(4).length);
    expect(find.textContaining('$pool words on my list fit'), findsOneWidget);
    expect(find.textContaining('answers from $pool words'), findsOneWidget);
    expect(find.textContaining('3 tries left'), findsOneWidget);
    expect(find.textContaining('· 3 tries'), findsWidgets); // the title

    for (final ch in 'mais'.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('2 tries left'), findsOneWidget);
  });

  for (final (tries, caption) in [
    (2, 'two tries left: the guess most likely to solve it in time'),
    (1, 'last try: the likeliest word that fits'),
    (6, 'recommended guess'),
  ]) {
    testWidgets('solver with $tries tries left advises for them', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      appState.setup(lang: 'fr', length: 4, tries: tries);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(caption), findsOneWidget);
      if (tries <= 2) {
        expect(find.textContaining('% to solve it'), findsOneWidget);
      } else {
        expect(find.textContaining('skill '), findsOneWidget);
      }
    });
  }
}
