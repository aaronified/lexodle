import 'dart:ui' show Tristate;

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
import 'package:lexodle/ui.dart' show FlagBadge;
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

    test('a limit and a draw round trip, and are left out when unset', () {
      final p = back(
        DiyPuzzle(
          'en',
          'crane',
          6,
          limit: const Duration(minutes: 5),
          draw: Draw.equal,
        ),
      )!;
      expect((p.limit, p.draw), (const Duration(minutes: 5), Draw.equal));
      final f = DiyPuzzle(
        'en',
        'crane',
        6,
        limit: const Duration(seconds: 60),
        draw: Draw.frequency,
      );
      expect(f.link, allOf(contains('&cd=60'), contains('&d=f')));
      expect(back(f)!.draw, Draw.frequency);
      final plain = DiyPuzzle('en', 'crane', 6);
      expect(plain.link, isNot(contains('cd=')));
      expect(plain.link, isNot(contains('&d=')));
      expect(plain.draw, Draw.equal);
      final sig = DiyPuzzle('en', 'crane', 6, draw: Draw.sigmoid);
      expect(sig.link, contains('&d=s'));
      expect(back(sig)!.draw, Draw.sigmoid);
    });

    test('an unknown limit or draw is ignored', () {
      final w = diyEncode('crane');
      final p = DiyPuzzle.parse(Uri.parse('/diy?l=en&t=6&cd=90&d=x&w=$w'))!;
      expect((p.limit, p.draw), (null, Draw.equal));
      final q = DiyPuzzle.parse(Uri.parse('/diy?l=en&t=6&cd=30&d=s&w=$w'))!;
      expect((q.limit, q.draw), (null, Draw.sigmoid));
    });

    test('links of equations and blind, made before, still parse', () {
      final eq = DiyPuzzle.parse(
        Uri.parse('/diy?l=en&m=equations&t=6&w=${diyEncode('4*5=20')}'),
      )!;
      expect(
        (eq.mode, eq.word, eq.limit),
        (GameMode.equations, '4*5=20', null),
      );
      final blind = DiyPuzzle.parse(
        Uri.parse('/diy?l=en&m=blind&t=10&w=${diyEncode('crane')}'),
      )!;
      expect(
        (blind.mode, blind.word, blind.tries),
        (GameMode.blind, 'crane', 10),
      );
    });

    test('a link of an earlier version, with no mode, is classic', () {
      final old = DiyPuzzle.parse(
        Uri.parse('/diy?l=en&t=6&w=${diyEncode('crane')}'),
      )!;
      expect(old.mode, GameMode.classic);
      expect((old.limit, old.draw), (null, Draw.equal));
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
    Future<void> open(WidgetTester tester, {String lang = 'en'}) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      await appState.load();
      appState.setup(lang: lang, mode: GameMode.classic);
      // the screen reads the word list as it opens: have it read before, in real
      // time, or the read is left waiting on the test's clock for every test
      // after it (the asset cache keeps the first read)
      await tester.runAsync(() async {
        final langs = await WordBank.languages();
        await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
        await WordBank.load(langs.firstWhere((l) => l.code == 'fr'));
        await Geography.load(langs.firstWhere((l) => l.code == 'en'));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: SizedBox()),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: const DiyPage(), onGenerateRoute: onGenerateRoute),
      );
      await tester.pump();
    }

    Future<void> tapPill(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey('diy-$key')));
      await tester.pump();
    }

    bool on(WidgetTester tester, String key) =>
        tester
            .getSemantics(find.byKey(ValueKey('diy-$key')))
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;

    Future<void> typeWord(WidgetTester tester, String w) async {
      for (final ch in w.split('')) {
        await tester.tap(find.text(ch).last);
        await tester.pump();
      }
    }

    String linkOf(WidgetTester tester) => tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byKey(const ValueKey('diy-link')),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;

    testWidgets('there is no mode row, and each group selects one pill', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('mode-filter')), findsNothing);
      expect(find.byKey(const ValueKey('mode-classic')), findsNothing);
      expect(find.text('make your own'), findsOneWidget);
      // the defaults
      expect(on(tester, 'board-classic'), isTrue);
      expect(on(tester, 'rules-classic'), isTrue);
      expect(on(tester, 'timer-unlimited'), isTrue);
      expect(on(tester, 'draw-sigmoid'), isTrue);
      expect(on(tester, 'source-classic'), isTrue);
      await tapPill(tester, 'board-quartet');
      expect(
        (on(tester, 'board-quartet'), on(tester, 'board-classic')),
        (true, false),
      );
      await tapPill(tester, 'board-relay');
      expect(
        (on(tester, 'board-relay'), on(tester, 'board-quartet')),
        (true, false),
      );
      await tapPill(tester, 'board-classic');
      await tapPill(tester, 'rules-lockdown');
      expect(on(tester, 'rules-lockdown'), isTrue);
      expect(find.byKey(const ValueKey('diy-hearts')), findsOneWidget);
      expect(find.byKey(const ValueKey('diy-tries')), findsNothing);
      await tapPill(tester, 'rules-classic');
      expect(find.byKey(const ValueKey('diy-tries')), findsOneWidget);
      await tapPill(tester, 'timer-1 min');
      expect(
        (on(tester, 'timer-1 min'), on(tester, 'timer-unlimited')),
        (true, false),
      );
      await tapPill(tester, 'timer-5 min');
      expect(on(tester, 'timer-5 min'), isTrue);
      await tapPill(tester, 'draw-frequency');
      expect(on(tester, 'draw-frequency'), isTrue);
      await tapPill(tester, 'draw-equal');
      expect(
        (on(tester, 'draw-equal'), on(tester, 'draw-frequency')),
        (true, false),
      );
      await tapPill(tester, 'source-geography');
      expect(on(tester, 'source-geography'), isTrue);
      expect(find.text('geography is only in english'), findsNothing);
    });

    testWidgets('a quartet or a relay race cannot be locked down', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'board-quartet');
      await tapPill(tester, 'rules-lockdown');
      expect(find.text('a quartet cannot be locked down'), findsOneWidget);
      expect(on(tester, 'rules-classic'), isTrue);
      expect(on(tester, 'board-quartet'), isTrue);
      await tapPill(tester, 'board-relay');
      await tapPill(tester, 'rules-lockdown');
      expect(find.text('a relay race cannot be locked down'), findsOneWidget);
      expect(on(tester, 'rules-classic'), isTrue);
      expect(on(tester, 'board-relay'), isTrue);
    });

    testWidgets('lockdown, then a quartet or a relay race: classic rules', (
      tester,
    ) async {
      await open(tester);
      for (final b in ['quartet', 'relay']) {
        await tapPill(tester, 'board-classic');
        await tapPill(tester, 'rules-lockdown');
        expect(on(tester, 'rules-lockdown'), isTrue);
        await tapPill(tester, 'board-$b');
        expect(
          find.text('lockdown is for one board: classic rules it is'),
          findsOneWidget,
        );
        expect(on(tester, 'rules-classic'), isTrue);
        expect(on(tester, 'board-$b'), isTrue);
      }
    });

    testWidgets('geography keeps classic with a non-english language', (
      tester,
    ) async {
      await open(tester, lang: 'fr');
      await tapPill(tester, 'source-geography');
      expect(find.text('geography is only in english'), findsOneWidget);
      expect(on(tester, 'source-classic'), isTrue);
    });

    testWidgets('geography keeps classic on a quartet, a relay, a lockdown', (
      tester,
    ) async {
      await open(tester);
      for (final b in ['quartet', 'relay']) {
        await tapPill(tester, 'board-$b');
        await tapPill(tester, 'source-geography');
        expect(find.text('geography is one board, classic rules'), findsOne);
        expect(on(tester, 'source-classic'), isTrue);
        expect(on(tester, 'board-$b'), isTrue);
      }
      await tapPill(tester, 'board-classic');
      await tapPill(tester, 'rules-lockdown');
      await tapPill(tester, 'source-geography');
      expect(find.text('geography is one board, classic rules'), findsOne);
      expect(on(tester, 'source-classic'), isTrue);
      expect(on(tester, 'rules-lockdown'), isTrue);
    });

    testWidgets('geography goes back to classic when the board or rules move', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'source-geography');
      expect(on(tester, 'source-geography'), isTrue);
      await tapPill(tester, 'board-quartet');
      expect(find.text('geography is one board, classic rules'), findsOne);
      expect(on(tester, 'source-classic'), isTrue);
      await tapPill(tester, 'board-classic');
      await tapPill(tester, 'source-geography');
      await tapPill(tester, 'rules-lockdown');
      expect(find.text('geography is one board, classic rules'), findsOne);
      expect(on(tester, 'source-classic'), isTrue);
      expect(on(tester, 'rules-lockdown'), isTrue);
    });

    testWidgets('the language pill shows the flag and code, and opens the '
        'sheet', (tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diy-language')),
          matching: find.text('en'),
        ),
        findsOneWidget,
      );
      expect(find.byType(FlagBadge), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('diy-language')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-fr')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diy-language')),
          matching: find.text('fr'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a language away from english turns geography off', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'source-geography');
      expect(on(tester, 'source-geography'), isTrue);
      await tester.tap(find.byKey(const ValueKey('diy-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-fr')));
      await tester.pumpAndSettle();
      expect(find.text('geography is only in english'), findsOneWidget);
      expect(on(tester, 'source-classic'), isTrue);
    });

    testWidgets('a classic board makes a link with its timer and pool', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'timer-1 min');
      await tapPill(tester, 'draw-frequency');
      await typeWord(tester, 'crane');
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect(p.mode, GameMode.classic);
      expect(p.word, 'crane');
      expect(p.limit, const Duration(minutes: 1));
      expect(p.draw, Draw.frequency);
    });

    testWidgets('the default pool makes a link with d=s', (tester) async {
      await open(tester);
      await typeWord(tester, 'crane');
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final link = linkOf(tester);
      expect(link, contains('&d=s'));
      expect(DiyPuzzle.parse(Uri.parse(routeOf(link)))!.draw, Draw.sigmoid);
    });

    testWidgets('lockdown rules make a lockdown puzzle with hearts', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'rules-lockdown');
      await typeWord(tester, 'crane');
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect(p.mode, GameMode.lockdown);
      expect(p.hearts, isNotNull);
    });

    testWidgets('geography makes a themed puzzle', (tester) async {
      await open(tester);
      await tapPill(tester, 'source-geography');
      await tester.pump();
      await typeWord(tester, 'spain');
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect((p.mode, p.word, p.lang), (GameMode.themed, 'spain', 'en'));
    });

    testWidgets('each length pill selects and sets the tile count', (
      tester,
    ) async {
      await open(tester);
      expect(on(tester, 'length-5'), isTrue);
      for (final n in diyLengths) {
        await tapPill(tester, 'length-$n');
        expect(on(tester, 'length-$n'), isTrue);
        expect(find.byKey(ValueKey('diy-tile-${n - 1}')), findsOneWidget);
        expect(find.byKey(ValueKey('diy-tile-$n')), findsNothing);
      }
    });

    testWidgets('a word is held to the length, and a link of 6 parses back', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'length-6');
      await typeWord(tester, 'cranes');
      await typeWord(tester, 'x');
      expect(find.byKey(const ValueKey('diy-tile-6')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diy-tile-5')),
          matching: find.text('s'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect(p.word.length, 6);
      // a shorter word is not complete
      await tapPill(tester, 'length-7');
      expect(find.byKey(const ValueKey('diy-link')), findsNothing);
      await typeWord(tester, 'cranes');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('diy-make')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a length change keeps the words that fit', (tester) async {
      await open(tester);
      await tapPill(tester, 'board-quartet');
      await typeWord(tester, 'crane');
      await tapPill(tester, 'length-6');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diy-tile-0')),
          matching: find.text('c'),
        ),
        findsNothing,
      );
      await tapPill(tester, 'length-5');
      await typeWord(tester, 'crane');
      await tapPill(tester, 'length-5');
      await tapPill(tester, 'length-6');
      await tapPill(tester, 'length-5');
      expect(find.byKey(const ValueKey('diy-tile-4')), findsOneWidget);
    });

    testWidgets('geography shows the place lengths', (tester) async {
      await open(tester);
      await tapPill(tester, 'source-geography');
      await tester.pump();
      for (final n in Geography.counts.keys) {
        expect(find.byKey(ValueKey('diy-length-$n')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('diy-length-9')), findsNothing);
      expect(on(tester, 'length-5'), isTrue);
    });

    testWidgets('the length survives a board change when legal, else resets', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'length-7');
      await tapPill(tester, 'board-relay');
      expect(on(tester, 'length-7'), isTrue);
      await tapPill(tester, 'board-classic');
      await tapPill(tester, 'source-geography');
      await tester.pump();
      expect(on(tester, 'length-7'), isTrue);
      // a length no place has resets to the default when the source changes
      final keep = Map.of(Geography.counts);
      Geography.counts = {
        for (final e in keep.entries)
          if (e.key != 7) e.key: e.value,
      };
      await tapPill(tester, 'source-classic');
      await tapPill(tester, 'length-7');
      await tapPill(tester, 'source-geography');
      expect(on(tester, 'length-5'), isTrue);
      Geography.counts = keep;
    });

    testWidgets('quartet: four words, one at a time, tries of its own', (
      tester,
    ) async {
      await open(tester);
      await tapPill(tester, 'board-quartet');
      expect(find.byKey(const ValueKey('diy-word-3')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('diy-word-$i')));
        await tester.pump();
        await typeWord(tester, ['crane', 'plumb', 'ghost', 'fifty'][i]);
      }
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect(p.mode, GameMode.quartet);
      expect(p.words, ['crane', 'plumb', 'ghost', 'fifty']);
      expect(p.tries, 9);
    });

    testWidgets('a relay race makes a relay puzzle', (tester) async {
      await open(tester);
      await tapPill(tester, 'board-relay');
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('diy-word-$i')));
        await tester.pump();
        await typeWord(tester, ['crane', 'plumb', 'ghost', 'fifty'][i]);
      }
      await tester.tap(find.byKey(const ValueKey('diy-make')));
      await tester.pump();
      final p = DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!;
      expect((p.mode, p.tries), (GameMode.relay, 10));
    });

    testWidgets('the keyboard of the computer types, erases and makes', (
      tester,
    ) async {
      await open(tester);
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
      expect(
        DiyPuzzle.parse(Uri.parse(routeOf(linkOf(tester))))!.word,
        'crane',
      );
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

    testWidgets('the limit and the draw reach the game', (tester) async {
      await play(
        tester,
        DiyPuzzle(
          'en',
          'crane',
          6,
          limit: const Duration(minutes: 1),
          draw: Draw.frequency,
        ),
      );
      final g = tester.widget<GamePage>(find.byType(GamePage));
      expect((g.limit, g.draw), (const Duration(minutes: 1), Draw.frequency));
      expect(g.practice, isTrue);
    });

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
