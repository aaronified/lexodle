import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.learnLog = LearnLog();
    appState.achOf('').clear();
  });

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

  Future<void> guess(WidgetTester tester, String word) async {
    await type(tester, word);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 3));
  }

  String hintText(WidgetTester tester) => textOf(
    tester.widget<Text>(find.byKey(const ValueKey('learn-hint-text'))),
  )!;

  testWidgets('the hint ladder gives the letter, then the word, then why', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('learn-hint-text')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('learn-hint')));
    await tester.pump(const Duration(seconds: 3));
    expect(hintText(tester), startsWith('the best guess starts with '));
    final letter = hintText(tester).split(' ').last;
    await tester.tap(find.byKey(const ValueKey('learn-hint')));
    await tester.pump();
    expect(hintText(tester), startsWith('the best guess: '));
    expect(hintText(tester), isNot(contains('groups')));
    final word = hintText(tester).substring('the best guess: '.length);
    expect(word.startsWith(letter), isTrue);
    await tester.tap(find.byKey(const ValueKey('learn-hint')));
    await tester.pump();
    expect(hintText(tester), contains('groups, the biggest'));
    // the ladder ends there
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('learn-hint')))
          .onPressed,
      isNull,
    );
    // the word is the best one: guessing it grades 100
    final shown = hintText(tester).split(' ')[3].replaceAll('.', '');
    expect(shown, word);
    await tester.tap(find.byKey(const ValueKey('learn-hint-text')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 3));
    final fb = textOf(
      tester.widget<Text>(find.byKey(const ValueKey('learn-feedback-0'))),
    )!;
    expect(fb, startsWith('skill 100'));
    // a new position starts with no hint showing
    expect(find.byKey(const ValueKey('learn-hint-text')), findsNothing);
  });

  testWidgets('a guess explains itself, and a tap folds the explanation', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    await guess(tester, answer == 'mais' ? 'lien' : 'mais');
    expect(find.byKey(const ValueKey('learn-why-0')), findsOneWidget);
    expect(find.textContaining('your '), findsWidgets);
    // which habit of the playstyle the guess counts as, and its luck, explained
    expect(find.textContaining('style: '), findsOneWidget);
    expect(find.textContaining('not your choice'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-feedback-tap-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('learn-why-0')), findsNothing);
  });

  testWidgets('undo takes the last guess back, with its position', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    final fits = find.textContaining('words fit the clues so far');
    final before = textOf(tester.widget<Text>(fits))!;
    expect(find.byKey(const ValueKey('learn-undo')), findsNothing);
    await guess(tester, answer == 'mais' ? 'lien' : 'mais');
    expect(textOf(tester.widget<Text>(fits)), isNot(before));
    await tester.tap(find.byKey(const ValueKey('learn-undo')));
    await tester.pump();
    expect(textOf(tester.widget<Text>(fits)), before);
    expect(find.byKey(const ValueKey('learn-feedback-0')), findsNothing);
    expect(find.byKey(const ValueKey('learn-undo')), findsNothing);
    // the position is analysed again: a hint still works after the undo
    await tester.tap(find.byKey(const ValueKey('learn-hint')));
    await tester.pump(const Duration(seconds: 3));
    expect(hintText(tester), startsWith('the best guess starts with '));
  });

  testWidgets('undo after solving reopens the word', (tester) async {
    await open(tester);
    await guess(tester, answerOf(tester));
    expect(find.text('solved in 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-undo')));
    await tester.pump();
    expect(find.text('solved in 1'), findsNothing);
    expect(find.byKey(const ValueKey('learn-hint')), findsOneWidget);
  });

  testWidgets('a solved word is logged once, with its grades and hints', (
    tester,
  ) async {
    await open(tester);
    final answer = answerOf(tester);
    expect(appState.learnLog.isEmpty, isTrue);
    await tester.tap(find.byKey(const ValueKey('learn-hint')));
    await tester.pump(const Duration(seconds: 3));
    await guess(tester, answer == 'mais' ? 'lien' : 'mais');
    expect(appState.learnLog.isEmpty, isTrue, reason: 'not solved yet');
    await guess(tester, answer);
    final e = appState.learnLog.events.single;
    expect(e.kind, LearnKind.free);
    expect(e.language, 'fr');
    expect(e.length, 4);
    expect(e.questions, 2);
    expect(e.hints, 1);
    expect(e.right, inInclusiveRange(0, 2));
    expect(e.avgSkill, inInclusiveRange(0, 100));
    // taken back and solved again, it is the same word: not logged twice
    await tester.tap(find.byKey(const ValueKey('learn-undo')));
    await tester.pump();
    await guess(tester, answer);
    expect(appState.learnLog.events, hasLength(1));
  });
}
