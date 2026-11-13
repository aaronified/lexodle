import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/hint_pick.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/lex.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hint_pick', () {
    const abc = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'r', 's', 't', 'o'};

    test('grey is never a letter of the answer or one already guessed', () {
      for (final guesses in [
        <String>[],
        ['crane'],
        ['crane', 'trove'],
      ]) {
        final p = pickGrey('shore', guesses, abc)!;
        expect(p.kind, HintKind.grey);
        expect('shore'.contains(p.letter), isFalse);
        expect(guesses.any((g) => g.contains(p.letter)), isFalse);
      }
    });

    test('grey is null when every letter is in or guessed', () {
      expect(pickGrey('abc', [], {'a', 'b', 'c'}), isNull);
    });

    test('yellow is a letter in the answer that is not green yet', () {
      final p = pickYellow('shore', ['sport'])!;
      // s and o... s is green; o is in the answer, not green
      expect('hore'.contains(p.letter), isTrue);
      expect(p.letter, isNot('s'));
      expect(pickYellow('shore', ['shore']), isNull);
    });

    test('yellow prefers a letter not yet guessed', () {
      // s, h, o, r are guessed; only e is fresh
      expect(pickYellow('shore', ['rosht'])!.letter, 'e');
    });

    test('green is a place that is not green yet, with its letter', () {
      final p = pickGreen('shore', ['sport'])!;
      expect(p.pos, isNot(0));
      expect(p.letter, 'shore'[p.pos]);
      expect(pickGreen('shore', ['shore']), isNull);
    });

    test('green skips the places an earlier hint gave', () {
      final first = pickGreen('abcd', ['abxx'])!;
      final second = pickGreen('abcd', ['abxx'], taken: [first])!;
      expect({first.pos, second.pos}, {2, 3});
      expect(pickGreen('abcd', ['abxx'], taken: [first, second]), isNull);
    });

    test('the pick is deterministic', () {
      final a = pickHint(HintKind.grey, 'shore', ['crane'], abc)!;
      final b = pickHint(HintKind.grey, 'shore', ['crane'], abc)!;
      expect(a.letter, b.letter);
    });
  });

  group('game screen', () {
    late WordBank bank;

    Future<void> open(WidgetTester tester, {bool unlocked = true}) async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'fr', length: 4, tries: 6, mode: GameMode.classic);
      appState.lex.veteran = unlocked;
      appState.lex.balance = 100;
      appState.lex.freeHints = 1;
      bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, random: Random(7)),
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

    testWidgets('the bar shows only once lex is unlocked', (tester) async {
      await open(tester, unlocked: false);
      expect(find.byType(HintBar), findsNothing);
    });

    testWidgets('the bar shows, and the tray swaps with the keyboard', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(HintBar), findsOneWidget);
      expect(find.byType(LetterKeyboard), findsOneWidget);
      await tester.tap(find.byType(HintBar));
      await tester.pump();
      expect(find.byType(LetterKeyboard), findsNothing);
      expect(find.byType(HintHoldRow), findsNWidgets(3));
      expect(
        find.text('a hint makes this game pay 0 lex. your streak is safe.'),
        findsOneWidget,
      );
      await tester.tap(find.text('back to the keyboard'));
      await tester.pump();
      expect(find.byType(LetterKeyboard), findsOneWidget);
      expect(find.byType(HintHoldRow), findsNothing);
    });

    testWidgets('a free hint goes first, and undo takes it back', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byType(HintBar));
      await tester.pump();
      await hold(tester, HintKind.yellow);
      expect(appState.freeHints, 0);
      expect(appState.lexBalance, 100);
      expect(find.byType(HintHoldRow), findsNothing);
      expect(find.byType(HintMiniRow), findsOneWidget);
      expect(find.text('free hint used'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('undo'));
      await tester.pump();
      expect(appState.freeHints, 1);
      expect(find.byType(HintMiniRow), findsNothing);
    });

    testWidgets('with no free hint it costs lex', (tester) async {
      await open(tester);
      appState.lex.freeHints = 0;
      await tester.tap(find.byType(HintBar));
      await tester.pump();
      await hold(tester, HintKind.grey);
      expect(appState.lexBalance, 100 - HintKind.grey.price);
      expect(find.text('hint bought · -10 lex'), findsOneWidget);
      expect(find.byType(HintMiniRow), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
