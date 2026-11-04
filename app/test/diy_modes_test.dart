import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/diy.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/game_modes_dialog.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  DiyPuzzle? back(DiyPuzzle p) => DiyPuzzle.parse(Uri.parse(routeOf(p.link)));

  group('the link', () {
    test('every mode with an answer round trips; the mastermind has none', () {
      for (final m in GameMode.values) {
        expect(diyApplies(m), m != GameMode.mastermind, reason: '$m');
      }
      final classic = back(DiyPuzzle('en', 'crane', 6))!;
      expect(classic.mode, GameMode.classic);
      expect(classic.word, 'crane');
      final lock = back(
        DiyPuzzle('en', 'crane', 6, mode: GameMode.lockdown, hearts: 3),
      )!;
      expect((lock.mode, lock.hearts), (GameMode.lockdown, 3));
      final blind = back(DiyPuzzle('fr', 'élève', 10, mode: GameMode.blind))!;
      expect(
        (blind.mode, blind.word, blind.tries),
        (GameMode.blind, 'élève', 10),
      );
      final quartet = back(
        DiyPuzzle(
          'en',
          'crane',
          9,
          mode: GameMode.quartet,
          words: ['crane', 'plumb', 'ghost', 'fifty'],
        ),
      )!;
      expect(quartet.words, ['crane', 'plumb', 'ghost', 'fifty']);
      final eq = back(DiyPuzzle('en', '4*5=20', 6, mode: GameMode.equations))!;
      expect((eq.mode, eq.word), (GameMode.equations, '4*5=20'));
      final place = back(DiyPuzzle('en', 'spain', 6, mode: GameMode.themed))!;
      expect(place.mode, GameMode.themed);
    });

    test('a link of an earlier version, with no mode, is classic', () {
      final old = DiyPuzzle.parse(
        Uri.parse('/diy?l=en&t=6&w=${diyEncode('crane')}'),
      )!;
      expect(old.mode, GameMode.classic);
    });

    test('what is not a puzzle is not read', () {
      String link(String q) => '/diy?l=en&t=6&$q';
      final w = diyEncode('crane');
      // a mastermind has no answer to make up
      expect(DiyPuzzle.parse(Uri.parse(link('m=mastermind&w=$w'))), isNull);
      // an equation that is not true
      expect(
        DiyPuzzle.parse(
          Uri.parse(link('m=equations&w=${diyEncode('2+2=5x')}')),
        ),
        isNull,
      );
      expect(
        DiyPuzzle.parse(Uri.parse(link('m=equations&w=${diyEncode('2+2=5')}'))),
        isNull,
        reason: 'a true equation, but not six to eight tiles',
      );
      // a quartet with one word
      expect(DiyPuzzle.parse(Uri.parse(link('m=quartet&w=$w'))), isNull);
      // words of different lengths
      expect(
        DiyPuzzle.parse(
          Uri.parse(link('m=quartet&w=$w.$w.$w.${diyEncode('cranes')}')),
        ),
        isNull,
      );
      // a lockdown without its hearts
      expect(DiyPuzzle.parse(Uri.parse(link('m=lockdown&w=$w'))), isNull);
      expect(DiyPuzzle.parse(Uri.parse(link('m=nothing&w=$w'))), isNull);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester, GameMode mode) async {
      await tester.binding.setSurfaceSize(const Size(420, 2000));
      await appState.load();
      appState.setup(lang: 'en', mode: mode);
      // the screen reads the word list as it opens: have it read before, in real
      // time, or the read is left waiting on the test's clock for every test
      // after it (the asset cache keeps the first read)
      await tester.runAsync(() async {
        final langs = await WordBank.languages();
        await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
      });
      await tester.pumpWidget(
        MaterialApp(home: const DiyPage(), onGenerateRoute: onGenerateRoute),
      );
      await tester.pump();
    }

    testWidgets('equations: a number pad, and an untrue one is told so', (
      tester,
    ) async {
      await open(tester, GameMode.equations);
      expect(find.text('make your own · equations'), findsOneWidget);
      expect(find.byKey(const ValueKey('diy-language')), findsNothing);
      expect(find.text('÷'), findsWidgets);
      expect(find.text('q'), findsNothing);
      for (final ch in '2+2=5x'.replaceAll('x', '').split('')) {
        await tester.tap(find.text(faceOf(ch)).last);
        await tester.pump();
      }
      expect(find.textContaining('six, seven or eight'), findsOneWidget);
      for (final ch in '=0'.split('')) {
        await tester.tap(find.text(faceOf(ch)).last);
        await tester.pump();
      }
      // "2+2=5=0": two signs
      expect(find.text('needs exactly one ='), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('diy-make')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('equations: a true one makes a link', (tester) async {
      await open(tester, GameMode.equations);
      for (final ch in '4*5=20'.split('')) {
        await tester.tap(find.text(faceOf(ch)).last);
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final link = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byKey(const ValueKey('diy-link')),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
      expect(DiyPuzzle.parse(Uri.parse(routeOf(link)))!.word, '4*5=20');
    });

    testWidgets('quartet: four words, one at a time, tries of its own', (
      tester,
    ) async {
      await open(tester, GameMode.quartet);
      expect(find.byKey(const ValueKey('diy-word-3')), findsOneWidget);
      Future<void> typeWord(String w) async {
        for (final ch in w.split('')) {
          await tester.tap(find.text(ch).last);
          await tester.pump();
        }
      }

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('diy-word-$i')));
        await tester.pump();
        await typeWord(['crane', 'plumb', 'ghost', 'fifty'][i]);
      }
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final link = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byKey(const ValueKey('diy-link')),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
      final p = DiyPuzzle.parse(Uri.parse(routeOf(link)))!;
      expect(p.mode, GameMode.quartet);
      expect(p.words, ['crane', 'plumb', 'ghost', 'fifty']);
      expect(p.tries, 9);
    });

    testWidgets('the keyboard of the computer types, erases and makes', (
      tester,
    ) async {
      await open(tester, GameMode.classic);
      Future<void> type(String w) async {
        for (final ch in w.split('')) {
          await tester.sendKeyEvent(
            LogicalKeyboardKey(ch.codeUnitAt(0)),
            character: ch,
          );
        }
        await tester.pump();
      }

      await type('cranx');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await type('e');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final link = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byKey(const ValueKey('diy-link')),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
      expect(DiyPuzzle.parse(Uri.parse(routeOf(link)))!.word, 'crane');
      // shift and backspace clear the word, and the link with it
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.byKey(const ValueKey('diy-link')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('diy-make')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('lockdown: hearts, not tries', (tester) async {
      await open(tester, GameMode.lockdown);
      expect(find.byKey(const ValueKey('diy-hearts')), findsOneWidget);
      expect(find.byKey(const ValueKey('diy-tries')), findsNothing);
    });
  });

  group('playing a made puzzle', () {
    Future<void> play(WidgetTester tester, DiyPuzzle p) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      await tester.runAsync(() async {
        final langs = await WordBank.languages();
        await Equations.load(langs.firstWhere((l) => l.code == p.lang));
        await WordBank.load(langs.firstWhere((l) => l.code == p.lang));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: DiyGate(puzzle: p),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      // (a lockdown game with few hearts throbs, so it never settles)
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a quartet opens as a quartet with its tries', (tester) async {
      await play(
        tester,
        DiyPuzzle(
          'en',
          'crane',
          9,
          mode: GameMode.quartet,
          words: ['crane', 'plumb', 'ghost', 'fifty'],
        ),
      );
      expect(find.byType(MultiGamePage), findsOneWidget);
    });

    testWidgets('an equation opens as an equations game on the number pad', (
      tester,
    ) async {
      await play(
        tester,
        DiyPuzzle('en', '4*5=20', 6, mode: GameMode.equations),
      );
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.text('÷'), findsWidgets);
    });

    testWidgets('a lockdown puzzle has the hearts it was made with', (
      tester,
    ) async {
      await play(
        tester,
        DiyPuzzle('en', 'crane', 6, mode: GameMode.lockdown, hearts: 3),
      );
      expect(find.byType(GamePage), findsOneWidget);
      final state = tester.state(find.byType(GamePage)) as dynamic;
      expect(state.heartsTotal, 3);
    });
  });

  testWidgets('the game modes offer it in every mode but the mastermind', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    await appState.load();
    // the dialog counts the equations and the places as it opens: have them
    // read before, so no read is left waiting on the test's clock
    await tester.runAsync(() async {
      final langs = await WordBank.languages();
      final en = langs.firstWhere((l) => l.code == 'en');
      await Equations.load(en);
      await Geography.load(en);
    });
    for (final m in GameMode.values) {
      appState.setup(lang: 'en', mode: m);
      await tester.pumpWidget(const MaterialApp(home: GameModesDialog()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-diy')),
        m == GameMode.mastermind ? findsNothing : findsOneWidget,
        reason: '$m',
      );
    }
  });
}
