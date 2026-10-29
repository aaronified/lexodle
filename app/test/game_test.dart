import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
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

  testWidgets('a double tap locks a letter, which stays for the next guess', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    // a word that is not the answer, so the game goes on
    final word = bank
        .guessable(4)
        .firstWhere((w) => w.runes.every((r) => r < 128));
    for (final ch in word.split('')) {
      await tester.sendKeyEvent(_key(ch), character: ch);
    }
    const locked = ValueKey('locked');
    expect(find.byKey(locked), findsNothing);
    final tile = find.byKey(const ValueKey('tile-0-1'));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(tile);
    await tester.pump();
    expect(find.byKey(locked), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // the next row opens with the letter still locked in the same place
    expect(find.byKey(locked), findsOneWidget);
    final next = find.byKey(const ValueKey('tile-1-1'));
    expect(
      find.descendant(of: next, matching: find.text(word[1])),
      findsOneWidget,
    );
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(next);
    await tester.pump();
    expect(find.byKey(locked), findsNothing);
  });

  testWidgets('a blank can be typed but not submitted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();

    // the on-screen blank key is the only underscore before anything is typed
    await tester.tap(find.text('_'));
    await tester.pump();
    for (final ch in ['a', ' ', 'b']) {
      await tester.sendKeyEvent(
        ch == ' ' ? LogicalKeyboardKey.space : _key(ch),
        character: ch,
      );
    }
    // the row is _a_b: full, but with blanks, so it is not a guess yet
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('fill the blanks'), findsOneWidget);

    // editing the row clears the message; nothing was spent on the attempt
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.text('fill the blanks'), findsNothing);
    expect(find.text('3 tries left'), findsOneWidget);
  });

  testWidgets('the left and right arrows move the cursor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    // a word whose last two letters swapped is not a word, so a wrongly placed
    // letter cannot pass by luck
    final w = bank
        .answers(4)
        .firstWhere(
          (w) =>
              w[2] != w[3] &&
              !bank.valid.contains('${w.substring(0, 2)}${w[3]}${w[2]}'),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();

    Future<void> type(String s) async {
      for (final ch in s.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
    }

    // the last two letters typed the wrong way round, then put right with the
    // left arrow: from a full row it selects the last letter, and steps back
    await type('${w[0]}${w[1]}${w[3]}${w[2]}');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await type(w[2]); // replaces the third letter, and the row is full again
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await type(w[3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('not in the word list'), findsNothing);
    expect(find.text('need 4 letters'), findsNothing);
    // with a guess made the status line leads with the words left
    expect(
      find.textContaining('2 tries left'),
      findsOneWidget,
      reason: '$w was played',
    );

    // the right arrow skips a slot: the fourth letter goes in first, and the
    // cursor then wraps back to the one skipped
    await type(w.substring(0, 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await type(w[3]);
    await type(w[2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // the same word again, so it is refused, which proves it was complete and
    // in the right order
    expect(find.text('already guessed'), findsOneWidget);
  });

  testWidgets('lose a game, then review it step by step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    // A seeded game, so the answer is known and the three guesses can all be
    // wrong; the game draws its answer from the same seed the same way.
    final answer = chooseWord(
      bank.answers(4),
      bank.answerWeights(4),
      Random(7),
    );
    final guesses = bank.answers(4).where((w) => w != answer).take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute, // the review is opened by name
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
    expect(find.byKey(const ValueKey('pill-skill')), findsOneWidget);
    expect(find.text('best skill'), findsOneWidget);

    // ...where the helper has gone back over the step: picks and a reading
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('working it out…'), findsNothing);
    expect(find.text('top risk'), findsOneWidget);
    expect(find.text('luckiest'), findsOneWidget);
    expect(find.byKey(const ValueKey('gain-0')), findsOneWidget);

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
