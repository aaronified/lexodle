import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

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
    test(
      'partial split: skill 66.7; luck is signed against the average pool',
      () {
        // groups for guess "ab": {aa, ac} and {ab}  ->  E = 5/3
        final unlucky = scoreGuess(field, 'ab', 2);
        expect(unlucky.skill, closeTo(66.67, .01));
        expect(unlucky.luck, closeTo(-20, .01)); // 20% larger than average
        final lucky = scoreGuess(field, 'ab', 1);
        expect(lucky.luck, closeTo(40, .01)); // 40% smaller than average
        expect((lucky.before, lucky.after), (3, 1));
      },
    );
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
    test('expectedLeft inverts skill', () {
      expect(expectedLeft(3, 66.67), closeTo(5 / 3, .01));
      expect(expectedLeft(1, 100), 1);
    });
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

    test('comment: a top pick is praised', () {
      final t = stepComment(
        m: gm('grout', 98, 0, 7, 1),
        picks: [rec('turbo', 99, 1.1), rec('grout', 98, 1.2)],
        after: ['grout'],
        solved: false,
      );
      expect(t, contains('Terrific choice'));
      expect(t, contains('only one possible solution left'));
    });
    test(
      'comment: a weak guess names the better one and both expectations',
      () {
        final t = stepComment(
          m: gm('mamma', 30, 0, 400, 280),
          picks: [rec('rates', 95, 20)],
          after: List.filled(280, 'x'),
          solved: false,
        );
        expect(t, contains('A missed chance'));
        expect(t, contains('rates'));
        expect(t, contains('about 20 words'));
      },
    );
    test('comment: luck and few words left are mentioned', () {
      final lucky = stepComment(
        m: gm('crane', 80, 50, 300, 3),
        picks: [rec('crane', 80, 60)],
        after: ['a', 'b', 'c'],
        solved: false,
      );
      expect(lucky, contains('lucky'));
      expect(lucky, contains('Only 3 words are left: a, b, c.'));
      final unlucky = stepComment(
        m: gm('crane', 80, -50, 300, 200),
        picks: [rec('crane', 80, 60)],
        after: List.filled(200, 'x'),
        solved: false,
      );
      expect(unlucky, contains('Unlucky'));
    });
    test(
      'comment: a valid guess that can never be the answer is said so, once',
      () {
        final t = stepComment(
          m: gm('entre', 0, 0, 1, 1),
          picks: [rec('etude', 100, 1)],
          after: ['etude'],
          solved: false,
          guessCanBeAnswer: false,
        );
        expect(t, contains('this was not it'));
        expect(t, contains('never uses it as an answer'));
        expect(t, isNot(contains('vocabulary')));
      },
    );
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

  group('recommend', () {
    test('picks the guess that splits the field best', () async {
      final r = await recommend(['aa', 'ab', 'ac'], ['ad', 'ab', 'ax']);
      expect(r!.word, 'ab');
      expect(r.expected, closeTo(5 / 3, 1e-9));
      expect(r.skill, closeTo(66.67, .01));
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
