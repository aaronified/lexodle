import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/review_plots.dart';
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
      // the group of the answer is the one that happened
      final key = patternCode('grate', 'crate');
      final size = words.where((w) => patternCode(w, 'crate') == key).length;
      expect(o.sizes[o.landed], size);
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
        expect(o.sizes[o.landed], after.length);
        expect(o.luck, closeTo(m.luck, 1e-9), reason: '$guess vs $answer');
      }
    });
  });

  group('the luck plot puts zero luck in the middle', () {
    test('larger pools fill the left half, smaller the right, in order', () {
      final o = Outcomes([40, 30, 12, 6, 3, 2, 1, 1, 1], 9.5, 4);
      final slots = luckSlots(o, 300);
      expect(slots.map((s) => s.index).toSet().length, o.sizes.length);
      for (final s in slots) {
        expect(s.unlucky, o.sizes[s.index] > o.expected);
        if (s.unlucky) {
          expect(s.x1, lessThanOrEqualTo(150 + 1e-9));
        } else {
          expect(s.x0, greaterThanOrEqualTo(150 - 1e-9));
        }
      }
      // sizes only ever fall from the left to the right
      final byX = [...slots]..sort((a, b) => a.x0.compareTo(b.x0));
      final sizes = [for (final s in byX) o.sizes[s.index]];
      expect(sizes, orderedEquals([...sizes]..sort((a, b) => b - a)));
      // each half is filled edge to edge, with no gap
      expect(byX.first.x0, 0);
      expect(byX.last.x1, closeTo(300, 1e-9));
      for (var i = 0; i + 1 < byX.length; i++) {
        expect(byX[i].x1, closeTo(byX[i + 1].x0, 1e-9));
      }
    });

    test('the pool landed in is on the unlucky side exactly when luck < 0', () {
      for (final landed in [0, 2, 4, 8]) {
        final o = Outcomes([40, 30, 12, 6, 3, 2, 1, 1, 1], 9.5, landed);
        final s = luckSlots(o, 200).firstWhere((s) => s.index == landed);
        expect(s.unlucky, o.luck < 0, reason: 'landed $landed');
        expect(s.center < 100, o.luck < 0);
      }
    });

    test('a side with nothing on it just stays empty', () {
      final o = Outcomes([5, 5, 5], 5, 0); // none above the average
      final slots = luckSlots(o, 100);
      expect(slots.every((s) => !s.unlucky), isTrue);
      expect(slots.first.x0, 50, reason: 'the right half starts at the middle');
    });
  });

  group('ranking among the guesses scored', () {
    final land = Landscape(const [], const [100, 80, 80, 20]);
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
        final m = scoreGuess(eligible, r.word, 1);
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
      answer = chooseWord(
        bank.answers(4, 500),
        bank.answerWeights(4, 500),
        Random(7),
      );
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
      await tester.pump(const Duration(seconds: 20));
    }

    testWidgets('every guess has a skill plot and a luck plot', (tester) async {
      await open(tester, 0);
      expect(find.byKey(const ValueKey('skill-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('luck-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('chance-plot')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('skill-caption'))).data,
        contains('guesses I scored'),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('luck-caption'))).data,
        contains('you landed in ${record.metrics[0].after}'),
      );
      // the luck plot comes before rarity, which is below
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('luck-plot'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('freq-plot'))).dy),
      );

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('skill-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('luck-plot')), findsOneWidget);
    });

    testWidgets('the last try shows one plot: all that fit are as likely', (
      tester,
    ) async {
      await open(tester, 2);
      expect(find.byKey(const ValueKey('chance-plot')), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-plot')), findsNothing);
      expect(find.byKey(const ValueKey('luck-plot')), findsNothing);
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
      // and the colour key sits on its own line below
      expect(
        tester.getRect(find.text('your guess').last).top,
        greaterThan(rarest.bottom - 1),
      );
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

  testWidgets('a crowded luck plot is drawn as an area and still paints', (
    tester,
  ) async {
    final sizes = [for (var i = 300; i >= 1; i--) i];
    final n = sizes.fold<int>(0, (a, b) => a + b);
    final expected = sizes.fold<int>(0, (a, s) => a + s * s) / n;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: LuckPlot(outcomes: Outcomes(sizes, expected, 40)),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('luck-plot')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // far too narrow to be columns: every slot is under 3 px wide
    final w = tester.getSize(find.byKey(const ValueKey('luck-plot'))).width;
    final slots = luckSlots(Outcomes(sizes, expected, 40), w);
    expect(slots.every((s) => s.width < 3), isTrue);
  });
}
