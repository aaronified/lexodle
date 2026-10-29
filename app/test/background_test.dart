import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/background.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the game does for the end screen while it is still being played.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordBank bank;
  late List<String> requested;

  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    requested = [];
    // a fake Wiktionary that answers at once and says what was asked for
    Wiktionary.shared = Wiktionary(
      client: MockClient((req) async {
        requested.add(req.url.queryParameters['page']!);
        return http.Response('{"error":{"code":"missingtitle"}}', 200);
      }),
    );
  });
  tearDown(() {
    prefetchDefinitions = false;
    analyseWhilePlaying = false;
  });

  Future<void> load(WidgetTester tester) async {
    // inside the test, so the queue's first future lives in its fake-time zone
    Wiktionary.reset();
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3, mode: GameMode.classic);
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
  }

  Future<void> type(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      if (RegExp(r'^[a-z]$').hasMatch(ch)) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch,
        );
      } else {
        // a letter with no key on a desktop keyboard (é, ß, ñ...) is tapped on
        // the screen's own keyboard, as a player would
        await tester.tap(
          find
              .descendant(
                of: find.byType(LetterKeyboard),
                matching: find.text(ch),
              )
              .first,
        );
        await tester.pump();
      }
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  testWidgets('a classic game looks its answer up before the first guess', (
    tester,
  ) async {
    await load(tester);
    prefetchDefinitions = true;
    final answer = chooseWord(
      bank.answers(4),
      bank.answerWeights(4),
      Random(7),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(requested, isNotEmpty);
    expect(requested.first.toLowerCase(), answer.toLowerCase());
  });

  testWidgets('a quartet looks up all four answers, one at a time', (
    tester,
  ) async {
    await load(tester);
    appState.setup(mode: GameMode.quartet, share: 10);
    prefetchDefinitions = true;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiGamePage(bank: bank, random: Random(3)),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final answers = chooseTargets(
      bank.answers(4),
      bank.answerWeights(4),
      4,
      10,
      Random(3),
    ).map((w) => w.toLowerCase()).toSet();
    final seen = requested.map((p) => p.toLowerCase()).toSet();
    expect(seen.containsAll(answers), isTrue, reason: '$seen vs $answers');
  });

  testWidgets('the review opens with its picks already worked out', (
    tester,
  ) async {
    await load(tester);
    analyseWhilePlaying = true;
    final pool = bank.answers(4);
    final answer = chooseWord(pool, bank.answerWeights(4), Random(7));
    final guesses = pool.where((w) => w != answer).take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    for (final w in guesses) {
      await type(tester, w);
    }
    // the work went on while the game was being played and the end screen shown
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();
    // one frame in, no "working it out": the first step's picks are there
    expect(find.text('working it out…'), findsNothing);
    expect(find.text('best skill'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30)); // let anything left finish
  });

  test('a new game stops the work on the last game\'s guesses', () async {
    final queue = JobQueue();
    var ran = 0;
    expect(
      await queue.add(() async {
        ran++;
        return 1;
      }),
      1,
    );
    queue.close(); // a new game has begun
    var finished = false;
    queue
        .add(() async {
          ran++;
          return 2;
        })
        .then((_) => finished = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ran, 1, reason: 'the job queued after close never ran');
    expect(finished, isFalse);
  });

  group('skill is measured against the best real guess as the game is played', () {
    Future<(List<String>, String)> setup(WidgetTester tester) async {
      await load(tester);
      appState.setup(helper: Helper.full, mode: GameMode.classic);
      analyseWhilePlaying = true;
      final all = bank.guessable(4);
      final answer = chooseWord(
        bank.answers(4),
        bank.answerWeights(4),
        Random(7),
      );
      return (all, answer);
    }

    testWidgets('the helper shows a dots first, then the real skill', (
      tester,
    ) async {
      final (all, answer) = await setup(tester);
      final guess = all.firstWhere((w) => w != answer);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, random: Random(7)),
        ),
      );
      await tester.pump();
      await type(tester, guess);
      // the best real guess is still being found
      expect(find.textContaining('skill …'), findsOneWidget);

      await tester.pump(const Duration(seconds: 40));
      final law = bank.weightMap(4);
      final land = await tester.runAsync(
        () => analyseGuesses(all, all, weights: law),
      );
      final skill = scoreGuess(
        all,
        guess,
        1,
        best: land!.bestGain,
        triesLeft: appState.tries,
        weights: law,
        afterWords: filterEligible(all, guess, evaluate(answer, guess)),
      ).skill;
      expect(find.textContaining('skill …'), findsNothing);
      expect(
        find.textContaining('skill ${skill.toStringAsFixed(1)}'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets(
      'the end waits for every guess to be analysed before recording',
      (tester) async {
        final (all, answer) = await setup(tester);
        final before = appState.stats.played;
        final wrong = all.where((w) => w != answer).take(3).toList();
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(bank: bank, random: Random(7)),
          ),
        );
        await tester.pump();
        for (final w in wrong) {
          await type(tester, w);
        }
        // three tries used: the game is over, but its skills are not final yet
        expect(find.text('replay'), findsOneWidget);
        expect(appState.stats.played, before, reason: 'not recorded yet');
        expect(find.textContaining('average skill …'), findsOneWidget);

        await tester.pump(const Duration(seconds: 60));
        expect(appState.stats.played, before + 1);
        expect(find.textContaining('average skill …'), findsNothing);
        expect(find.textContaining('average skill'), findsOneWidget);
      },
    );

    testWidgets('a quartet does the same: dots, then the real skill', (
      tester,
    ) async {
      await load(tester);
      appState.setup(mode: GameMode.quartet, share: 10, helper: Helper.full);
      analyseWhilePlaying = true;
      final before = appState.stats.played;
      final answers = chooseTargets(
        bank.answers(4),
        bank.answerWeights(4),
        4,
        10,
        Random(3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MultiGamePage(bank: bank, random: Random(3)),
        ),
      );
      await tester.pump();
      for (final w in answers) {
        await type(tester, w);
      }
      expect(find.text('replay'), findsOneWidget);
      expect(appState.stats.played, before, reason: 'waits for the analysis');
      expect(find.textContaining('average skill …'), findsOneWidget);
      await tester.pump(const Duration(seconds: 90));
      expect(appState.stats.played, before + 1);
      expect(find.textContaining('average skill …'), findsNothing);
      expect(find.textContaining('average skill'), findsOneWidget);
    });
  });

  test('jobs run one after another, in order', () async {
    final queue = JobQueue();
    final order = <int>[];
    var running = 0, peak = 0;
    final futures = [
      for (var i = 0; i < 4; i++)
        queue.add(() async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 3));
          order.add(i);
          running--;
          return i;
        }),
    ];
    expect(await Future.wait(futures), [0, 1, 2, 3]);
    expect(order, [0, 1, 2, 3]);
    expect(peak, 1);
  });
}
