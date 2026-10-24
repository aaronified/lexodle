import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  testWidgets('game modes: mode, shared letters, helper, play and the solver', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, mode: GameMode.classic, share: 10);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();

    // the home screen keeps only the game itself: no helper, no solver
    expect(find.text('helper'), findsNothing);
    expect(find.text('solver'), findsNothing);
    expect(find.text('play'), findsOneWidget);

    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();
    expect(find.text('game modes'), findsWidgets);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('mode'), findsOneWidget);
    expect(find.text('helper'), findsOneWidget);
    expect(find.text('open the solver'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-play')), findsOneWidget);
    // one word has nothing to share: the slider is there, greyed and fixed
    expect(find.text('shared letters'), findsOneWidget);
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('share-slider')))
          .onChanged,
      isNull,
    );
    await tester.drag(
      find.byKey(const ValueKey('share-slider')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(appState.share, 10, reason: 'a greyed slider does not move');

    // quartet brings the shared-letters slider, 0 to 30
    appState.setup(mode: GameMode.quartet);
    await tester.pumpAndSettle();
    expect(find.text('shared letters'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('share-slider')),
    );
    expect(slider.min, 0);
    expect(slider.max, 30);
    await tester.drag(
      find.byKey(const ValueKey('share-slider')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(appState.share, 30);
    expect(find.text('30%'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('share-slider')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    expect(appState.share, 0);

    // closing leaves the choice on the play button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('play · quartet'), findsOneWidget);
  });

  testWidgets('the helper is greyed and fixed outside classic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(
      lang: 'fr',
      length: 4,
      mode: GameMode.classic,
      helper: Helper.off,
    );
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();

    final fade = find.byKey(const ValueKey('helper-fade'));
    final next = find.descendant(
      of: fade,
      matching: find.byIcon(Icons.chevron_right),
    );
    Opacity opacity() => tester.widget<Opacity>(fade);

    // classic: the helper is live and a chevron changes it
    expect(opacity().opacity, 1);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(appState.helper, Helper.skill);

    // quartet and relay race: dimmed, and nothing changes it
    for (final m in [GameMode.quartet, GameMode.relay]) {
      appState.setup(mode: m);
      await tester.pumpAndSettle();
      expect(opacity().opacity, lessThan(1), reason: '$m');
      await tester.tap(next, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(appState.helper, Helper.skill, reason: '$m: a tap does nothing');
      // nor does the keyboard: it cannot even focus the stepper
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(appState.helper, Helper.skill, reason: '$m: nor a key');
      expect(
        find.text(
          'the helper shows in classic mode only. whatever you '
          'choose, everything is revealed when the game ends.',
        ),
        findsOneWidget,
      );
    }

    // back to classic and it is live again
    appState.setup(mode: GameMode.classic);
    await tester.pumpAndSettle();
    expect(opacity().opacity, 1);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(appState.helper, Helper.skillLuck);
  });

  test('mode and shared letters are kept and bounded', () async {
    SharedPreferences.setMockInitialValues({});
    await appState.load();
    appState.setup(mode: GameMode.relay, share: 99);
    expect(appState.share, 30, reason: 'the slider tops out at 30%');
    appState.setup(share: -5);
    expect(appState.share, 0);
    appState.setup(share: 20);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('mode'), GameMode.relay.index);
    expect(p.getInt('share'), 20);
  });

  group('multi-board screen', () {
    late WordBank bank;

    Future<void> open(WidgetTester tester, GameMode mode, int seed) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(
        lang: 'fr',
        length: 4,
        tries: 6,
        pool: 500,
        mode: mode,
        share: 10,
      );
      bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: MultiGamePage(bank: bank, random: Random(seed)),
        ),
      );
      await tester.pump();
    }

    List<String> answers(int seed) => chooseTargets(
      bank.answers(4, 500),
      bank.answerWeights(4, 500),
      4,
      10,
      Random(seed),
    );

    Future<void> type(WidgetTester tester, String w) async {
      for (final ch in w.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }

    testWidgets('quartet: nine tries at normal, solve all four', (
      tester,
    ) async {
      await open(tester, GameMode.quartet, 3);
      expect(find.text('0 of 4 solved · 9 tries left'), findsOneWidget);
      final a = answers(3);
      expect(a.toSet().length, 4);

      await type(tester, a[0]);
      // the keyboard now carries what each board says about the letters used
      expect(find.byKey(ValueKey('quad-${a[0][0]}')), findsOneWidget);
      expect(find.text('1 of 4 solved · 8 tries left'), findsOneWidget);
      expect(find.textContaining('1 · solved in 1'), findsOneWidget);
      for (final w in a.skip(1)) {
        await type(tester, w);
      }
      await tester.pumpAndSettle();
      expect(find.text('solved all 4 in 4 of 9'), findsOneWidget);
      expect(find.text('replay'), findsOneWidget);
      for (final w in a) {
        expect(find.text(w), findsWidgets);
      }
    });

    testWidgets('relay race: ten tries, boards open in order', (tester) async {
      await open(tester, GameMode.relay, 5);
      expect(find.text('word 1 of 4 · 10 tries left'), findsOneWidget);
      final a = answers(5);
      await type(tester, a[0]);
      // whole keys, no four-way split, in a relay race
      expect(find.byKey(ValueKey('quad-${a[0][0]}')), findsNothing);
      expect(find.text('word 2 of 4 · 9 tries left'), findsOneWidget);
      expect(find.textContaining('1 · solved in 1'), findsOneWidget);
    });

    testWidgets('a wrong word is turned away without costing a try', (
      tester,
    ) async {
      await open(tester, GameMode.quartet, 3);
      await type(tester, 'eeee');
      expect(find.text('not in the word list'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(find.text('0 of 4 solved · 9 tries left'), findsOneWidget);
    });
  });
}

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));
