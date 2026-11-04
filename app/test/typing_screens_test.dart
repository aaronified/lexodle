import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/learn.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    appState.learnLog = LearnLog();
    appState.achOf('').clear();
  });

  group('the learn practice page takes what the game takes', () {
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      appState.setup(lang: 'fr', length: 4);
      final b = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      await tester.pumpWidget(MaterialApp(home: LearnPage(bank: b, seed: 3)));
      await tester.pump(const Duration(seconds: 1));
    }

    dynamic input(WidgetTester tester) =>
        (tester.state(find.byType(LearnPage)) as dynamic).input;

    Future<void> type(WidgetTester tester, String word) async {
      for (final ch in word.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch,
        );
        await tester.pump();
      }
    }

    String answer(WidgetTester tester) =>
        textOf(tester.widget<Text>(find.byKey(const ValueKey('learn-answer'))))!
            .replaceFirst('the answer: ', '');

    testWidgets('delete is backspace, shift and backspace clear the row', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cra');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      expect(input(tester).slot(2), '');
      expect(input(tester).slot(1), 'r');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        expect(input(tester).slot(i), '', reason: 'slot $i');
      }
    });

    testWidgets('a swipe from right to left clears the row', (tester) async {
      await open(tester);
      await type(tester, 'cra');
      await tester.drag(find.byType(MarkTile).at(2), const Offset(-150, 0));
      await tester.pump();
      expect(input(tester).slot(0), '');
    });

    testWidgets('a tap moves the cursor, a second tap locks the letter', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cr');
      await tester.tap(find.byType(MarkTile).at(0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(input(tester).cursor, 0);
      await tester.tap(find.byType(MarkTile).at(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(input(tester).isLocked(0), isTrue);
    });

    testWidgets('shift taps the lock, and a lock stays for the next guess', (
      tester,
    ) async {
      await open(tester);
      final word = answer(tester);
      // a guess that is not the answer: a word of the list
      final other = word == 'cela' ? 'dans' : 'cela';
      await type(tester, other);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // cursor to 3
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final at = input(tester).cursor as int;
      expect(input(tester).isLocked(at), isTrue);
    });

    testWidgets('the keys take the colours of the guesses', (tester) async {
      await open(tester);
      expect(
        tester.widget<LetterKeyboard>(find.byType(LetterKeyboard)).marks,
        isEmpty,
      );
      final word = answer(tester);
      final other = word == 'cela' ? 'dans' : 'cela';
      await type(tester, other);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        tester.widget<LetterKeyboard>(find.byType(LetterKeyboard)).marks,
        isNotEmpty,
      );
      // let the analysis of the position finish before the test ends
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a double tap on the guesses locks the greens', (tester) async {
      await open(tester);
      final word = answer(tester);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      // a word of the list that is not the answer and has a green against it
      int? at;
      final other = bank.guessable(4).firstWhere((w) {
        if (w == word) return false;
        for (var i = 0; i < 4; i++) {
          if (w[i] == word[i]) {
            at = i;
            return true;
          }
        }
        return false;
      });
      await type(tester, other);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final area = find.byKey(const ValueKey('greens-area'));
      expect(area, findsOneWidget);
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 100));
      expect(input(tester).isLocked(at!), isTrue);
      expect(find.text('all greens are locked'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
