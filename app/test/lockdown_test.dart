import 'dart:math';

import 'package:flutter/material.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/guess_input.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/mode_wheel.dart' show modeIconName;
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  late WordBank bank;

  Future<void> open(WidgetTester tester, {int hearts = 3, Daily? daily}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(
      lang: 'fr',
      length: 4,
      tries: 6,
      mode: GameMode.lockdown,
      hearts: hearts,
    );
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          bank: bank,
          random: Random(7),
          mode: GameMode.lockdown,
          daily: daily,
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  /// A letter with no desktop key (é, ç...) is tapped on the screen's keyboard.
  Future<void> typeKey(WidgetTester tester, String ch) async {
    if (RegExp(r'^[a-z]$').hasMatch(ch)) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    } else {
      await tester.tap(find.text(ch).last);
    }
    await tester.pump();
  }

  Future<void> guess(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      await typeKey(tester, ch);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  String heartState(WidgetTester tester, int i) {
    for (final s in ['breaking', 'throbbing', 'whole', 'lost']) {
      if (find.byKey(ValueKey('heart-$i-$s')).evaluate().isNotEmpty) return s;
    }
    return 'none';
  }

  /// The answer of the seeded game, and a word that fits some of it.
  (String, String) answerAndPartial() {
    final answer = chooseWord(
      bank.answers(4),
      bank.drawWeights(4, appState.draw),
      Random(7),
    );
    final w = bank
        .guessable(4)
        .firstWhere(
          (g) =>
              g != answer &&
              RegExp(r'^[a-z]+$').hasMatch(g) &&
              evaluate(answer, g).contains(Mark.correct),
        );
    return (answer, w);
  }

  testWidgets(
    'it plays four-letter hearts and six tries, header with the mode icon',
    (tester) async {
      await open(tester);
      expect(find.bySemanticsLabel('3 hearts left'), findsOneWidget);
      expect(find.textContaining('4 · 6 tries'), findsOneWidget);
      expect(find.textContaining('3 hearts · 6 tries left'), findsOneWidget);
      // the header is the flag, the mode's icon and the text: no language name
      expect(find.textContaining('français'), findsNothing);
    },
  );

  testWidgets('a word that is not in the list costs a heart, not a try', (
    tester,
  ) async {
    await open(tester);
    await guess(tester, 'qqqq');
    expect(find.text('not in the word list'), findsOneWidget);
    expect(find.bySemanticsLabel('2 hearts left'), findsOneWidget);
    expect(heartState(tester, 2), 'breaking');
    // (the hearts left throb for good, so nothing ever settles: wait by time)
    await tester.pump(const Duration(seconds: 2));
    expect(heartState(tester, 2), 'lost');
    // the tries are untouched: a bad word is not a guess
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.textContaining('2 hearts · 6 tries left'), findsOneWidget);
  });

  testWidgets(
    'the hearts left throb when three or fewer, and lost ones do not',
    (tester) async {
      await open(tester, hearts: 5);
      await tester.pump();
      expect(heartState(tester, 0), 'whole');
      await guess(tester, 'qqqq'); // 4 left
      await tester.pump(const Duration(seconds: 1));
      expect(heartState(tester, 0), 'whole');
      await guess(tester, 'qqqq'); // 3 left: they beat
      await tester.pump(const Duration(seconds: 1));
      expect(heartState(tester, 0), 'throbbing');
      expect(heartState(tester, 2), 'throbbing');
      expect(heartState(tester, 3), anyOf('breaking', 'lost'));
      await tester.pump(const Duration(seconds: 2));
      expect(heartState(tester, 3), 'lost');
      expect(heartState(tester, 4), 'lost');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('with no hearts left the game is lost and ends like any other', (
    tester,
  ) async {
    await open(tester, hearts: 1);
    final before = appState.stats.played;
    await guess(tester, 'qqqq');
    await tester.pump(const Duration(seconds: 2));
    // the end panel of every mode: the answer, and the way on
    expect(find.byKey(const ValueKey('freq-plot')), findsNothing);
    expect(find.text('replay'), findsOneWidget);
    expect(appState.stats.played, before + 1);
    expect(appState.stats.wins, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a letter in the right place locks for good and stays for the next guess',
    (tester) async {
      await open(tester, hearts: 10);
      final (answer, partial) = answerAndPartial();
      final greens = [
        for (var i = 0; i < 4; i++)
          if (evaluate(answer, partial)[i] == Mark.correct) i,
      ];
      await guess(tester, partial);
      // a locked tile in the next row for every green
      expect(
        find.byKey(const ValueKey('locked')),
        findsNWidgets(greens.length),
      );
      // the game's lock is green, its border too
      final scheme = Theme.of(tester.element(find.byType(GamePage)))
          .colorScheme;
      final green = markColors(scheme, Mark.correct).$1;
      expect(
        tester
            .widget<TablerIcon>(find.byKey(const ValueKey('locked')).first)
            .color,
        green,
      );
      final box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(ValueKey('tile-1-${greens.first}')),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect((box.border as Border).top.color, green);
      // the lock sits in the corner of its tile
      final tile = tester.getRect(
        find.byKey(ValueKey('tile-1-${greens.first}')),
      );
      final lock = tester.getCenter(find.byKey(const ValueKey('locked')).first);
      expect(lock.dx, greaterThan(tile.center.dx));
      expect(lock.dy, lessThan(tile.center.dy));
      expect(tile.contains(lock), isTrue);
      for (final i in greens) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('tile-1-$i')),
            matching: find.text(partial[i]),
          ),
          findsOneWidget,
        );
        // a double tap does not take it off
        await tester.tap(find.byKey(ValueKey('tile-1-$i')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(ValueKey('tile-1-$i')));
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('locked')),
        findsNWidgets(greens.length),
      );
      // typing goes into the open slots only
      final open0 = [
        for (var i = 0; i < 4; i++)
          if (!greens.contains(i)) i,
      ];
      await typeKey(tester, 'z');
      // the taps on the locked tiles left the cursor on the last of them: the
      // letter goes in the first open slot after it, or from the start
      final target = open0.firstWhere(
        (i) => i > greens.last,
        orElse: () => open0.first,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('tile-1-$target')),
          matching: find.text('z'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a lockdown daily has five hearts and keeps what is left', (
    tester,
  ) async {
    final d = Daily('2026-11-03', 'abcd', length: 4, tries: lockdownTries);
    await open(tester, daily: d);
    expect(find.bySemanticsLabel('$dailyHearts hearts left'), findsOneWidget);
    expect(find.textContaining('2026-11-03'), findsOneWidget);
    await guess(tester, 'qqqq');
    final saved = appState.dailyFor('fr', '2026-11-03', GameMode.lockdown);
    expect(saved?.hearts, dailyHearts - 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the home mode button and the achievements show the lock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', mode: GameMode.lockdown);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mode-name-lockdown')), findsOneWidget);
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    // the icon of the mode on the mode button is the lock, drawn
    final icon = find.descendant(
      of: find.byKey(const ValueKey('mode-button')),
      matching: find.byType(SvgPicture),
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon).width, greaterThan(16));
    expect(modeIconName(GameMode.lockdown), 'lock');
    expect(
      File('assets/icons/lock.svg').existsSync(),
      isTrue,
      reason: 'the icon is an asset of the app',
    );
  });

  test('a fixed lock cannot be toggled off, and clear lets go of it', () {
    final g = GuessInput(4)..lockFixed([(1, 'a'), (3, 'b')]);
    expect(g.isFixed(1), isTrue);
    expect(g.toggleLock(1), isTrue);
    expect(g.isLocked(1), isTrue);
    g.next();
    expect(g.slots, ['', 'a', '', 'b']);
    expect(g.cursor, 0);
    g.clear();
    expect(g.hasLocked, isFalse);
  });
}
