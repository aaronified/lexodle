import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pill = ValueKey('timer-pill');
  late WordBank bank;
  var now = Duration.zero;

  Future<void> load(
    WidgetTester tester, {
    GameMode mode = GameMode.classic,
  }) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3, mode: mode);
    now = Duration.zero;
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
  }

  Future<void> show(
    WidgetTester tester, {
    Duration? limit,
    Draw? draw,
    bool multi = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: multi
            ? MultiGamePage(
                key: UniqueKey(),
                bank: bank,
                random: Random(7),
                clock: () => now,
                limit: limit,
                draw: draw,
              )
            : GamePage(
                key: UniqueKey(),
                bank: bank,
                random: Random(7),
                clock: () => now,
                limit: limit,
                draw: draw,
              ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  Text pillText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byKey(pill), matching: find.byType(Text)),
  );

  Future<void> wait(WidgetTester tester, int seconds) async {
    now += Duration(seconds: seconds);
    await tester.pump(Duration(seconds: seconds));
  }

  Future<void> key(WidgetTester tester, String ch) async {
    await tester.sendKeyEvent(
      LogicalKeyboardKey(ch.codeUnitAt(0)),
      character: ch,
    );
    await tester.pump();
  }

  Future<void> guess(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      await key(tester, ch);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  String wrong(WidgetTester tester) {
    final answer = (tester.state(find.byType(GamePage)) as dynamic).answer;
    return bank
        .guessable(4)
        .firstWhere((w) => w != answer && w.runes.every((r) => r < 128));
  }

  group('a game with a limit', () {
    testWidgets('the pill shows the time left and counts down', (tester) async {
      await load(tester);
      await show(tester, limit: const Duration(minutes: 1));
      expect(pillText(tester).data, '1:00');
      // it starts at the first key
      await wait(tester, 5);
      expect(pillText(tester).data, '1:00');
      await key(tester, 'a');
      await wait(tester, 7);
      expect(pillText(tester).data, '0:53');
      await wait(tester, 20);
      expect(pillText(tester).data, '0:33');
    });

    testWidgets('the last 10 seconds take the error colour', (tester) async {
      await load(tester);
      await show(tester, limit: const Duration(minutes: 1));
      final c = Theme.of(tester.element(find.byKey(pill))).colorScheme;
      await key(tester, 'a');
      await wait(tester, 49);
      expect(pillText(tester).data, '0:11');
      expect(pillText(tester).style!.color, isNull);
      await wait(tester, 1);
      expect(pillText(tester).data, '0:10');
      expect(pillText(tester).style!.color, heartColor(c));
      await wait(tester, 5);
      expect(pillText(tester).style!.color, heartColor(c));
    });

    testWidgets('reaching zero loses the game and records it once', (
      tester,
    ) async {
      await load(tester);
      await show(tester, limit: const Duration(minutes: 1));
      await guess(tester, wrong(tester));
      await key(tester, 'a');
      await wait(tester, 59);
      expect(find.text('time is up'), findsNothing);
      expect(find.byType(LetterKeyboard), findsOneWidget);
      await wait(tester, 2);
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsOneWidget);
      expect(find.byType(LetterKeyboard), findsNothing);
      final answer = (tester.state(find.byType(GamePage)) as dynamic).answer;
      expect(find.textContaining('the word was  $answer'), findsOneWidget);
      expect(appState.history.games, hasLength(1));
      final g = appState.history.games.single;
      expect(g.won, isFalse);
      expect(g.ms, 60000);
      await wait(tester, 120);
      expect(appState.history.games, hasLength(1));
    });

    testWidgets('a saved game past the limit opens over, recorded once', (
      tester,
    ) async {
      await load(tester);
      await show(tester, limit: const Duration(minutes: 5));
      await guess(tester, wrong(tester));
      await key(tester, 'a');
      await wait(tester, 20);
      await key(tester, 'b');
      expect(appState.history.games, isEmpty);
      await show(tester, limit: const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsOneWidget);
      expect(find.byType(LetterKeyboard), findsNothing);
      expect(appState.history.games, hasLength(1));
      expect(appState.history.games.single.ms, 15000);
      expect(appState.history.games.single.won, isFalse);
      // the save is gone: opening it again is a new game, not another loss
      await show(tester, limit: const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsNothing);
      expect(appState.history.games, hasLength(1));
    });

    testWidgets('a game with no limit is not cut short', (tester) async {
      await load(tester);
      await show(tester);
      await key(tester, 'a');
      await wait(tester, 3600);
      expect(find.text('time is up'), findsNothing);
      expect(find.byType(LetterKeyboard), findsOneWidget);
      expect(pillText(tester).data, '1:00:00');
      expect(pillText(tester).style!.color, isNull);
    });

    testWidgets('a quartet is lost the same way', (tester) async {
      await load(tester, mode: GameMode.quartet);
      await show(tester, limit: const Duration(minutes: 1), multi: true);
      expect(pillText(tester).data, '1:00');
      await key(tester, 'a');
      await wait(tester, 30);
      expect(pillText(tester).data, '0:30');
      expect(find.byType(LetterKeyboard), findsOneWidget);
      await wait(tester, 40);
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsOneWidget);
      expect(find.byType(LetterKeyboard), findsNothing);
      expect(appState.history.games, hasLength(1));
      expect(appState.history.games.single.won, isFalse);
      expect(appState.history.games.single.ms, 60000);
    });

    testWidgets('a quartet saved past the limit opens over', (tester) async {
      await load(tester, mode: GameMode.quartet);
      await show(tester, multi: true);
      await key(tester, 'a');
      await wait(tester, 20);
      await key(tester, 'b');
      await show(tester, limit: const Duration(seconds: 15), multi: true);
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsOneWidget);
      expect(appState.history.games, hasLength(1));
      expect(appState.history.games.single.ms, 15000);
    });
  });

  group('the draw of a made puzzle', () {
    testWidgets('reaches the weights of a single game', (tester) async {
      await load(tester);
      await show(tester, draw: Draw.frequency);
      expect(
        (tester.state(find.byType(GamePage)) as dynamic).draw,
        Draw.frequency,
      );
      await show(tester, draw: Draw.equal);
      expect((tester.state(find.byType(GamePage)) as dynamic).draw, Draw.equal);
      appState.setup(lang: 'fr', length: 4, tries: 3, mode: GameMode.classic);
      await show(tester);
      expect(
        (tester.state(find.byType(GamePage)) as dynamic).draw,
        appState.draw,
      );
    });

    testWidgets('reaches the weights of a quartet', (tester) async {
      await load(tester, mode: GameMode.quartet);
      await show(tester, draw: Draw.frequency, multi: true);
      expect(
        (tester.state(find.byType(MultiGamePage)) as dynamic).draw,
        Draw.frequency,
      );
      await show(tester, multi: true);
      expect(
        (tester.state(find.byType(MultiGamePage)) as dynamic).draw,
        appState.draw,
      );
    });
  });
}
