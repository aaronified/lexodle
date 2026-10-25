import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/review.dart';

const c = Mark.correct, p = Mark.present, a = Mark.absent;

void main() {
  group('evaluate', () {
    test(
      'all correct',
      () => expect(evaluate('crane', 'crane'), [c, c, c, c, c]),
    );
    test('repeated letter: the single e goes to the green', () {
      expect(evaluate('crane', 'eerie'), [a, a, p, a, c]);
    });
    test('green takes priority over earlier yellow', () {
      expect(evaluate('abbey', 'babes'), [p, p, c, c, a]);
    });
    test('non-ascii letters', () {
      expect(evaluate('łódka', 'łodzi'), [c, a, c, a, a]);
    });
  });

  group('filterEligible', () {
    const words = ['crane', 'crate', 'grace', 'trace', 'brace'];
    test('keeps only words consistent with feedback', () {
      final m = evaluate('crane', 'crate');
      expect(filterEligible(words, 'crate', m), ['crane']);
    });
    test('always keeps the real answer', () {
      for (final t in words) {
        for (final g in words) {
          expect(filterEligible(words, g, evaluate(t, g)), contains(t));
        }
      }
    });
    test('repeated guess letter does not drop the answer', () {
      // The Python filter dropped 'crane' here (second e scored absent).
      final m = evaluate('crane', 'eerie');
      expect(filterEligible(['crane', 'zzzzz'], 'eerie', m), ['crane']);
    });
  });

  group('luck on the last try', () {
    final three = ['aaaa', 'bbbb', 'cccc'];
    test('three left: +67 for the right one, -33 for a wrong one', () {
      expect(
        scoreGuess(three, 'bbbb', 1, finalTry: true, solved: true).luck,
        closeTo(66.67, .01),
      );
      expect(
        scoreGuess(three, 'aaaa', 2, finalTry: true).luck,
        closeTo(-33.33, .01),
      );
    });
    test('two left: +50 for the right one, -50 for a wrong one', () {
      final two = ['aaaa', 'bbbb'];
      expect(
        scoreGuess(two, 'aaaa', 1, finalTry: true, solved: true).luck,
        closeTo(50, 1e-9),
      );
      expect(
        scoreGuess(two, 'bbbb', 1, finalTry: true).luck,
        closeTo(-50, 1e-9),
      );
    });
    test('one left: nothing to gain for the right one, all lost otherwise', () {
      expect(
        scoreGuess(['aaaa'], 'aaaa', 1, finalTry: true, solved: true).luck,
        0,
      );
      // a guess that cannot win has no chance to be lucky about
      expect(scoreGuess(['aaaa'], 'zzzz', 1, finalTry: true).luck, 0);
    });
    test('a guess that does not fit has luck 0: the loss is its skill', () {
      expect(scoreGuess(three, 'zzzz', 3, finalTry: true).luck, 0);
      expect(scoreGuess(three, 'zzzz', 3, finalTry: true).skill, 0);
    });
    test(
      'over every possible answer it averages exactly 0, fitting or not',
      () {
        final rng = Random(21);
        const alphabet = 'abcdefgh';
        String word() => String.fromCharCodes([
          for (var i = 0; i < 4; i++) alphabet.codeUnitAt(rng.nextInt(8)),
        ]);
        for (var i = 0; i < 300; i++) {
          final field = {for (var k = 0; k < 2 + rng.nextInt(8); k++) word()}
              .toList();
          final guess = rng.nextBool()
              ? field[rng.nextInt(field.length)]
              : word();
          final mean =
              field
                  .map(
                    (answer) => scoreGuess(
                      field,
                      guess,
                      1,
                      finalTry: true,
                      solved: answer == guess,
                    ).luck,
                  )
                  .reduce((a, b) => a + b) /
              field.length;
          expect(mean, closeTo(0, 1e-9), reason: '$guess in $field');
        }
      },
    );
    test('the earlier tries use the pools: where the pool landed in ranks', () {
      // 'aaaa' splits the three into {aaaa} and {bbbb, cccc}; landing in the
      // pair is the likelier outcome and the unluckier one
      expect(scoreGuess(three, 'aaaa', 2).luck, closeTo(-33.33, .01));
      expect(scoreGuess(three, 'aaaa', 1).luck, closeTo(66.67, .01));
      // on the last try a miss is -33 as well, but a hit is the chance of it
      final late = scoreGuess(three, 'bbbb', 1, finalTry: true, solved: true);
      expect(late.luck, closeTo(66.67, .01));
    });
  });

  group('frequency plot data', () {
    test('log heights scaled between the rarest and commonest of the pool', () {
      final w = {'a': 1000, 'b': 100, 'c': 10};
      final h = frequencySeries(['a', 'b', 'c'], w, w.values);
      expect(h, [1.0, closeTo(.5, 1e-9), 0.0]);
    });
    test(
      'a subset shares the pool scale, and an unknown word is the rarest',
      () {
        final w = {'a': 1000, 'b': 100, 'c': 10};
        expect(frequencySeries(['b'], w, w.values), [closeTo(.5, 1e-9)]);
        expect(frequencySeries(['zz'], w, w.values), [0.0]);
      },
    );
    test('a pool of one weight is a flat line', () {
      expect(frequencySeries(['a', 'b'], {'a': 5, 'b': 5}, [5, 5]), [1.0, 1.0]);
    });
  });

  group('skill against the best real guess', () {
    test('0 for no split, 100 for as even as the best real word', () {
      expect(skillAgainst(20, 20, 3), 0);
      expect(skillAgainst(20, 3, 3), 100);
      expect(skillAgainst(20, 6.8, 1), closeTo(36.01, .01));
      // the same guess is worth more when the best a real word can do is worse
      expect(skillAgainst(20, 6.8, 3), closeTo(56.87, .01));
    });

    test('it is on a log scale: each factor of two in E is the same step', () {
      // N = 1024, E* = 1: a guess that leaves 512, 256, ... words on average
      // is worth 10, 20, ... each a tenth of the way
      for (var k = 1; k <= 10; k++) {
        expect(skillAgainst(1024, 1024 / pow(2, k), 1), closeTo(k * 10, 1e-9));
      }
      // the guess that leaves 10% and the one that leaves 1% are far apart,
      // where on a linear scale they would be 99 and 90 apart by a hair
      expect(
        skillAgainst(5000, 5000 / 100, 1) - skillAgainst(5000, 5000 / 10, 1),
        closeTo(100 * log(10) / log(5000), 1e-9),
      );
    });

    test('it is the guess\'s collision entropy as a share of the best\'s', () {
      // H2 = -ln(sum p^2) = ln(N / E), so skill = H2(guess) / H2(best)
      final rng = Random(4);
      for (var i = 0; i < 200; i++) {
        final sizes = [
          for (var k = 0; k < 2 + rng.nextInt(30); k++) 1 + rng.nextInt(50),
        ];
        final n = sizes.fold(0, (a, b) => a + b);
        final e = sizes.fold<int>(0, (a, s) => a + s * s) / n;
        final h2 = -log(sizes.fold<double>(0, (a, s) => a + pow(s / n, 2)));
        final best = 1 + rng.nextDouble() * (e - 1).clamp(0, double.infinity);
        final h2Best = log(n / best);
        if (h2Best <= 1e-9) continue;
        expect(
          skillAgainst(n, e, best),
          closeTo((h2 / h2Best * 100).clamp(0, 100), 1e-9),
        );
      }
    });

    test('a finer split is always worth more', () {
      // refining the partition lowers E, so skill rises (Lemma 1, Proposition 2)
      expect(skillAgainst(100, 10, 2), lessThan(skillAgainst(100, 9, 2)));
      expect(skillAgainst(100, 100, 2), 0);
      expect(skillAgainst(100, 2, 2), 100);
    });

    test('it is clamped to 0 to 100 and a lone word is 100', () {
      expect(skillAgainst(20, 2, 3), 100, reason: 'cannot beat the best');
      expect(skillAgainst(20, 25, 3), 0);
      expect(skillAgainst(1, 1, 1), 100);
      expect(skillAgainst(5, 5, 5), 100, reason: 'no guess splits anything');
    });

    test('scoreGuess takes the best when it knows it', () {
      const field = ['aa', 'ab', 'ac'];
      final absolute = scoreGuess(field, 'ab', 2); // best taken as 1
      expect(absolute.skill, closeTo(53.50, .01));
      expect(absolute.ready, isTrue);
      final relative = scoreGuess(field, 'ab', 2, best: 5 / 3);
      expect(relative.skill, 100, reason: 'it is the best split there is');
      expect(relative.best, closeTo(5 / 3, 1e-9));
      final provisional = scoreGuess(field, 'ab', 2, provisional: true);
      expect(provisional.ready, isFalse);
      expect(provisional.skill, closeTo(53.50, .01));
    });

    test('withBest refines the skill and leaves luck alone', () {
      const field = ['aa', 'ab', 'ac'];
      final p = scoreGuess(field, 'ab', 2, provisional: true);
      final r = p.withBest(5 / 3);
      expect(r.ready, isTrue);
      expect(r.skill, 100);
      expect(r.luck, p.luck);
      expect(r.expected, p.expected);
      expect(r.withBest(5 / 3).skill, 100, reason: 'idempotent');
      // a lone word keeps its 100 or 0
      final hit = scoreGuess(['aa'], 'aa', 1, provisional: true).withBest(1);
      expect(hit.skill, 100);
      expect(hit.ready, isTrue);
      final miss = scoreGuess(['aa'], 'bb', 1, provisional: true).withBest(1);
      expect(miss.skill, 0);
    });

    test(
      'measured against every real guess, the best one scores 100',
      () async {
        const eligible = ['crane', 'crate', 'grate', 'grape', 'shape', 'slate'];
        final land = await analyseGuesses(eligible, [
          ...eligible,
          'light',
          'ounce',
        ]);
        expect(land.skills.first, closeTo(100, 1e-9));
        expect(land.top.first.skill, closeTo(100, 1e-9));
        // E* is the smallest expected pool among the guesses scored
        final lowest = [
          for (final g in [...eligible, 'light', 'ounce'])
            scoreGuess(eligible, g, 1).expected,
        ].reduce((a, b) => a < b ? a : b);
        expect(land.bestExpected, closeTo(lowest, 1e-9));
        // and every guess's skill is its place between N and E*
        for (final g in [...eligible, 'light', 'ounce']) {
          final m = scoreGuess(eligible, g, 1, best: land.bestExpected);
          expect(m.skill, inInclusiveRange(0, 100));
        }
      },
    );
  });

  group('luck is the chance-weighted percentile of the pool landed in', () {
    test('a pool of 19 against a pool of 1', () {
      expect(chanceLuck([19, 1], 19), closeTo(-5, 1e-9)); // the likely outcome
      expect(chanceLuck([19, 1], 1), closeTo(95, 1e-9));
    });

    test('equal pools are all the middle', () {
      expect(chanceLuck([10, 10], 10), 0);
      expect(chanceLuck([5, 5, 5, 5], 5), 0);
      expect(chanceLuck([7], 7), 0, reason: 'only one outcome');
    });

    test('the biggest pool is unluckiest, the smallest luckiest', () {
      final sizes = [641, 521, 328, 23, 6, 1, 1];
      final lucks = [for (final s in sizes) chanceLuck(sizes, s)];
      for (var i = 0; i + 1 < lucks.length; i++) {
        expect(lucks[i], lessThanOrEqualTo(lucks[i + 1]));
      }
      expect(lucks.first, lessThan(-50));
      expect(lucks.last, greaterThan(95));
    });

    test('always between -100 and +100, never reaching either', () {
      final rng = Random(5);
      for (var i = 0; i < 500; i++) {
        final sizes = [
          for (var k = 0; k < 2 + rng.nextInt(40); k++) 1 + rng.nextInt(300),
        ];
        for (final s in sizes) {
          final l = chanceLuck(sizes, s);
          expect(l, greaterThan(-100));
          expect(l, lessThan(100));
        }
      }
    });

    test('over every answer it averages exactly 0, whatever the guess', () {
      final rng = Random(8);
      for (var i = 0; i < 500; i++) {
        final sizes = [
          for (var k = 0; k < 1 + rng.nextInt(60); k++) 1 + rng.nextInt(500),
        ];
        final n = sizes.fold(0, (a, b) => a + b);
        // each word is equally likely to be the answer: a group of s words is
        // landed in with chance s / n
        final mean = sizes.fold<double>(
          0,
          (a, s) => a + s / n * chanceLuck(sizes, s),
        );
        expect(mean, closeTo(0, 1e-9), reason: '$sizes');
      }
    });

    test('scaling every group by the same factor changes nothing', () {
      // the sizes are the chances, so only their proportions count
      final a = [100, 40, 40, 9, 3, 1];
      final b = [for (final s in a) s * 7];
      for (var i = 0; i < a.length; i++) {
        expect(chanceLuck(a, a[i]), closeTo(chanceLuck(b, b[i]), 1e-9));
      }
    });

    test('the order the groups are listed in does not matter', () {
      final a = [30, 9, 9, 4, 1];
      final shuffled = [4, 9, 1, 30, 9];
      for (final s in a) {
        expect(chanceLuck(a, s), closeTo(chanceLuck(shuffled, s), 1e-12));
      }
    });

    test('scoreGuess uses it, and it is bounded for a real field too', () {
      const field = ['aa', 'ab', 'ac'];
      expect(scoreGuess(field, 'ab', 2).luck, chanceLuck([2, 1], 2));
      expect(scoreGuess([], 'ab', 0).luck, 0);
    });
  });

  group('scoreGuess (skill and luck)', () {
    const field = ['aa', 'ab', 'ac'];

    test('a guess that tells nothing: skill 0, luck 0', () {
      final m = scoreGuess(field, 'ad', 3); // every word scores the same
      expect(m.skill, 0);
      expect(m.luck, 0); // the only pool there is is the average pool
    });
    test('a guess that splits the field into singletons has skill 100', () {
      final m = scoreGuess(['aa', 'bb'], 'aa', 1);
      expect(m.skill, 100);
      expect(m.luck, 0); // landed in a pool of 1, and 1 was the average
    });
    test('partial split: skill 53.5 on the log scale; luck is signed against the average pool', () {
      // groups for guess "ab": {aa, ac} and {ab}  ->  E = 5/3
      final unlucky = scoreGuess(field, 'ab', 2);
      expect(unlucky.skill, closeTo(53.50, .01));
      // groups of 2 and 1: landing in the 2 is the likelier outcome (2 in 3),
      // so the chance of a bigger pool is 0 and of a smaller one 1 in 3
      expect(unlucky.luck, closeTo(-33.33, .01));
      final lucky = scoreGuess(field, 'ab', 1);
      // landing in the 1: a bigger pool 2 times in 3, a smaller one never
      expect(lucky.luck, closeTo(66.67, .01));
      expect((lucky.before, lucky.after), (3, 1));
    });
    test('the split is described: groups, biggest group, expected pool', () {
      final m = scoreGuess(field, 'ab', 2);
      expect(m.groups, 2);
      expect(m.largest, 2);
      expect(m.expected, closeTo(5 / 3, 1e-9));
    });
    test('a single remaining word: playing it is 100, anything else is 0; luck 0 either way', () {
      final hit = scoreGuess(['aa'], 'aa', 1);
      expect(hit.skill, 100);
      expect(hit.luck, 0); // 1 - 1/1
      final miss = scoreGuess(['aa'], 'bb', 1);
      expect(miss.skill, 0);
      expect(miss.luck, 0);
    });
    test('luckText: signed, rounded, a real minus sign', () {
      expect(luckText(80.4), '+80%');
      expect(luckText(-44.6), '\u221245%');
      expect(luckText(0.3), '0%');
      expect(luckText(-0.4), '0%');
    });
  });

  test('patternCode agrees with evaluate on every pair of a word set', () {
    const words = [
      'crane',
      'eerie',
      'abbey',
      'babes',
      'speed',
      'erase',
      'llama',
      'aaaaa',
      'level',
      'kebab',
      'sissy',
      'geese',
      'mamma',
      'array',
      'radar',
      'tarta',
    ];
    int pack(List<Mark> m) => m.fold(0, (a, x) => a * 3 + x.index);
    for (final t in words) {
      for (final g in words) {
        expect(patternCode(t, g), pack(evaluate(t, g)), reason: '$t / $g');
      }
    }
  });

  group('review helpers', () {
    test('recommendTop lists the best picks, best first', () async {
      final top = await recommendTop(
        ['aa', 'ab', 'ac'],
        ['ad', 'ab', 'ax'],
        k: 2,
      );
      expect(top.map((r) => r.word), ['ab', 'ad']);
      expect(top.first.skill, greaterThan(top.last.skill));
    });
    test(
      'infoGained matches the NYT screenshot (about 3,100 words at the start)',
      () {
        // 159 left -> 37%, 7 left -> 76%, 1 left -> 100%
        expect(infoGained(3100, 159), closeTo(37, 1.5));
        expect(infoGained(3100, 7), closeTo(76, 1.5));
        expect(infoGained(3100, 1), 100);
        expect(infoGained(1, 1), 100);
      },
    );
    test('ordinal', () {
      expect(
        [ordinal(1), ordinal(3), ordinal(10)],
        ['first', 'third', 'tenth'],
      );
    });

    GuessMetrics gm(
      String g,
      double skill,
      double luck,
      int before,
      int after,
    ) => GuessMetrics(
      guess: g,
      skill: skill,
      luck: luck,
      before: before,
      after: after,
    );
    Recommendation rec(String w, double skill, double e) =>
        Recommendation(w, skill, e, false);

    test('comment: on the last try only a fitting word could win', () {
      final fits = stepComment(
        m: gm('grout', 40, 0, 12, 1),
        picks: [rec('turbo', 90, 1.1)],
        after: ['grout'],
        solved: false,
        finalTry: true,
      );
      expect(fits, contains('Last try'));
      expect(fits, contains('1 in 12'));
      expect(fits, isNot(contains('missed chance')));
      expect(fits, isNot(contains('turbo')));
      final misses = stepComment(
        m: gm('mamma', 40, 0, 12, 5),
        picks: [rec('turbo', 90, 1.1)],
        after: ['a', 'b', 'c', 'd', 'e'],
        solved: false,
        finalTry: true,
        guessFits: false,
      );
      expect(misses, contains('does not fit the clues'));
      expect(misses, isNot(contains('turbo')));
    });

    test('comment: a top pick is praised', () {
      final t = stepComment(
        m: gm('grout', 98, 0, 7, 1),
        picks: [rec('turbo', 99, 1.1), rec('grout', 98, 1.2)],
        after: ['grout'],
        solved: false,
      );
      expect(t, contains('Terrific choice'));
      expect(t, contains('Only one word is left: grout.'));
    });
    test('comment: a weak guess names the better one', () {
      final t = stepComment(
        m: gm('mamma', 30, 0, 400, 280),
        picks: [rec('rates', 95, 20)],
        after: List.filled(280, 'x'),
        solved: false,
      );
      expect(t, contains('A missed chance'));
      expect(t, contains('rates'));
      expect(t, isNot(contains('about')), reason: 'no numbers, no formulas');
    });
    test('comment: luck and few words left are mentioned', () {
      final lucky = stepComment(
        m: gm('crane', 80, 50, 300, 3),
        picks: [rec('crane', 80, 60)],
        after: ['a', 'b', 'c'],
        solved: false,
      );
      // one fact only: the few words left come before the luck
      expect(lucky, contains('Only 3 words are left: a, b, c.'));
      expect(lucky, isNot(contains('lucky')));
      final luckyOnly = stepComment(
        m: gm('crane', 80, 50, 300, 30),
        picks: [rec('crane', 80, 60)],
        after: List.filled(30, 'x'),
        solved: false,
      );
      expect(luckyOnly, contains('You got lucky'));
      final unlucky = stepComment(
        m: gm('crane', 80, -50, 300, 200),
        picks: [rec('crane', 80, 60)],
        after: List.filled(200, 'x'),
        solved: false,
      );
      expect(unlucky, contains('Unlucky'));
    });
    test('comment: solved, and nothing to compare yet', () {
      expect(
        stepComment(
          m: gm('a', 100, 0, 1, 1),
          picks: [],
          after: ['a'],
          solved: true,
        ),
        contains('You solved it'),
      );
      expect(
        stepComment(
          m: gm('a', 50, 0, 10, 5),
          picks: [],
          after: List.filled(5, 'x'),
          solved: false,
        ),
        isEmpty,
      );
    });
  });

  group('risk and daring', () {
    test('a split into equal groups has no risk', () {
      // 8 words in 4 groups of 2: sum c^2 = 16, sum c log2 c = 8
      expect(splitRisk(8, 16, 8), closeTo(0, 1e-12));
      expect(splitRisk(1, 1, 0), 0);
    });

    test('a tail of one big group is risky', () {
      // 8 words as 7 + 1: usually nearly everything is left, once nothing
      final sumSq = 7 * 7 + 1;
      final clogc = 7 * (log(7) / ln2);
      expect(splitRisk(8, sumSq, clogc), closeTo(0.1868, 1e-3));
      // at a fixed size, the more lopsided the two groups, the more risk
      double two(int big) {
        final small = 8 - big;
        return splitRisk(
          8,
          big * big + small * small,
          big * (log(big) / ln2) + (small > 1 ? small * (log(small) / ln2) : 0),
        );
      }

      expect(two(4), closeTo(0, 1e-12)); // equal halves
      expect(two(5), greaterThan(two(4)));
      expect(two(6), greaterThan(two(5)));
      expect(two(7), greaterThan(two(6)));
    });

    test('risk is never negative', () {
      for (final sizes in [
        [1, 1, 1],
        [5],
        [3, 3, 3],
        [10, 1, 1, 1],
        [2, 2, 1, 1, 1, 1],
      ]) {
        final n = sizes.reduce((a, b) => a + b);
        final sq = sizes.fold<int>(0, (a, s) => a + s * s);
        final cl = sizes.fold<double>(0, (a, s) => a + s * (log(s) / ln2));
        expect(splitRisk(n, sq, cl), greaterThanOrEqualTo(0), reason: '$sizes');
      }
    });

    test(
      'daring is going for the whole word, at a cost, with tries to spare',
      () {
        double d(bool p, double w, double s, int t) =>
            daringOf(possible: p, winChance: w, skill: s, triesLeft: t);
        // a probe is not an attempt at the word
        expect(d(false, 0, 40, 5), 0);
        // the last try is the only play
        expect(d(true, 0.1, 40, 1), 0);
        // going for an unlikely word with a poor split, six tries left
        expect(d(true, 0, 0, 6), closeTo(100 * 5 / 6, 1e-9));
        // the best split costs nothing; a sure word is no gamble
        expect(d(true, 0.1, 100, 6), 0);
        expect(d(true, 1, 0, 6), 0);
        // fewer tries to spare, less daring
        expect(d(true, 0.2, 50, 2), closeTo(100 * .5 * .8 * .5, 1e-9));
        expect(d(true, 0.2, 50, 4), greaterThan(d(true, 0.2, 50, 2)));
        // a more likely word is a smaller gamble
        expect(d(true, 0.5, 50, 4), lessThan(d(true, 0.1, 50, 4)));
      },
    );

    test('a guess knows if it could win, and its chance by frequency', () {
      const field = ['aa', 'ab', 'ac', 'bd'];
      final probe = scoreGuess(field, 'zz', 4, triesLeft: 3);
      expect(probe.possible, isFalse);
      expect(probe.winChance, 0);
      expect(probe.triesLeft, 3);
      final even = scoreGuess(field, 'ab', 1, triesLeft: 3);
      expect(even.possible, isTrue);
      expect(even.winChance, closeTo(.25, 1e-9));
      final weighted = scoreGuess(
        field,
        'ab',
        1,
        triesLeft: 3,
        weights: {'aa': 1, 'ab': 6, 'ac': 2, 'bd': 1},
      );
      expect(weighted.winChance, closeTo(.6, 1e-9));
    });

    test(
      'a position scored for real carries its daring once analysed',
      () async {
        const words = [
          'crane',
          'crate',
          'trace',
          'brace',
          'grace',
          'slate',
          'stare',
          'share',
          'shale',
          'whale',
          'while',
          'white',
          'write',
          'wrote',
          'quote',
          'quite',
        ];
        final land = await analyseGuesses(words, words);
        final eligible = List.of(words);
        final after = filterEligible(
          eligible,
          'crane',
          evaluate('trace', 'crane'),
        );
        final m = scoreGuess(
          eligible,
          'crane',
          after.length,
          provisional: true,
          triesLeft: 5,
        );
        expect(m.risk, greaterThanOrEqualTo(0));
        expect(m.daring, isNull, reason: 'not known until the analysis lands');
        final done = m.withLandscape(land);
        expect(done.ready, isTrue);
        expect(done.daring, isNotNull);
        expect(done.daring, inInclusiveRange(0, 100));
        expect(done.best, land.bestExpected);
        expect(done.risk, m.risk, reason: 'the risk is a fact of the guess');
        // without the tries left, daring is not known
        final unknown = scoreGuess(eligible, 'crane', after.length);
        expect(unknown.withLandscape(land).daring, isNull);
      },
    );

    test('with one word left there is no choice to be daring about', () async {
      const words = ['crane', 'crate', 'trace'];
      final land = await analyseGuesses(['crane'], words);
      final m = scoreGuess(['crane'], 'crane', 0, solved: true);
      expect(m.withLandscape(land).daring, isNull);
    });
  });

  group('recommend for the tries left', () {
    const field = ['ab', 'ac', 'ad', 'bc'];

    test(
      'with one try only a word that fits is worth it, the likeliest',
      () async {
        final r = await recommendWithin(
          field,
          ['zz', 'ab', 'ac'],
          1,
          weights: {'ab': 1, 'ac': 5, 'ad': 1, 'bc': 1},
        );
        expect(r!.word, 'ac');
        expect(r.canWin, isTrue);
        expect(r.winChance, closeTo(5 / 8, 1e-9));
        // even when the candidates hold a better splitter that cannot win
        final probe = await recommendWithin(field, ['zz'], 1);
        expect(field, contains(probe!.word));
      },
    );

    test(
      'with two tries it is the guess with the best chance by the last',
      () async {
        // ab splits the four into {ab}, {ac, ad}, {bc}: 3 of 4 solved in time
        final r = await recommendWithin(field, ['zz', 'ab', 'ac'], 2);
        expect(r!.word, 'ab');
        expect(r.winChance, closeTo(.75, 1e-9));
        expect(r.canWin, isTrue);
        // a guess that tells nothing is not chosen over one that does
        final dull = await recommendWithin(field, ['zz', 'ab'], 2);
        expect(dull!.word, 'ab');
        // with weights the likelier word of each group is the one tried next
        final w = await recommendWithin(
          field,
          ['zz', 'ab'],
          2,
          weights: {'ab': 1, 'ac': 1, 'ad': 6, 'bc': 1},
        );
        expect(w!.winChance, closeTo((1 + 6 + 1) / 9, 1e-9));
      },
    );

    test(
      'a guess that cannot be the answer can still be the one for two tries',
      () async {
        // two words that no word of the field can split as well as a probe does
        const two = ['aab', 'aba', 'baa', 'bbb'];
        final r = await recommendWithin(two, ['aab', 'zzz', 'abz'], 2);
        expect(r!.winChance, greaterThanOrEqualTo(.5));
        expect(r.canWin, two.contains(r.word));
      },
    );

    test('with three or more it is the plain recommendation', () async {
      final plain = await recommend(field, ['zz', 'ab', 'ac']);
      for (final t in [3, 6]) {
        final r = await recommendWithin(field, ['zz', 'ab', 'ac'], t);
        expect(r!.word, plain!.word);
        expect(r.winChance, isNull);
      }
    });

    test('nothing left, nothing to recommend', () async {
      expect(await recommendWithin([], ['ab'], 2), isNull);
    });
  });

  group('recommend', () {
    test('picks the guess that splits the field best', () async {
      final r = await recommend(['aa', 'ab', 'ac'], ['ad', 'ab', 'ax']);
      expect(r!.word, 'ab');
      expect(r.expected, closeTo(5 / 3, 1e-9));
      // measured against the best real guess, and this is it
      expect(r.skill, closeTo(100, 1e-9));
      expect(r.canWin, isTrue);
    });
    test('a possible answer wins a tie against an impossible word', () async {
      // "ab" and "zb" split ['ab','ac','ad'] identically; "ab" can be the answer
      final r = await recommend(['ab', 'ac', 'ad'], ['zb', 'ab']);
      expect(r!.word, 'ab');
    });
    test('with two left, names the likelier (first) one', () async {
      expect((await recommend(['xx', 'yy'], ['zz']))!.word, 'xx');
    });
    test('nothing left, nothing to recommend', () async {
      expect(await recommend([], ['aa']), isNull);
    });
  });

  test('chooseWord respects weights', () {
    final rng = Random(1);
    final picks = [
      for (var i = 0; i < 500; i++) chooseWord(['a', 'b'], [99, 1], rng),
    ];
    expect(picks.where((w) => w == 'a').length, greaterThan(450));
  });
}
