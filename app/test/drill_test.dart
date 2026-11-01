import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const words = [
    'bake',
    'cake',
    'fake',
    'lake',
    'make',
    'rake',
    'take',
    'wake',
  ];
  const probes = [
    ...words,
    'flit',
    'crow',
    'mura',
    'plum',
    'gnus',
    'bark',
    'cola',
    'pale',
    'mode',
  ];

  group('pickOptions', () {
    Future<List<DrillOption>> options(int seed) async {
      final land = await analyseGuesses(words, probes, k: 3);
      return pickOptions(
        eligible: words,
        candidates: probes,
        best: land.top.first.word,
        bestGain: land.bestGain,
        weights: null,
        rng: Random(seed),
      );
    }

    test('offers four different words, one of them the best', () async {
      final o = await options(1);
      expect(o, hasLength(4));
      expect({for (final x in o) x.word}, hasLength(4));
      expect(o.where((x) => x.skill >= 99.99), hasLength(1));
      expect(o.map((x) => x.skill).reduce(max), closeTo(100, 0.01));
    });

    test('the worse ones are clearly worse, and not all alike', () async {
      final o = await options(2);
      final worse = [
        for (final x in o)
          if (x.skill < 99.5) x.skill,
      ]..sort();
      expect(worse, hasLength(3));
      expect(worse.last - worse.first, greaterThan(2));
    });

    test(
      'the same seed gives the same options, another gives another order',
      () async {
        final a = [for (final x in await options(3)) x.word];
        final b = [for (final x in await options(3)) x.word];
        expect(a, b);
        final orders = {
          for (var s = 0; s < 12; s++)
            [for (final x in await options(s)) x.word].join(),
        };
        expect(orders.length, greaterThan(1));
      },
    );

    test('a position with too few words gives fewer than four', () async {
      final land = await analyseGuesses(
        ['bake', 'cake'],
        ['bake', 'cake'],
        k: 3,
      );
      final o = pickOptions(
        eligible: ['bake', 'cake'],
        candidates: ['bake', 'cake'],
        best: land.top.first.word,
        bestGain: land.bestGain,
        weights: null,
        rng: Random(1),
      );
      expect(o.length, lessThan(4));
    });
  });

  group('buildDrillQuestion', () {
    Future<WordBank> fr(WidgetTester? t) async => WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
    );

    testWidgets('a position has clues, words that fit, and a best option', (
      tester,
    ) async {
      final bank = (await tester.runAsync(() => fr(tester)))!;
      final q = (await tester.runAsync(
        () => buildDrillQuestion(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          rng: Random(5),
        ),
      ))!;
      expect(q.guesses, isNotEmpty);
      expect(q.guesses.length, q.marks.length);
      expect(q.eligible.length, inInclusiveRange(8, 1500));
      // the answer is still possible, and every clue agrees with it
      expect(q.eligible, contains(q.answer));
      for (var i = 0; i < q.guesses.length; i++) {
        expect(q.marks[i], evaluate(q.answer, q.guesses[i]));
      }
      expect(q.options, hasLength(4));
      final best = q.options.firstWhere((o) => o.skill >= 99.99);
      expect(q.isRight(best), isTrue);
      expect(q.options.where(q.isRight), hasLength(1));
      // choosing a worse one is wrong, and its report says why
      final worse = q.options.firstWhere((o) => o != best);
      expect(q.isRight(worse), isFalse);
      final r = q.report(worse);
      expect(r.guess, worse.word);
      expect(r.skill, closeTo(worse.skill, 0.5));
      expect(r.bestWord, best.word);
    });

    testWidgets('a word already played in the position is never offered', (
      tester,
    ) async {
      final bank = (await tester.runAsync(() => fr(tester)))!;
      for (var seed = 0; seed < 6; seed++) {
        final q = (await tester.runAsync(
          () => buildDrillQuestion(
            bank: bank,
            length: 4,
            draw: Draw.sigmoid,
            rng: Random(seed),
          ),
        ))!;
        for (final o in q.options) {
          expect(q.guesses, isNot(contains(o.word)), reason: 'seed $seed');
          // and every option splits the words at least a little
          expect(q.walk(o).groups.length, greaterThan(1), reason: o.word);
        }
      }
    });

    testWidgets('an opener question has no clues and every word fitting', (
      tester,
    ) async {
      final bank = (await tester.runAsync(() => fr(tester)))!;
      final q = (await tester.runAsync(
        () => buildOpenerQuestion(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          rng: Random(2),
        ),
      ))!;
      expect(q.guesses, isEmpty);
      expect(q.marks, isEmpty);
      expect(q.eligible.length, bank.guessable(4).length);
      expect(q.options, hasLength(4));
      expect(q.options.where(q.isRight), hasLength(1));
      // the same analysis is reused when it is handed back
      final again = (await tester.runAsync(
        () => buildOpenerQuestion(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          rng: Random(3),
          landscape: q.landscape,
        ),
      ))!;
      expect(identical(again.landscape, q.landscape), isTrue);
      expect(
        again.options.firstWhere(again.isRight).word,
        q.options.firstWhere(q.isRight).word,
        reason: 'the best opener does not change',
      );
    });
  });

  test('a round becomes the event the log keeps', () {
    final round = DrillRound('fr', 5, [
      const DrillAnswer('a', 100, true),
      const DrillAnswer('b', 60, false),
    ], kind: LearnKind.opener);
    final e = round.toEvent('2026-11-01');
    expect(e.kind, LearnKind.opener);
    expect(e.language, 'fr');
    expect(e.length, 5);
    expect(e.date, '2026-11-01');
    expect(e.questions, 2);
    expect(e.right, 1);
    expect(e.avgSkill, 80);
    expect(round.complete, isFalse);
    expect(roundLengthOf(LearnKind.opener), 5);
    expect(roundLengthOf(LearnKind.choose), drillRoundLength);
  });
}
