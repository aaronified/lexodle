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

  group('skill is the expected gain against the best real guess', () {
    const field = ['aa', 'ab', 'ac'];
    // 'ab' splits the three words into {ab} and {aa, ac}
    final h = -(1 / 3) * log(1 / 3) / ln2 - (2 / 3) * log(2 / 3) / ln2;

    test('0 for no gain, 100 for the best, on a straight scale', () {
      expect(skillOf(0, 3), 0);
      expect(skillOf(3, 3), 100);
      expect(skillOf(1.5, 3), 50);
      expect(skillOf(4, 3), 100, reason: 'cannot beat the best');
      expect(skillOf(0, 0), 100, reason: 'no guess gains anything');
    });

    test('the expected gain is the entropy of the split, in bits', () {
      final m = scoreGuess(field, 'ab', 2);
      expect(m.expectedGain, closeTo(h, 1e-9));
      // a split into singletons gains log2 of the words
      expect(
        scoreGuess(const ['aa', 'ab', 'ba', 'bb'], 'ab', 1).expectedGain,
        closeTo(2, 1e-9),
        reason: 'four equal groups',
      );
      expect(scoreGuess(field, 'zz', 3).expectedGain, 0);
    });

    test('a finer split is always worth more', () {
      final coarse = scoreGuess(field, 'ab', 2).expectedGain;
      final fine = scoreGuess(const ['aa', 'ab', 'ba'], 'ab', 1).expectedGain;
      expect(fine, greaterThan(coarse));
    });

    test('scoreGuess takes the best when it knows it', () {
      final provisional = scoreGuess(field, 'ab', 2, provisional: true);
      expect(provisional.ready, isFalse);
      // until H* is known it is the finest split, every word alone: log2 3
      expect(provisional.skill, closeTo(h / (log(3) / ln2) * 100, 1e-9));
      final relative = scoreGuess(field, 'ab', 2, best: h);
      expect(relative.skill, closeTo(100, 1e-9));
      expect(relative.best, closeTo(h, 1e-9));
      expect(relative.ready, isTrue);
    });

    test('withBest refines the skill and leaves luck alone', () {
      final p = scoreGuess(field, 'ab', 2, provisional: true);
      final r = p.withBest(h);
      expect(r.ready, isTrue);
      expect(r.skill, closeTo(100, 1e-9));
      expect(r.luck, p.luck);
      expect(r.expectedGain, p.expectedGain);
      expect(r.withBest(h).skill, closeTo(100, 1e-9), reason: 'idempotent');
      final hit = scoreGuess(['aa'], 'aa', 1, provisional: true).withBest(1);
      expect(hit.skill, 100);
      final miss = scoreGuess(['aa'], 'bb', 1, provisional: true).withBest(1);
      expect(miss.skill, 0);
    });

    test(
      'measured against every real guess, the best one scores 100',
      () async {
        const eligible = ['crane', 'crate', 'grate', 'grape', 'shape', 'slate'];
        final all = [...eligible, 'light', 'ounce'];
        final land = await analyseGuesses(eligible, all);
        expect(land.top.first.skill, closeTo(100, 1e-9));
        // H* is the largest expected gain among the guesses scored
        final highest = [
          for (final g in all) scoreGuess(eligible, g, 1).expectedGain,
        ].reduce(max);
        expect(land.bestGain, closeTo(highest, 1e-9));
        expect(land.gains.first, closeTo(highest, 1e-9));
        for (final g in all) {
          final m = scoreGuess(eligible, g, 1, best: land.bestGain);
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
    test('partial split: skill 57.9 against every word alone; luck is signed against the average gain', () {
      // groups for guess "ab": {aa, ac} and {ab}  ->  E = 5/3
      final unlucky = scoreGuess(field, 'ab', 2);
      expect(unlucky.skill, closeTo(57.94, .01));
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

  group('risk', () {
    // twelve words in a well-known family give splits of every shape
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

    test('a split into equal groups has no raw risk', () {
      final even = scoreGuess(const ['aa', 'ab', 'ba', 'bb'], 'ab', 1);
      expect(even.rawRisk, closeTo(0, 1e-9));
    });

    test('a tail of one big group is risky', () {
      // 7 words alike and one apart: usually little is learnt, once a lot
      const tail = [
        'aaaa',
        'aaab',
        'aaac',
        'aaad',
        'aaae',
        'aaaf',
        'aaag',
        'zzzz',
      ];
      expect(scoreGuess(tail, 'zzzz', 1).rawRisk, greaterThan(0));
    });

    test('risk is a share of the riskiest guess, 0 to 100', () async {
      final land = await analyseGuesses(words, words);
      expect(land.bestRisk, greaterThan(0));
      for (final g in words) {
        final m = scoreGuess(words, g, 1, triesLeft: 5).withLandscape(land);
        expect(m.risk, isNotNull);
        expect(m.risk, inInclusiveRange(0, 100), reason: g);
      }
      final top = land.riskiest.first;
      final m = scoreGuess(
        words,
        top.word,
        1,
        triesLeft: 5,
      ).withLandscape(land);
      expect(m.risk, closeTo(100, 1e-6), reason: 'the riskiest guess is 100');
    });

    test(
      'with one word or one try left there is nothing to gamble on',
      () async {
        const two = ['crane', 'crate'];
        final land = await analyseGuesses(['crane'], words);
        final lone = scoreGuess(['crane'], 'crane', 0, solved: true);
        expect(lone.withLandscape(land).risk, isNull);
        final last = scoreGuess(two, 'crane', 1, triesLeft: 1);
        expect(
          last.withLandscape(await analyseGuesses(two, words)).risk,
          isNull,
        );
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

  group('SplitContext', () {
    // the same scoring pair by pair with patternCode, which it replaces in loops
    SplitStats reference(
      List<String> eligible,
      String guess,
      Map<String, int>? weights,
    ) {
      final mass = <int, double>{};
      var total = 0.0;
      for (final w in eligible) {
        final x = weights == null ? 1.0 : (weights[w] ?? 1).toDouble();
        total += x;
        mass[patternCode(w, guess)] = (mass[patternCode(w, guess)] ?? 0) + x;
      }
      var h = 0.0;
      for (final m in mass.values) {
        h -= m / total * log(m / total) / ln2;
      }
      return SplitStats(
        e: 0,
        h: h,
        d: 0,
        groups: mass.length,
        largest: 0,
        total: total,
        masses: mass.values.toList(),
      );
    }

    test(
      'agrees with patternCode on repeated letters, with and without weights',
      () {
        final rng = Random(3);
        String word() =>
            String.fromCharCodes(List.generate(5, (_) => 97 + rng.nextInt(6)));
        final words = {for (var i = 0; i < 400; i++) word()}.toList();
        final weights = {for (final w in words) w: 1 + rng.nextInt(1000)};
        for (final law in [null, weights]) {
          final ctx = SplitContext(words, law);
          for (var i = 0; i < 60; i++) {
            // a guess may use a letter no word has, and repeat letters
            final g = i % 7 == 0 ? 'zzaab' : word();
            final a = ctx.stats(g), b = reference(words, g, law);
            expect(a.groups, b.groups, reason: g);
            expect(a.h, closeTo(b.h, 1e-9), reason: g);
            expect(a.total, closeTo(b.total, 1e-9));
            final answer = words[rng.nextInt(words.length)];
            expect(
              a.landedOf(g, answer),
              closeTo(
                words
                    .where((w) => patternCode(w, g) == patternCode(answer, g))
                    .fold<double>(0, (t, w) => t + (law == null ? 1 : law[w]!)),
                1e-9,
              ),
            );
          }
        }
      },
    );

    test('the opening of a big list is kept for the next game', () async {
      final rng = Random(5);
      final words = {
        for (var i = 0; i < 2100; i++)
          String.fromCharCodes(List.generate(5, (_) => 97 + rng.nextInt(26))),
      }.toList();
      final first = await analyseGuesses(words, words, answer: words[3]);
      final again = await analyseGuesses(words, words, answer: words[40]);
      expect(again.bestGain, first.bestGain);
      expect(again.top.first.word, first.top.first.word);
      expect(again.gains, first.gains);
      // only the answer-dependent part differs
      expect(again.luckiest.first.word, words[40]);
    });
  });

  group('lockedGuesses', () {
    const words = ['crane', 'crate', 'slate', 'brine'];
    test('keeps only words with the shown letters in place', () {
      expect(
        lockedGuesses(
          words,
          ['crone'],
          [
            [c, c, a, c, c],
          ],
        ),
        ['crane'],
      );
    });
    test('without greens every candidate stays', () {
      expect(
        lockedGuesses(
          words,
          ['xxxxx'],
          [
            [a, a, a, a, a],
          ],
        ),
        words,
      );
    });
  });

  group('blind groups', () {
    test('the group landed in is found by counts, not by tile pattern', () {
      const words = ['crane', 'crate', 'slate', 'brine', 'trace'];
      final stats = splitStats(words, 'crone', null, blind: true);
      for (final w in words) {
        final mass = stats.landedOf('crone', w)!;
        final real = words
            .where((x) => blindCode(x, 'crone') == blindCode(w, 'crone'))
            .length;
        expect(mass, real.toDouble());
      }
    });
  });
}
