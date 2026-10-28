import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/review_plots.dart';
import 'package:lexodle/words.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('outcomes of a guess', () {
    final words = [
      'crane',
      'crate',
      'grate',
      'grape',
      'shape',
      'slate',
      'stale',
    ];

    test(
      'groups by pattern, biggest first; the answer picks the one landed',
      () {
        final o = outcomesOf(words, 'crate', 'grate', null);
        final chances = o.outcomes.map((x) => x.chance).toList();
        expect(chances.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
        for (var k = 1; k < chances.length; k++) {
          expect(chances[k - 1], greaterThanOrEqualTo(chances[k]));
        }
        expect(o.landed, inInclusiveRange(0, o.outcomes.length - 1));
      },
    );

    test('the gain of an outcome is minus the log of its chance', () {
      final o = outcomesOf(words, 'crate', 'grate', null);
      for (final x in o.outcomes) {
        expect(x.gain, closeTo(-log(x.chance) / ln2, 1e-9));
      }
    });

    test('weights make a common word\'s group likelier', () {
      final w = {for (final x in words) x: 1, 'slate': 100};
      final o = outcomesOf(words, 'crate', 'slate', w);
      expect(o.outcomes[o.landed].chance, greaterThan(.5));
    });
  });

  group('on the review screen', () {
    late WordBank bank;
    late List<String> pool, guesses, fitting;
    late String answer;
    late GameRecord record;

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      );
      pool = bank.guessable(4);
      answer = chooseWord(bank.answers(4), bank.answerWeights(4), Random(7));
      var eligible = pool;
      guesses = [pool[10], pool[20]];
      final marks = <List<Mark>>[], metrics = <GuessMetrics>[];
      final befores = <List<String>>[];
      void play(String g, {bool last = false}) {
        final m = evaluate(answer, g);
        final after = filterEligible(eligible, g, m);
        metrics.add(
          scoreGuess(
            eligible,
            g,
            after.length,
            finalTry: last,
            solved: g == answer,
            provisional: true,
          ),
        );
        befores.add(eligible);
        marks.add(m);
        eligible = after;
      }

      guesses.forEach(play);
      final third = eligible.firstWhere((w) => w != answer);
      guesses.add(third);
      fitting = List.of(eligible);
      play(third, last: true);
      record = GameRecord(
        bank: bank,
        length: 4,
        poolSize: 500,
        answer: answer,
        guesses: guesses,
        marks: marks,
        metrics: metrics,
        befores: befores,
        finalEligible: eligible,
        won: false,
        tries: 3,
      );
    });

    Future<void> open(WidgetTester tester, int step) async {
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: ReviewPage(record: record, initialStep: step),
        ),
      );
      await tester.pump(const Duration(seconds: 40));
    }

    testWidgets('every guess has the one plot of skill, risk and luck', (
      tester,
    ) async {
      await open(tester, 0);
      expect(find.byKey(const ValueKey('gain-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('bits-waterfall')), findsOneWidget);
      expect(find.byKey(const ValueKey('chance-plot')), findsNothing);
      // the plot comes before rarity, which is below
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('gain-plot'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('freq-plot'))).dy),
      );
      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gain-plot')), findsOneWidget);
    });

    testWidgets('the four pills show skill, luck, risk and bits', (
      tester,
    ) async {
      await open(tester, record.guesses.length - 1);
      for (final k in ['skill', 'luck', 'risk', 'bits']) {
        expect(find.byKey(ValueKey('pill-$k')), findsOneWidget, reason: k);
      }
      final skill = int.parse(
        textOf(
          tester.widget<Text>(find.byKey(const ValueKey('pill-value-skill'))),
        )!,
      );
      expect(skill, inInclusiveRange(0, 100));
      // the pill is the game's: the mean of the skills in the table
      final rows = [
        for (var i = 0; i < record.guesses.length; i++)
          double.parse(
            textOf(tester.widget<Text>(find.byKey(ValueKey('skill-$i'))))!,
          ),
      ];
      expect(skill, closeTo(rows.reduce((a, b) => a + b) / rows.length, 1));
      await tester.tap(find.byKey(const ValueKey('pill-skill')));
      await tester.pumpAndSettle();
      expect(find.textContaining('expected to gain'), findsOneWidget);
    });

    testWidgets('the table shows words before and after, skill and risk', (
      tester,
    ) async {
      await open(tester, 0);
      final m = record.metrics[0];
      expect(
        textOf(tester.widget<Text>(find.byKey(const ValueKey('words-0')))),
        '${m.before}→${m.after}',
      );
      expect(find.byKey(const ValueKey('head-skill')), findsOneWidget);
      expect(find.byKey(const ValueKey('head-risk')), findsOneWidget);
      expect(find.byKey(const ValueKey('head-luck')), findsNothing);
    });

    testWidgets('three lists of picks stand side by side', (tester) async {
      await open(tester, 0);
      final a = tester.getTopLeft(find.text('best skill')).dy;
      final b = tester.getTopLeft(find.text('top risk')).dy;
      final c = tester.getTopLeft(find.text('luckiest')).dy;
      expect(b, a);
      expect(c, a);
    });

    testWidgets('the last try shows one plot: all that fit are as likely', (
      tester,
    ) async {
      await open(tester, 2);
      expect(find.byKey(const ValueKey('chance-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('gain-plot')), findsNothing);
      final text = textOf(
        tester.widget<Text>(find.byKey(const ValueKey('chance-caption'))),
      )!;
      expect(text, contains('only a word that fits can win'));
      final luck = textOf(
        tester.widget<Text>(find.byKey(const ValueKey('chance-luck'))),
      )!;
      expect(luck, contains('${fitting.length} words that fit'));
    });

    testWidgets('rarest is at the right end of the rarity plot', (
      tester,
    ) async {
      await open(tester, 0);
      final plot = tester.getRect(find.byKey(const ValueKey('freq-plot')));
      final rarest = tester.getRect(find.text('rarest'));
      final common = tester.getRect(find.text('most common'));
      expect(rarest.right, closeTo(plot.right, 1));
      expect(common.left, closeTo(plot.left, 1));
    });

    testWidgets('clicking a row of the board goes to that guess', (
      tester,
    ) async {
      await open(tester, 0);
      expect(find.text('your first guess'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('row-2')));
      await tester.pumpAndSettle();
      expect(find.text('your third guess'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('row-1')));
      await tester.pumpAndSettle();
      expect(find.text('your second guess'), findsOneWidget);
    });
  });

  group('the plots', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );

    testWidgets('a crowded gain plot still paints', (tester) async {
      final chances = [for (var i = 300; i >= 1; i--) i.toDouble()];
      final total = chances.fold<double>(0, (a, b) => a + b);
      final o = [
        for (final c in chances) Outcome(c / total, -log(c / total) / ln2),
      ];
      final h = o.fold<double>(0, (a, x) => a + x.chance * x.gain);
      await tester.pumpWidget(
        host(
          GainPlot(
            outcomes: o,
            landed: 40,
            expected: h,
            best: h + 1,
            word: 'crane',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('gain-plot')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bits waterfall paints every step', (tester) async {
      await tester.pumpWidget(
        host(
          const BitsWaterfall(
            steps: [
              WaterfallStep('crane', 5.1, 6.0, 5.8),
              WaterfallStep('slimy', 3.0, 2.0, 3.3),
            ],
            needed: 11.5,
            current: 1,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('bits-waterfall')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
