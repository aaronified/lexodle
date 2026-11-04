import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/clue.dart';
import 'package:lexodle/clue_page.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  test(
    'exactly one of the four words fits every clue, in words and sums',
    () async {
      final langs = await WordBank.languages();
      final en = langs.firstWhere((l) => l.code == 'en');
      for (final (bank, length) in [
        (await WordBank.load(en), 5),
        (await Equations.load(en), 7),
      ]) {
        for (var seed = 0; seed < 20; seed++) {
          final q = buildClueQuestion(
            bank: bank,
            length: length,
            draw: Draw.equal,
            rng: Random(seed),
          )!;
          expect(q.options.toSet(), hasLength(4));
          final fitting = [
            for (final o in q.options)
              if (q.broken(o) == null) o,
          ];
          expect(fitting, [q.options[q.fit]], reason: '$length seed $seed');
        }
      }
    },
  );

  testWidgets('a round: a wrong pick says why, ten questions end in a result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: CluePage(bank: bank, seed: 5)));
    for (var n = 0; n < clueRoundLength; n++) {
      // the first option, right or wrong
      await tester.tap(find.byKey(const ValueKey('clue-option-0')));
      await tester.pump();
      expect(find.byKey(const ValueKey('clue-verdict')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clue-next')));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('clue-result')), findsOneWidget);
    // the round is kept in the learn log, for its mode
    expect(
      appState.learnLog.where(kind: LearnKind.clue, mode: GameMode.classic),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('clue-again')));
    await tester.pump();
    expect(find.byKey(const ValueKey('clue-option-0')), findsOneWidget);
  });

  testWidgets('the keys 1 to 4 choose, and enter goes on', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: CluePage(bank: bank, seed: 5)));
    // enter before choosing does nothing
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('clue-verdict')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.pump();
    expect(find.byKey(const ValueKey('clue-verdict')), findsOneWidget);
    // a second key does not change the choice
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '3');
    await tester.pump();
    expect(find.byKey(const ValueKey('clue-verdict')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('clue-verdict')), findsNothing);
    expect(find.textContaining('2 of 10'), findsOneWidget);
  });
}
