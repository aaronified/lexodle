import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/hint_pick.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/lex.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordBank bank;

  String key(GameMode m) => 'p|en|${m.name}|5|${triesFor(m, 8)}';

  Future<void> open(
    WidgetTester tester,
    GameMode mode, {
    int seed = 7,
    bool fresh = true,
  }) async {
    if (fresh) {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, tries: 8, mode: mode);
      appState.lex.veteran = true;
      appState.lex.balance = 100;
      appState.lex.freeHints = 1;
      bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: MultiGamePage(key: UniqueKey(), bank: bank, random: Random(seed)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  Future<void> hold(WidgetTester tester, HintKind k) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('hint-${k.name}'))),
    );
    await tester.pump();
    await tester.pump(holdDuration + const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
  }

  Future<void> buy(WidgetTester tester, HintKind k) async {
    await tester.tap(find.byType(HintBar));
    await tester.pump();
    await hold(tester, k);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('a hint bought on board 2 of a quartet is for that board only', (
    tester,
  ) async {
    await open(tester, GameMode.quartet);
    await tester.tap(find.byKey(const ValueKey('board-caption-1')));
    await tester.pump();
    await tester.tap(find.byType(HintBar));
    await tester.pump();
    expect(find.text('for board 2'), findsOneWidget);
    await hold(tester, HintKind.green);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final saved = appState.progressFor(key(GameMode.quartet))!;
    final hints = saved['hints'] as List;
    expect(hints, hasLength(1));
    expect((hints.single as Map)['b'], 1);
    final answers = (saved['a'] as List).cast<String>();
    final h = hintsFromJson(
      hints,
      boards: 4,
      length: 5,
      letters: bank.letters(5),
    ).single;
    expect(h.board, 1);
    expect(answers[1][h.pos], h.letter);
    expect(find.byType(HintMiniRow), findsOneWidget);
    expect(appState.freeHints, 0);
    // restoring the saved hints marks the game hinted, so it pays 0 lex
    expect(restoreHints([h], guesses: 0).hinted, isTrue);
    expect(restoreHints(const [], guesses: 0).hinted, isFalse);
  });

  testWidgets('a grey hint marks the keys of its board only', (tester) async {
    await open(tester, GameMode.quartet);
    await tester.tap(find.byKey(const ValueKey('board-caption-2')));
    await tester.pump();
    await buy(tester, HintKind.grey);
    final h = hintsFromJson(
      appState.progressFor(key(GameMode.quartet))!['hints'],
      boards: 4,
      length: 5,
      letters: bank.letters(5),
    ).single;
    expect(h.board, 2);
    final kb = tester.widget<LetterKeyboard>(find.byType(LetterKeyboard));
    expect(kb.quadMarks[h.letter]![2], isNotNull);
    expect(
      [
        for (final i in [0, 1, 3]) kb.quadMarks[h.letter]![i],
      ],
      [null, null, null],
    );
  });

  testWidgets('the relay tray names the word', (tester) async {
    await open(tester, GameMode.relay);
    await tester.tap(find.byType(HintBar));
    await tester.pump();
    expect(find.text('for word 1'), findsOneWidget);
    expect(find.byType(LetterKeyboard), findsNothing);
    expect(find.byType(HintHoldRow), findsNWidgets(3));
  });

  testWidgets('a resumed game keeps its hint and is not charged again', (
    tester,
  ) async {
    await open(tester, GameMode.relay);
    appState.lex.freeHints = 0;
    await buy(tester, HintKind.yellow);
    expect(appState.lexBalance, 100 - HintKind.yellow.price);
    final ledger = appState.lex.ledger.length;
    expect(find.byType(HintMiniRow), findsOneWidget);

    // leave and come back: the same words, the hint still there
    await open(tester, GameMode.relay, seed: 99, fresh: false);
    expect(find.byType(HintMiniRow), findsOneWidget);
    expect(appState.lexBalance, 100 - HintKind.yellow.price);
    expect(appState.lex.ledger.length, ledger);
    expect(appState.freeHints, 0);
  });

  testWidgets('an old saved game without the hints key loads', (tester) async {
    await open(tester, GameMode.quartet);
    final pick = bank.answers(5).take(4).toList();
    appState.saveProgress(key(GameMode.quartet), {
      'a': pick,
      'g': <String>[],
      'in': <String, dynamic>{},
    });
    await open(tester, GameMode.quartet, seed: 3, fresh: false);
    expect(find.byType(MultiGamePage), findsOneWidget);
    expect(find.byType(HintMiniRow), findsNothing);
    expect(find.byType(HintBar), findsOneWidget);
  });
}
