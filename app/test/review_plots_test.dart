import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/review_plots.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';

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

    test('groups by pattern; the answer picks the group landed in', () {
      final o = outcomesOf(words, 'crate', 'grate');
      expect(o.words, words.length);
      expect(o.sizes, orderedEquals([...o.sizes]..sort((a, b) => b - a)));
      final key = patternCode('grate', 'crate');
      final size = words.where((w) => patternCode(w, 'crate') == key).length;
      expect(o.pool, size);
    });

    test('expected pool and luck are the table\'s numbers', () {
      for (final (guess, answer) in [
        ('crate', 'grate'),
        ('slate', 'shape'),
        ('crane', 'stale'),
      ]) {
        final o = outcomesOf(words, guess, answer);
        final marks = evaluate(answer, guess);
        final after = filterEligible(words, guess, marks);
        final m = scoreGuess(words, guess, after.length);
        expect(o.expected, closeTo(m.expected, 1e-9));
        expect(o.pool, after.length);
        expect(o.luck, closeTo(m.luck, 1e-9), reason: '$guess vs $answer');
      }
    });

    test('the chances of a bigger and a smaller pool give the luck', () {
      final o = Outcomes([40, 30, 12, 6, 3, 2, 1, 1, 1], 9.5, 3);
      expect(o.words, 96);
      expect(o.chanceBigger, closeTo((40 + 30 + 12) / 96 * 100, 1e-9));
      expect(o.chanceSmaller, closeTo((3 + 2 + 1 + 1 + 1) / 96 * 100, 1e-9));
      expect(o.luck, closeTo(o.chanceBigger - o.chanceSmaller, 1e-9));
    });
  });

  group('the columns of the plot', () {
    final o = Outcomes([40, 30, 12, 6, 3, 2, 1, 1, 1], 9.5, 4);

    test('each is as wide as its chance and they fill the plot', () {
      final slots = splitSlots(o, 480);
      expect(slots.length, o.sizes.length);
      expect(slots.first.x0, 0);
      expect(slots.last.x1, closeTo(480, 1e-9));
      for (final s in slots) {
        expect(s.width, closeTo(o.sizes[s.index] / o.words * 480, 1e-9));
      }
      for (var i = 0; i + 1 < slots.length; i++) {
        expect(slots[i].x1, closeTo(slots[i + 1].x0, 1e-9), reason: 'no gap');
      }
    });

    test('the biggest pools are on the left, the smallest on the right', () {
      final slots = splitSlots(o, 300);
      for (var i = 0; i + 1 < slots.length; i++) {
        expect(
          o.sizes[slots[i].index],
          greaterThanOrEqualTo(o.sizes[slots[i + 1].index]),
        );
      }
    });

    test('how far a column\'s centre is from the middle is its luck', () {
      // for a pool no other group shares, luck = 2 * (centre / width) - 1
      final sizes = [60, 25, 9, 4, 2];
      final oo = Outcomes(sizes, 0, 0);
      final slots = splitSlots(oo, 1000);
      for (final s in slots) {
        final luck = chanceLuck(sizes, sizes[s.index]);
        expect(luck / 100, closeTo(2 * s.center / 1000 - 1, 1e-9));
      }
    });

    test('the median outcome sits at the middle: zero luck', () {
      final sizes = [10, 10, 10, 10, 10];
      final slots = splitSlots(Outcomes(sizes, 10, 2), 500);
      expect(slots[2].center, closeTo(250, 1e-9));
      expect(chanceLuck(sizes, 10), 0);
    });
  });

  group('ranking among the guesses scored', () {
    const land = Landscape([], [100, 80, 80, 20]);
    test('rank is how many scored more', () {
      expect(land.rankOf(100), 0);
      expect(land.rankOf(80), 1);
      expect(land.rankOf(20), 3);
      expect(land.rankOf(50), 3);
    });
    test('percentile counts the ones beaten, and half the ties', () {
      expect(land.percentile(100), (3 + 0.5) / 4 * 100);
      expect(land.percentile(80), 50);
      expect(land.percentile(20), 12.5);
      expect(land.percentile(0), 0);
    });
  });

  group('skill does not depend on the answer', () {
    test(
      'the ranking is a function of the words left and the guesses only',
      () async {
        final left = ['abcd', 'abdc', 'acbd'];
        final candidates = [...left, 'wxyz', 'zzzz'];
        final land = await analyseGuesses(left, candidates);
        // there is no answer to pass in: whichever of the three it is, the
        // skill is the same, whatever pool the answer lands you in
        for (final answer in left) {
          for (final g in candidates) {
            final after = filterEligible(left, g, evaluate(answer, g)).length;
            final m = scoreGuess(left, g, after, best: land.bestExpected);
            expect(
              m.skill,
              closeTo(
                scoreGuess(left, g, 1, best: land.bestExpected).skill,
                1e-9,
              ),
              reason: '$g, answer $answer',
            );
          }
        }
        expect(land.skills.first, closeTo(100, 1e-9));
      },
    );

    test(
      'guesses that split the rest equally tie, in a stable order',
      () async {
        final left = ['abcd', 'abdc', 'acbd'];
        final land = await analyseGuesses(left, [...left, 'zzzz', 'wxyz']);
        expect(land.skills.take(3), everyElement(closeTo(100, 1e-9)));
        expect(land.tiedForBest, 3);
        expect(land.top.map((r) => r.word), ['abcd', 'abdc', 'acbd']);
        expect(land.top.every((r) => r.canWin), isTrue);
      },
    );
  });

  group('scoring every candidate', () {
    final eligible = [
      'crane',
      'crate',
      'grate',
      'grape',
      'shape',
      'slate',
      'stale',
      'trace',
    ];
    final candidates = [...eligible, 'ounce', 'light', 'crone'];

    test('the skills are kept, best first, and match the picks', () async {
      final land = await analyseGuesses(eligible, candidates);
      expect(land.skills.length, candidates.length);
      expect(
        land.skills,
        orderedEquals([...land.skills]..sort((a, b) => b.compareTo(a))),
      );
      expect(land.top.first.skill, closeTo(land.skills.first, 1e-9));
      expect(land.skills.first, closeTo(100, 1e-9));
      expect(
        (await recommendTop(eligible, candidates)).map((r) => r.word),
        land.top.map((r) => r.word),
      );
    });

    test('each candidate\'s skill is what scoring that guess says', () async {
      final land = await analyseGuesses(
        eligible,
        candidates,
        k: candidates.length,
      );
      for (final r in land.top) {
        final m = scoreGuess(eligible, r.word, 1, best: land.bestExpected);
        expect(r.skill, closeTo(m.skill, 1e-9), reason: r.word);
      }
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

    testWidgets('every guess has the one plot of skill and luck', (
      tester,
    ) async {
      await open(tester, 0);
      expect(find.byKey(const ValueKey('split-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('chance-plot')), findsNothing);
      // the old second plot is gone
      expect(find.byKey(const ValueKey('skill-plot')), findsNothing);
      expect(find.byKey(const ValueKey('luck-plot')), findsNothing);
      final skillText = tester
          .widget<Text>(find.byKey(const ValueKey('skill-caption')))
          .data!;
      expect(skillText, contains('the best real guess about'));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('luck-caption'))).data,
        contains('you landed in ${record.metrics[0].after}'),
      );
      // the plot comes before rarity, which is below
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('split-plot'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('freq-plot'))).dy),
      );

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('split-plot')), findsOneWidget);
    });

    testWidgets('skill in the table is measured against the best real guess', (
      tester,
    ) async {
      await open(tester, 0);
      final shown = find.byWidgetPredicate(
        (w) => w is Text && w.key != null && '${w.key}'.contains('yours-skill'),
      );
      expect(shown, findsOneWidget);
      final value = int.parse(tester.widget<Text>(shown).data!);
      expect(value, inInclusiveRange(0, 100));
      // and it is what the formula gives against the best of every guess
      final land = await tester.runAsync(
        () => analyseGuesses(record.befores[0], bank.guessable(4)),
      );
      final expected = record.metrics[0].withBest(land!.bestExpected).skill;
      expect(value, expected.round());
    });

    testWidgets('the last try shows one plot: all that fit are as likely', (
      tester,
    ) async {
      await open(tester, 2);
      expect(find.byKey(const ValueKey('chance-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('split-plot')), findsNothing);
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('chance-caption')))
          .data!;
      expect(text, contains('1 in ${fitting.length}'));
      expect(text, contains('your guess was one of them'));
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
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

    testWidgets('the highlighted row stands off its tiles and numbers', (
      tester,
    ) async {
      await open(tester, 0);
      final row = tester.getRect(find.byKey(const ValueKey('row-0')));
      final inside = [
        for (final f in [
          find.descendant(
            of: find.byKey(const ValueKey('row-0')),
            matching: find.byType(MarkTile),
          ),
          find.descendant(
            of: find.byKey(const ValueKey('row-0')),
            matching: find.byType(Text),
          ),
        ])
          for (final e in f.evaluate()) tester.getRect(find.byWidget(e.widget)),
      ];
      expect(inside, isNotEmpty);
      final left = inside.map((r) => r.left).reduce(min);
      final right = inside.map((r) => r.right).reduce(max);
      final top = inside.map((r) => r.top).reduce(min);
      final bottom = inside.map((r) => r.bottom).reduce(max);
      expect(left - row.left, greaterThanOrEqualTo(8));
      expect(row.right - right, greaterThanOrEqualTo(8));
      expect(top - row.top, greaterThanOrEqualTo(5));
      expect(row.bottom - bottom, greaterThanOrEqualTo(5));
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

  group('the plot itself', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );

    testWidgets('says what skill and luck are, in numbers', (tester) async {
      const o = Outcomes([60, 25, 9, 4, 2], 38.6, 1);
      await tester.pumpWidget(
        host(const SplitPlot(outcomes: o, best: 4.0, skill: 62, luck: 20)),
      );
      final skill = tester
          .widget<Text>(find.byKey(const ValueKey('skill-caption')))
          .data!;
      expect(skill, contains('skill 62'));
      // what it is about: how evenly the guess split the words, into how many
      // groups and how big the biggest, and what that means for the words left
      expect(skill, contains('how evenly and finely'));
      expect(skill, contains('split the 100 possible words'));
      expect(skill, contains('made 5 groups, the biggest holding 60'));
      expect(skill, contains('about 39'));
      expect(skill, contains('no split at all would leave 100'));
      expect(skill, contains('the best real guess about 4.0'));
      // and it does not read as an average group size
      expect(skill, isNot(contains('on average')));
      final luck = tester
          .widget<Text>(find.byKey(const ValueKey('luck-caption')))
          .data!;
      expect(luck, contains('you landed in 25 words'));
      expect(luck, contains('luck +20%'));
      expect(luck, contains('bigger pool 60% of the time'));
      expect(luck, contains('smaller one 15%'));
      expect(find.text('0% luck'), findsOneWidget);
    });

    testWidgets('while the best guess is being found it says so', (
      tester,
    ) async {
      const o = Outcomes([60, 25, 9, 4, 2], 38.6, 1);
      await tester.pumpWidget(
        host(
          const SplitPlot(
            outcomes: o,
            best: 1,
            skill: 62,
            luck: 20,
            skillReady: false,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('skill-caption'))).data,
        contains('working out the best real guess'),
      );
    });

    testWidgets('a crowded plot still paints, and the landing is marked', (
      tester,
    ) async {
      final sizes = [for (var i = 300; i >= 1; i--) i];
      final n = sizes.fold<int>(0, (a, b) => a + b);
      final expected = sizes.fold<int>(0, (a, s) => a + s * s) / n;
      final o = Outcomes(sizes, expected, 40);
      await tester.pumpWidget(
        host(SplitPlot(outcomes: o, best: 60, skill: 50, luck: o.luck)),
      );
      expect(find.byKey(const ValueKey('split-plot')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final w = tester.getSize(find.byKey(const ValueKey('split-plot'))).width;
      final slots = splitSlots(o, w);
      expect(slots.length, 300);
      // far too many to be told apart as columns: the thin ones form one area
      expect(slots.where((s) => s.width < 3).length, greaterThan(250));
    });
  });
}
