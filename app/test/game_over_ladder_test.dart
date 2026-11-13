import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the game over panel shows at each step of the ladder: the game just
/// played counts, so a player with N-1 played sees the panel of step N.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  late WordBank bank;

  Future<void> type(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  /// Wins a game of the English five-letter words as game number [step].
  Future<void> won(
    WidgetTester tester, {
    required int step,
    bool veteran = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.lex.veteran = veteran;
    appState.setup(lang: 'en', length: 5, tries: 6, mode: GameMode.classic);
    appState.stats.played = step - 1;
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    final answer = chooseWord(
      bank.answers(5),
      bank.drawWeights(5, appState.draw),
      Random(7),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    await type(tester, answer);
    await tester.pumpAndSettle();
    expect(find.text('replay'), findsOneWidget);
  }

  Finder measure(String which) => find.byKey(ValueKey('measure-$which'));
  final medal = find.textContaining('  —  ');
  final bookmark = find.byKey(const ValueKey('save-word'));

  testWidgets('before skill, luck and risk, none of it is shown', (
    tester,
  ) async {
    await won(tester, step: 1);
    expect(measure('skill'), findsNothing);
    expect(measure('luck'), findsNothing);
    expect(measure('risk'), findsNothing);
    expect(find.text('review'), findsNothing);
  });

  testWidgets('at step 2 the basic form, with no review button', (
    tester,
  ) async {
    await won(tester, step: 2);
    for (final which in ['skill', 'luck', 'risk']) {
      expect(measure(which), findsOneWidget, reason: which);
    }
    expect(
      find.text('how close your guesses were to the best possible'),
      findsOneWidget,
    );
    expect(find.text('how much the answer helped or hurt you'), findsOneWidget);
    expect(
      find.text('how often you gambled instead of playing safe'),
      findsOneWidget,
    );
    expect(find.text('review'), findsNothing);
    // the maths is not one tap away
    await tester.tap(measure('skill'));
    await tester.pumpAndSettle();
    expect(find.text('the maths'), findsNothing);
  });

  testWidgets('the full analysis only once every mode is open', (tester) async {
    await won(tester, step: 2, veteran: true);
    expect(find.text('review'), findsOneWidget);
    await tester.ensureVisible(measure('risk'));
    await tester.tap(measure('risk'));
    await tester.pumpAndSettle();
    expect(find.text('the maths'), findsOneWidget);
  });

  testWidgets('no medals list before step 3', (tester) async {
    await won(tester, step: 2);
    expect(medal, findsNothing);
  });

  testWidgets('the medals list comes at step 3', (tester) async {
    await won(tester, step: 3);
    expect(medal, findsWidgets);
  });

  testWidgets('no bookmark before step 9', (tester) async {
    await won(tester, step: 8);
    expect(bookmark, findsNothing);
  });

  testWidgets('the save-word bookmark comes at step 9', (tester) async {
    await won(tester, step: 9);
    expect(bookmark, findsOneWidget);
  });

  testWidgets('a quartet at step 2 has skill and luck, and no risk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.lex.veteran = false;
    appState.setup(lang: 'en', length: 5, mode: GameMode.quartet, share: 10);
    appState.stats.played = 1;
    // the quartet is open at game 4: teach it early, as a card would
    appState.markTaught(GameMode.quartet);
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    final answers = chooseTargets(
      bank.answers(5),
      bank.drawWeights(5, appState.draw),
      4,
      10,
      Random(3),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiGamePage(bank: bank, random: Random(3)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    for (final w in answers) {
      await type(tester, w);
    }
    await tester.pumpAndSettle();
    expect(find.text('replay'), findsOneWidget);
    expect(measure('skill'), findsOneWidget);
    expect(measure('luck'), findsOneWidget);
    expect(measure('risk'), findsNothing);
  });
}
