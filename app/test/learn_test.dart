import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<WordBank> bank(WidgetTester tester) async => (await tester.runAsync(
    () async => WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
    ),
  ))!;

  Future<void> type(WidgetTester tester, String word) async {
    for (final ch in word.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
  }

  String answerOf(WidgetTester tester) =>
      textOf(tester.widget<Text>(find.byKey(const ValueKey('learn-answer'))))!
          .replaceFirst('the answer: ', '');

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'fr', length: 4);
    final b = await bank(tester);
    await tester.pumpWidget(MaterialApp(home: LearnPage(bank: b, seed: 3)));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the answer and every word that fits, at the bottom', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    expect(answer.length, 4);
    expect(find.byKey(const ValueKey('learn-words')), findsOneWidget);
    expect(find.textContaining('words fit the clues so far'), findsOneWidget);
    // the list is below the board
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('learn-words'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('learn-answer'))).dy,
      ),
    );
  });

  testWidgets('a guess narrows the list, and is graded against the best', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    final before = find.textContaining('words fit the clues so far');
    final text0 = textOf(tester.widget<Text>(before))!;
    // a word that is not the answer
    final guess = answer == 'mais' ? 'lien' : 'mais';
    await type(tester, guess);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('learn-feedback-0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    final fb = textOf(
      tester.widget<Text>(find.byKey(const ValueKey('learn-feedback-0'))),
    )!;
    expect(fb, startsWith('skill '));
    final text1 = textOf(tester.widget<Text>(before))!;
    expect(text1, isNot(text0), reason: 'the list shrank');
    // the answer is still on the list
    expect(find.byKey(const ValueKey('learn-words')), findsOneWidget);
    expect(find.text('the answer: $answer'), findsOneWidget);
  });

  testWidgets('a word that is not in the list is refused', (tester) async {
    await open(tester);
    await type(tester, 'aaaa');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('not in the word list'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-feedback-0')), findsNothing);
  });

  testWidgets('guessing the answer finishes it, and another word starts over', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    await type(tester, answer);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('solved in 1'), findsOneWidget);
    expect(
      textOf(
        tester.widget<Text>(find.byKey(const ValueKey('learn-feedback-0'))),
      ),
      startsWith('skill '),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('learn-next')));
    await tester.tap(find.byKey(const ValueKey('learn-next')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('solved in 1'), findsNothing);
    expect(find.byKey(const ValueKey('learn-feedback-0')), findsNothing);
  });
}
