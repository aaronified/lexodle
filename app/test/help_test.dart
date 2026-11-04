import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/help.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the help text', () {
    List<String> heads(GameMode m, {bool daily = false}) => [
      for (final s in modeHelp(m, daily: daily)) s.heading,
    ];

    test('every mode has rules, typing, spaces, locks and erase', () {
      for (final m in GameMode.values) {
        final h = heads(m);
        for (final part in [
          'the rules',
          'typing',
          'spaces',
          'locks',
          'erase',
        ]) {
          expect(h, contains(part), reason: '$m');
        }
        expect(heads(m, daily: true).last, 'the daily');
        expect(heads(m), isNot(contains('the daily')));
      }
    });

    test('the lines are short and name no other game', () {
      for (final m in GameMode.values) {
        for (final s in modeHelp(m, daily: true)) {
          for (final l in s.lines) {
            expect(l.length, lessThan(60), reason: '$m: $l');
            for (final name in ['wordle', 'nerdle', 'absurdle', 'sudoku']) {
              expect(l.toLowerCase(), isNot(contains(name)), reason: '$m');
            }
          }
        }
      }
    });

    test('blind locks by its counts, the others by the guesses', () {
      String locks(GameMode m) =>
          modeHelp(m).firstWhere((s) => s.heading == 'locks').lines.join(' ');
      expect(locks(GameMode.blind), contains('the counts'));
      expect(locks(GameMode.classic), contains('the guesses'));
      expect(locks(GameMode.relay), contains('only the board in play'));
    });
  });

  group('the crops', () {
    testWidgets('every crop of every mode builds, in both themes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      for (final dark in [false, true]) {
        for (final m in GameMode.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.pink,
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final s in modeHelp(m))
                        if (s.crop != null) HelpCrop(s.crop!),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$m');
        }
      }
    });
  });

  group('the help button', () {
    late WordBank bank;

    Future<void> openGame(
      WidgetTester tester,
      GameMode mode, {
      Daily? daily,
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, mode: mode);
      bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, mode: mode, daily: daily),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
    }

    testWidgets('a game has it on the top right and it shows the rules', (
      tester,
    ) async {
      await openGame(tester, GameMode.blind);
      final button = find.byKey(const ValueKey('help-button'));
      expect(button, findsOneWidget);
      // on the right of the app bar
      expect(tester.getCenter(button).dx, greaterThan(300));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-dialog')), findsOneWidget);
      expect(find.text('how to play · blind'), findsOneWidget);
      expect(find.text('spaces'), findsOneWidget);
      expect(find.text('the daily'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('help-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-dialog')), findsNothing);
    });

    testWidgets('a daily has it too, with what a daily is', (tester) async {
      await openGame(
        tester,
        GameMode.classic,
        daily: const Daily('2026-11-04', 'crane'),
      );
      await tester.tap(find.byKey(const ValueKey('help-button')));
      await tester.pumpAndSettle();
      expect(find.text('the daily'), findsOneWidget);
    });

    testWidgets('a quartet has it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, mode: GameMode.quartet);
      bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: MultiGamePage(bank: bank),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('help-button')));
      await tester.pumpAndSettle();
      expect(find.text('how to play · quartet'), findsOneWidget);
    });
  });
}
