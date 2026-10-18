import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A player cannot know which words the answer is drawn from, so every real
/// word that fits the clues counts as possible, whatever the difficulty's pool.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  testWidgets(
    'caret, bingo, bread against break: bread is possible even at pool 500',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(
        lang: 'en',
        length: 5,
        tries: 6,
        pool: 500,
        mode: GameMode.classic,
      );
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      final pool = bank.answers(5, 500);
      expect(pool, contains('break'));
      expect(pool, isNot(contains('bread')), reason: 'outside the pool...');
      expect(bank.valid, contains('bread'), reason: '...but a real word');

      // a seed whose answer is break
      final weights = bank.answerWeights(5, 500);
      final seed = [for (var s = 0; s < 20000; s++) s]
          .firstWhere((s) => chooseWord(pool, weights, Random(s)) == 'break');

      // what is possible after the two guesses, worked out by brute force
      var left = bank.guessable(5);
      for (final g in ['caret', 'bingo']) {
        left = filterEligible(left, g, evaluate('break', g));
      }
      expect(left, containsAll(['break', 'bread']));
      expect(left.length, greaterThan(2));

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, random: Random(seed)),
        ),
      );
      await tester.pump();
      Future<void> type(String w) async {
        for (final ch in w.split('')) {
          await tester.sendKeyEvent(
            LogicalKeyboardKey(ch.codeUnitAt(0)),
            character: ch,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }

      expect(find.textContaining('possible words'), findsNothing);
      await type('caret');
      await type('bingo');
      // honest from the player's side: every word that fits is counted
      expect(
        find.text('${left.length} possible words · 4 tries left'),
        findsOneWidget,
      );
      expect(find.textContaining('1 possible word '), findsNothing);
    },
  );

  test(
    'the whole word list is in frequency order, for the pool to be a prefix',
    () async {
      final bank = await _bank('en');
      final all = bank.guessable(5);
      final w = bank.guessWeights(5);
      expect(w.length, all.length);
      for (var i = 1; i < w.length; i++) {
        expect(w[i], lessThanOrEqualTo(w[i - 1]), reason: 'row $i');
      }
      expect(bank.answers(5, 500), all.take(500).toList());
    },
  );
}

Future<WordBank> _bank(String code) async => WordBank.load(
  (await WordBank.languages()).firstWhere((l) => l.code == code),
);
