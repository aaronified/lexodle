import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/guess_input.dart';
import 'package:lexodle/keyboard.dart';
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

  test('a drag moves the cursor a tile for every few dozen pixels', () {
    expect(CursorDrag.tiles(10), 0);
    expect(CursorDrag.tiles(CursorDrag.step), 1);
    expect(CursorDrag.tiles(CursorDrag.step * 2.9), 2);
    expect(CursorDrag.tiles(-CursorDrag.step * 1.5), -1);
  });

  testWidgets('on the keyboard only the space key drags the cursor', (
    tester,
  ) async {
    final moves = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LetterKeyboard(
            letters: {...'abcdefghijklmnopqrstuvwxyz'.split('')},
            onLetter: (_) {},
            onEnter: () {},
            onBack: () {},
            onBlank: () {},
            onCursor: moves.add,
          ),
        ),
      ),
    );
    await tester.drag(find.text('q'), Offset(CursorDrag.step * 3, 0));
    await tester.pump();
    expect(moves, isEmpty, reason: 'a letter key does not move it');
    await tester.drag(find.text('_'), Offset(CursorDrag.step * 4, 0));
    await tester.pump();
    expect(moves.fold<int>(0, (a, b) => a + b), greaterThanOrEqualTo(3));
  });

  test('every screen with a space key lets it move the cursor', () {
    // a keyboard with a blank key and no cursor drag would be a gap
    for (final f in Directory('lib').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final m in RegExp(
        r'LetterKeyboard\(([\s\S]*?)\n\s*\),',
      ).allMatches(text)) {
        final body = m.group(1)!;
        if (body.contains('onBlank')) {
          expect(body, contains('onCursor'), reason: f.path);
        }
      }
    }
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

    testWidgets('a drag along the space key moves the cursor, a tap blanks', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cra');
      // the cursor is past the last tile: drag left two tiles, to the second
      await tester.drag(find.text('_'), Offset(-CursorDrag.step * 2.5, 0));
      await tester.pump();
      await tester.tap(find.text('x').last);
      await tester.pump();
      expect(letter(1, 'x'), findsOneWidget);
      expect(letter(0, 'c'), findsOneWidget);
      // typing x left the cursor on the next free tile (3); one tile to the
      // right of it is the last
      await tester.drag(find.text('_'), Offset(CursorDrag.step * 1.2, 0));
      await tester.pump();
      await tester.tap(find.text('z').last);
      await tester.pump();
      expect(letter(4, 'z'), findsOneWidget);
    });

    testWidgets('a tap on the space key still types a blank', (tester) async {
      await open(tester);
      await tester.tap(find.text('_'));
      await tester.pump();
      expect(letter(0, '_'), findsOneWidget);
    });

    testWidgets('a drag along the other keys does not move the cursor', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'cra');
      await tester.drag(find.text('q'), Offset(-CursorDrag.step * 2.5, 0));
      await tester.pump();
      await tester.tap(find.text('x').last);
      await tester.pump();
      // the cursor was past the last typed tile: x went to the first free one
      expect(letter(3, 'x'), findsOneWidget);
      expect(letter(1, 'x'), findsNothing);
    });
  });
}
