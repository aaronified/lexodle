import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/guess_input.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/swipe_clear.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('GuessInput.clearTyped', () {
    test('erases every letter and the player\'s locks, not the game\'s', () {
      final g = GuessInput(5);
      g.lockFixed([(0, 's')]);
      for (final ch in 'lat'.split('')) {
        g.type(ch, {'l', 'a', 't'});
      }
      g.select(2);
      g.toggleLock(2);
      expect(g.clearTyped(), isTrue);
      expect(g.slot(0), 's', reason: 'the game\'s lock stays');
      for (var i = 1; i < 5; i++) {
        expect(g.slot(i), '');
        expect(g.isLocked(i), isFalse);
      }
      expect(g.cursor, 1);
      expect(g.clearTyped(), isFalse, reason: 'nothing left to erase');
    });
  });

  test('a swipe counts when it is far or fast, and to the left', () {
    expect(SwipeClear.counts(-80, 0), isTrue);
    expect(SwipeClear.counts(-30, -900), isTrue);
    expect(SwipeClear.counts(-30, -100), isFalse);
    expect(SwipeClear.counts(80, 900), isFalse);
    expect(SwipeClear.counts(-5, -2000), isFalse);
  });

  group('in a game', () {
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.classic,
            practice: true,
            daily: const Daily('', 'crane', length: 5, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
    }

    Future<void> type(WidgetTester tester, String w) async {
      for (final ch in w.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch,
        );
        await tester.pump();
      }
    }

    Finder letter(int i, String ch) => find.descendant(
      of: find.byKey(ValueKey('tile-0-$i')),
      matching: find.text(ch),
    );

    testWidgets('a swipe from right to left erases the row being typed', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cra');
      expect(letter(0, 'c'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('tile-0-2')),
        const Offset(-150, 0),
      );
      await tester.pump();
      for (final (i, ch) in [(0, 'c'), (1, 'r'), (2, 'a')]) {
        expect(letter(i, ch), findsNothing);
      }
    });

    testWidgets('a swipe to the right leaves it', (tester) async {
      await open(tester);
      await type(tester, 'cra');
      await tester.drag(
        find.byKey(const ValueKey('tile-0-2')),
        const Offset(150, 0),
      );
      await tester.pump();
      expect(letter(0, 'c'), findsOneWidget);
    });

    testWidgets('shift and backspace erase it; delete is backspace', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cra');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(letter(2, 'a'), findsNothing);
      expect(letter(1, 'r'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(letter(0, 'c'), findsNothing);
      expect(letter(1, 'r'), findsNothing);
    });
  });
}
