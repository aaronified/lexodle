import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the modes', () {
    test(
      'the loop: themed last, blind after lockdown, equations before it',
      () {
        expect(GameMode.loopFor('en'), [
          GameMode.classic,
          GameMode.quartet,
          GameMode.relay,
          GameMode.lockdown,
          GameMode.blind,
          GameMode.equations,
          GameMode.themed,
        ]);
        expect(GameMode.loopFor('fr').last, GameMode.equations);
      },
    );

    test('saved modes keep their place: the new one comes after the old', () {
      expect(GameMode.classic.index, 0);
      expect(GameMode.themed.index, 4);
      expect(GameMode.blind.index, 5);
      expect(GameMode.equations.index, 6);
    });

    test('equations has a daily and no scores, themed has no daily', () {
      expect(GameMode.equations.hasDaily, isTrue);
      expect(GameMode.themed.hasDaily, isFalse);
      expect(GameMode.equations.scored, isFalse);
      expect(GameMode.classic.scored, isTrue);
    });
  });

  group('the equations', () {
    test('what makes a guess not an equation', () {
      expect(equationProblem('1+2=3'), isNull);
      expect(equationProblem('12+34=46'), isNull);
      expect(equationProblem('6/4*2=3'), isNull);
      expect(equationProblem('48-6=42'), isNull);
      expect(equationProblem('1+2'), 'needs exactly one =');
      expect(equationProblem('1=1=1'), 'needs exactly one =');
      expect(equationProblem('1+2=3+0'), 'the right of = is one number');
      expect(equationProblem('+1+2=3'), 'check the signs');
      expect(equationProblem('1++2=3'), 'check the signs');
      expect(equationProblem('12=12'), 'needs a sum on the left');
      expect(equationProblem('01+2=3'), 'no number starts with 0');
      expect(equationProblem('5/0+1=1'), 'no dividing by 0');
      expect(equationProblem('2+2=5'), 'both sides must be equal');
      // the order of operations: 2+3*4 is 14, not 20
      expect(equationProblem('2+3*4=14'), isNull);
      expect(equationProblem('2+3*4=20'), 'both sides must be equal');
      expect(equationProblem('5+0=5'), 'a lone 0 is not allowed');
    });

    test('every equation of the lists is one, of the length of its list', () {
      final counts = {6: 206, 7: 6371, 8: 17356};
      for (final n in equationLengths) {
        final lines = File('assets/equations/$n.txt')
            .readAsLinesSync()
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines.length, counts[n], reason: '$n tiles');
        expect(lines.toSet().length, lines.length);
        for (final l in lines) {
          expect(l.length, n, reason: l);
          expect(equationProblem(l), isNull, reason: l);
        }
      }
    });

    test('the daily is one equation of 8 tiles, the same on a date', () async {
      final langs = await WordBank.languages();
      final bank = await Equations.load(langs.first);
      final a = Daily.of(bank, '2026-11-04', GameMode.equations)!;
      final b = Daily.of(bank, '2026-11-04', GameMode.equations)!;
      expect(a.answer, b.answer);
      expect(a.length, 8);
      expect(a.tries, 6);
      expect(bank.valid, contains(a.answer));
      expect(equationProblem(a.answer), isNull);
      // it is the same in another language
      final other = await Equations.load(
        langs.firstWhere((l) => l.code == 'fr'),
      );
      expect(
        Daily.of(other, '2026-11-04', GameMode.equations)!.answer,
        a.answer,
      );
      // and not the same every day
      final days = {
        for (var d = 1; d < 20; d++)
          Daily.of(
            bank,
            '2026-11-${d.toString().padLeft(2, '0')}',
            GameMode.equations,
          )!.answer,
      };
      expect(days.length, greaterThan(15));
      expect(dailyTriesOf(GameMode.equations), 6);
    });

    test('the bank takes every character of an equation', () async {
      final langs = await WordBank.languages();
      final bank = await Equations.load(
        langs.firstWhere((l) => l.code == 'en'),
      );
      expect(bank.letters(8), containsAll('0123456789+-*/='.split('')));
      expect(bank.resolve('1+2=3'), '1+2=3');
    });

    test('the signs are drawn as the times, divide and minus signs', () {
      expect(faceOf('*'), '×');
      expect(faceOf('/'), '÷');
      expect(faceOf('-'), '−');
      expect(faceOf('7'), '7');
      expect(typedEquationChar('x'), '*');
      expect(typedEquationChar('÷'), '/');
    });
  });

  group('the games', () {
    testWidgets('equations: the keyboard has digits and signs, and a wrong '
        'guess says why', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(mode: GameMode.equations, tries: 6);
      final bank = (await tester.runAsync(
        () async => Equations.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.equations,
            practice: true,
            daily: const Daily('', '12+34=46', length: 8, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      for (final k in ['0', '9', '+', '×', '÷', '−', '=']) {
        expect(find.text(k), findsWidgets, reason: k);
      }
      expect(find.text('q'), findsNothing);
      // typed on the keyboard of the screen, as a phone would
      for (final ch in '12+34=47'.split('')) {
        await tester.tap(find.text(ch).last);
        await tester.pump();
      }
      await tester.tap(find.text('enter'));
      await tester.pump();
      expect(find.text('both sides must be equal'), findsOneWidget);
      // fix the last tile and play the equation that is the answer
      await tester.tap(find.text('⌫'));
      await tester.pump();
      await tester.tap(find.text('6').last);
      await tester.pump();
      await tester.tap(find.text('enter'));
      await tester.pump();
      expect(find.textContaining('solved in 1 of 6'), findsOneWidget);
    });

    testWidgets('equations: the hardware keyboard takes x as times', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(mode: GameMode.equations, tries: 6);
      final bank = (await tester.runAsync(
        () async => Equations.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.equations,
            practice: true,
            daily: const Daily('', '3*4+8=20', length: 8, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      // the x from the keyboard, the digits and = too; + from the screen's
      final keys = {
        '3': LogicalKeyboardKey.digit3,
        'x': LogicalKeyboardKey.keyX,
        '4': LogicalKeyboardKey.digit4,
        '8': LogicalKeyboardKey.digit8,
        '=': LogicalKeyboardKey.equal,
        '2': LogicalKeyboardKey.digit2,
        '0': LogicalKeyboardKey.digit0,
      };
      for (final ch in '3x4+8=20'.split('')) {
        if (ch == '+') {
          await tester.tap(find.text('+').last);
        } else {
          await tester.sendKeyEvent(keys[ch]!, character: ch);
        }
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.textContaining('solved in 1 of 6'), findsOneWidget);
    });
  });
}
