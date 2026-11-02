import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/closing.dart';
import 'package:lexodle/drill.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The classic trap: seven words that differ in one letter. Playing one of them
  // can win now but leaves the other six looking alike.
  const fit = ['batch', 'catch', 'hatch', 'latch', 'match', 'patch', 'watch'];
  // a probe that is not one of them: b, l, m, p, w tell the words apart, except
  // catch and hatch, which it cannot
  const probe = 'blmpw';

  test('with one try, the likeliest word is all there is', () {
    expect(bestWinMass(fit, 1, const [probe], null), 1);
    expect(winChance(fit, 'batch', 1, const [], null), closeTo(1 / 7, 1e-9));
    expect(winChance(fit, probe, 1, const [], null), 0);
  });

  test('with two tries, a word that fits wins little, a probe wins most', () {
    // batch wins itself, then the six that look alike are a coin toss of one
    expect(winChance(fit, 'batch', 2, const [], null), closeTo(2 / 7, 1e-9));
    // the probe splits them: five are found next, catch and hatch by one of two
    expect(winChance(fit, probe, 2, const [], null), closeTo(6 / 7, 1e-9));
    expect(bestWinMass(fit, 2, const [probe], null), 6);
    // without the probe the best word that fits is the best there is
    expect(bestWinMass(fit, 2, const [], null), 2);
  });

  test('with three tries, the probe finds all of them', () {
    expect(winChance(fit, probe, 3, const [], null), closeTo(1, 1e-9));
    // playing a word that fits first still leaves a probe for the rest
    expect(
      winChance(fit, 'batch', 3, const [probe], null),
      closeTo(6 / 7, 1e-9),
    );
    // and the best of all is the probe, at three tries
    expect(bestWinMass(fit, 3, const [probe], null), 7);
  });

  test('the likelier words count for more when they are weighted', () {
    final law = {for (final w in fit) w: w == 'batch' ? 100 : 1};
    // batch is nearly certain, so playing it now is nearly right
    expect(winChance(fit, 'batch', 2, const [], law), greaterThan(0.9));
    expect(
      winChance(fit, 'batch', 2, const [], law),
      greaterThan(winChance(fit, 'batch', 2, const [], null) * 3),
    );
  });

  test('one word left is won with it; none is not won', () {
    expect(bestWinMass(['batch'], 2, const [], null), 1);
    expect(bestWinMass(const [], 2, const [], null), 0);
    expect(winMass(fit, 'batch', 0, const [], null), 0);
    expect(winChance(const [], 'batch', 2, const [], null), 0);
  });

  test('more tries never win less', () {
    for (final g in [...fit, probe]) {
      var last = 0.0;
      for (var t = 1; t <= 3; t++) {
        final w = winChance(fit, g, t, const [probe], null);
        expect(w, greaterThanOrEqualTo(last - 1e-9), reason: '$g at $t');
        last = w;
      }
    }
  });

  test('the probes are the words that split the fitting words best', () {
    final probes = closingProbeWords(fit, [
      ...fit,
      probe,
      'zzzzz',
      'abcde',
    ], null);
    expect(
      probes,
      isNot(contains('batch')),
      reason: 'those that fit are tried anyway',
    );
    expect(probes.first, probe);
    expect(probes.length, lessThanOrEqualTo(closingProbes));
    expect(closingProbeWords(const ['batch'], [probe], null), isEmpty);
  });

  group('closing questions', () {
    test('four options: the best, and three clearly worse', () {
      final wins = {
        probe: 0.857,
        'batch': 0.286,
        'catch': 0.286,
        'hatch': 0.286,
        'latch': 0.286,
        'zzzzz': 0.0,
      };
      final o = pickClosingOptions(wins, Random(1))!;
      expect(o, hasLength(4));
      expect({for (final x in o) x.word}, hasLength(4));
      final best = o.firstWhere((x) => x.skill >= 99.99);
      expect(best.word, probe);
      expect(best.win, 0.857);
      for (final x in o.where((x) => x != best)) {
        expect(x.win!, lessThan(0.857 - 0.02));
        expect(x.skill, closeTo(x.win! / 0.857 * 100, 1e-9));
      }
    });

    test('a position where nothing is clearly worse is no choice', () {
      expect(
        pickClosingOptions({'a': 0.5, 'b': 0.5, 'c': 0.49}, Random(1)),
        isNull,
      );
      expect(pickClosingOptions(const {}, Random(1)), isNull);
      expect(pickClosingOptions({'a': 0.0, 'b': 0.0}, Random(1)), isNull);
    });

    testWidgets('a built position has few words, tries, and an exact best', (
      tester,
    ) async {
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      for (var seed = 0; seed < 4; seed++) {
        final q = (await tester.runAsync(
          () => buildClosingQuestion(
            bank: bank,
            length: 4,
            draw: Draw.sigmoid,
            rng: Random(seed),
          ),
        ))!;
        expect(q.closing, isTrue);
        expect(q.triesLeft, inInclusiveRange(2, 3));
        expect(
          q.eligible.length,
          inInclusiveRange(3, 10),
          reason: 'seed $seed',
        );
        expect(q.eligible, contains(q.answer));
        expect(q.options, hasLength(4));
        expect(q.options.where(q.isRight), hasLength(greaterThanOrEqualTo(1)));
        for (final o in q.options) {
          expect(q.guesses, isNot(contains(o.word)));
          expect(o.win, inInclusiveRange(0, 1));
        }
        // the chance shown is the exact one for the position
        final best = q.options.firstWhere(q.isRight);
        final top = q.options.map((o) => o.win!).reduce(max);
        expect(best.win, closeTo(top, 1e-12));
        // and the explanation names both, with the chance in time
        final worse = q.options.firstWhere((o) => !q.isRight(o));
        final lines = q.closingLines(worse);
        expect(lines, hasLength(5));
        expect(lines[0], startsWith('${worse.word}: '));
        expect(lines[1], startsWith('${best.word}: '));
        expect(lines[0], contains('wins within ${q.triesLeft} tries in '));
        expect(lines[3], startsWith('style: '));
        expect(lines[4], startsWith('the best, ${best.word}, counts as '));
        final good = q.closingLines(best);
        expect(good, hasLength(3));
        expect(good[2], startsWith('style: '));
      }
    });
  });
}
