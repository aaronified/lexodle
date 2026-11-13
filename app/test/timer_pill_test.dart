import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pill = ValueKey('timer-pill');
  late WordBank bank;
  var now = Duration.zero;

  Future<void> open(
    WidgetTester tester, {
    GameMode mode = GameMode.classic,
    bool practice = false,
    bool lex = true,
  }) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3, mode: mode);
    appState.lex.veteran = lex;
    appState.lex.balance = 100;
    now = Duration.zero;
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          key: UniqueKey(),
          bank: bank,
          random: Random(7),
          mode: mode,
          practice: practice,
          clock: () => now,
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  String shown(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: find.byKey(pill), matching: find.byType(Text)),
      )
      .data!;

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

  testWidgets('0:00 until the first key, then it counts', (tester) async {
    await open(tester);
    expect(find.byKey(pill), findsOneWidget);
    expect(shown(tester), '0:00');
    await wait(tester, 5);
    expect(shown(tester), '0:00');
    // a backspace of nothing does not start it
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await wait(tester, 5);
    expect(shown(tester), '0:00');
    await key(tester, 'a');
    await wait(tester, 7);
    expect(shown(tester), '0:07');
    await wait(tester, 60);
    expect(shown(tester), '1:07');
  });

  testWidgets('the timer is on the left, the hint pill on the right', (
    tester,
  ) async {
    await open(tester);
    final t = tester.getRect(find.byKey(pill));
    final h = tester.getRect(find.byType(HintBar));
    final kb = tester.getRect(find.byType(Scaffold));
    expect(t.left, lessThan(kb.center.dx));
    expect(t.right, lessThan(h.left + 1));
    expect(
      tester
          .getRect(
            find
                .descendant(
                  of: find.byType(HintBar),
                  matching: find.byType(Container),
                )
                .first,
          )
          .right,
      greaterThan(kb.center.dx),
    );
  });

  testWidgets('a game with no hint pill has the timer alone, on the left', (
    tester,
  ) async {
    for (final m in [GameMode.blind, GameMode.equations, GameMode.mastermind]) {
      await open(tester, mode: m);
      expect(find.byKey(pill), findsOneWidget, reason: m.name);
      expect(find.byType(HintBar), findsNothing, reason: m.name);
      expect(tester.getRect(find.byKey(pill)).left, lessThan(60));
    }
  });

  testWidgets('game over stops it and the history row keeps the time', (
    tester,
  ) async {
    await open(tester);
    final words = bank
        .guessable(4)
        .where((w) => w.runes.every((r) => r < 128))
        .take(3)
        .toList();
    await key(tester, words[0][0]);
    await wait(tester, 12);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    for (final w in words) {
      await guess(tester, w);
    }
    await tester.pumpAndSettle();
    expect(appState.history.games, hasLength(1));
    final ms = appState.history.games.single.ms;
    expect(ms, 12000);
    // the clock goes on; the time does not
    await wait(tester, 30);
    expect(appState.history.games.single.ms, 12000);
  });

  testWidgets('a saved game resumes with the time it had', (tester) async {
    await open(tester);
    await key(tester, 'a');
    await wait(tester, 9);
    await key(tester, 'b');
    const k = 'p|fr|classic|4|3';
    expect(appState.savedElapsedMs(k), 9000);
    // open it again: the time is back, and counts from the next key
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          key: UniqueKey(),
          bank: bank,
          random: Random(7),
          clock: () => now,
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    expect(shown(tester), '0:09');
    await wait(tester, 4);
    expect(shown(tester), '0:09');
    await key(tester, 'a');
    await wait(tester, 3);
    expect(shown(tester), '0:12');
  });
}
