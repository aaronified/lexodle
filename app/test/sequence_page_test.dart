import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/sequence.dart';
import 'package:lexodle/sequence_page.dart';
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

  late WordBank bank;
  late List<String> good; // the "best found" the page is given
  late List<String> poor;

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    appState.setup(lang: 'fr', length: 4);
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    final all = bank.guessable(4);
    // a set with real information, and one with very little
    final law = bank.law(4, appState.draw);
    final bench = (await tester.runAsync(
      () async => greedySequence(
        SequenceJob(
          all.take(1500).toList(),
          all.take(150).toList(),
          all.take(2).toList(),
          law,
        ),
      ),
    ))!;
    good = bench;
    poor = [
      all[0],
      all[0].split('').reversed.join(),
      all[1],
    ].where(bank.valid.contains).toList();
    // three words that tell little: the most alike words there are
    poor = all.where((w) => w.startsWith(all[0][0])).take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: SequencePage(
          bank: bank,
          findBenchmark: (b) async =>
              scoreSequence(all, good, b.law(4, appState.draw)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String word) async {
    for (final ch in word.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  Future<void> play(WidgetTester tester, List<String> set) async {
    for (final w in set) {
      await type(tester, w);
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  String text(WidgetTester tester, String key) =>
      textOf(tester.widget<Text>(find.byKey(ValueKey(key))))!;

  testWidgets('three words give a score, with every number it is made of', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('sequence-result')), findsNothing);
    await play(tester, poor);
    expect(find.byKey(const ValueKey('sequence-result')), findsOneWidget);
    expect(text(tester, 'sequence-skill'), startsWith('skill '));
    // the information after each word, three numbers
    final bits = text(tester, 'sequence-bits');
    expect(RegExp(r'[\d.]+ → [\d.]+ → [\d.]+ bits').hasMatch(bits), isTrue);
    expect(
      text(tester, 'sequence-groups'),
      contains('groups: the biggest has'),
    );
    expect(text(tester, 'sequence-left'), contains('words left on average'));
    expect(text(tester, 'sequence-wins'), contains('by the fourth guess'));
    // and it is scored against the best found: the poor set is below it
    final skill = int.parse(
      RegExp(r'skill (\d+)').firstMatch(text(tester, 'sequence-skill'))![1]!,
    );
    expect(skill, lessThan(100));
  });

  testWidgets('the best found scores 100, is logged once, and earns', (
    tester,
  ) async {
    await open(tester);
    await play(tester, good);
    expect(
      text(tester, 'sequence-skill'),
      'skill 100 · as good as the best found',
    );
    final e = appState.learnLog.events.single;
    expect(e.kind, LearnKind.sequence);
    expect(e.questions, 1);
    expect(e.right, 1, reason: 'as good as the best found');
    expect(e.avgSkill, 100);
    expect(find.byKey(const ValueKey('earned-rows')), findsOneWidget);
    // the same three in another order are the same set: not counted twice
    await tester.ensureVisible(find.byKey(const ValueKey('sequence-again')));
    await tester.tap(find.byKey(const ValueKey('sequence-again')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sequence-result')), findsNothing);
    await play(tester, good.reversed.toList());
    expect(appState.learnLog.events, hasLength(1));
    // another set is another event
    await tester.ensureVisible(find.byKey(const ValueKey('sequence-again')));
    await tester.tap(find.byKey(const ValueKey('sequence-again')));
    await tester.pump();
    await play(tester, poor);
    expect(appState.learnLog.events, hasLength(2));
  });

  testWidgets('a word that is not in the list, or twice, is refused', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'aaaa');
    expect(find.text('not in the word list'), findsOneWidget);
    // clear it, then type a real word twice
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    }
    await type(tester, good[0]);
    expect(find.byKey(const ValueKey('sequence-word-0')), findsOneWidget);
    await type(tester, good[0]);
    expect(find.text('already in the set'), findsOneWidget);
  });

  testWidgets('the best found can be shown, with how it does', (tester) async {
    await open(tester);
    await play(tester, poor);
    expect(find.byKey(const ValueKey('sequence-best')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('sequence-show')));
    await tester.tap(find.byKey(const ValueKey('sequence-show')));
    await tester.pump();
    expect(text(tester, 'sequence-best'), good.join(' · '));
    expect(
      find.textContaining('found by a search, not proved'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('sequence-show')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sequence-best')), findsNothing);
  });

  testWidgets(
    'a word can be changed by tapping it, and the set is scored again',
    (tester) async {
      await open(tester);
      await play(tester, poor);
      final before = text(tester, 'sequence-skill');
      await tester.tap(find.byKey(const ValueKey('sequence-word-2')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sequence-result')),
        findsNothing,
        reason: 'being edited, the set is not scored',
      );
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      }
      await type(tester, good[0]);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('sequence-result')), findsOneWidget);
      expect(text(tester, 'sequence-skill'), isNot(before));
    },
  );
}
