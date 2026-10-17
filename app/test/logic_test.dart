import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/store.dart';

const c = Mark.correct, p = Mark.present, a = Mark.absent;

void main() {
  group('evaluate', () {
    test('all correct', () => expect(evaluate('crane', 'crane'), [c, c, c, c, c]));
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

    test('a guess that tells nothing has skill 0 and luck 0', () {
      final m = scoreGuess(field, 'ad', 3); // every word scores the same
      expect(m.skill, 0);
      expect(m.luck, 0);
    });
    test('a guess that splits the field into singletons has skill 100', () {
      final m = scoreGuess(['aa', 'bb'], 'aa', 1);
      expect(m.skill, 100);
      expect(m.luck, 100);
    });
    test('partial split: skill 66.7, luck depends on the outcome', () {
      // groups for guess "ab": {aa, ac} and {ab}  ->  E = 5/3
      final unlucky = scoreGuess(field, 'ab', 2);
      expect(unlucky.skill, closeTo(66.67, .01));
      expect(unlucky.luck, closeTo(75, .01));
      final lucky = scoreGuess(field, 'ab', 1);
      expect(lucky.luck, closeTo(150, .01));
      expect((lucky.before, lucky.after), (3, 1));
    });
    test('a single remaining word: skill 100, luck 0', () {
      final m = scoreGuess(['aa'], 'aa', 1);
      expect(m.skill, 100);
      expect(m.luck, 0);
    });
  });

  test('patternCode agrees with evaluate on every pair of a word set', () {
    const words = [
      'crane', 'eerie', 'abbey', 'babes', 'speed', 'erase', 'llama', 'aaaaa',
      'level', 'kebab', 'sissy', 'geese', 'mamma', 'array', 'radar', 'tarta',
    ];
    int pack(List<Mark> m) => m.fold(0, (a, x) => a * 3 + x.index);
    for (final t in words) {
      for (final g in words) {
        expect(patternCode(t, g), pack(evaluate(t, g)), reason: '$t / $g');
      }
    }
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
    final picks = [for (var i = 0; i < 500; i++) chooseWord(['a', 'b'], [99, 1], rng)];
    expect(picks.where((w) => w == 'a').length, greaterThan(450));
  });

  group('achievements', () {
    GameResult win({int used = 3, int tries = 6, int length = 5, String lang = 'en'}) =>
        GameResult(lang: lang, length: length, tries: tries, used: used, won: true);

    test('first win unlocks first_light and one_shot', () {
      final s = Stats()..record(win(used: 1));
      final ids = achievements.where((x) => x.test(s, win(used: 1))).map((x) => x.id);
      expect(ids, containsAll(['first_light', 'one_shot']));
    });
    test('a loss resets the streak', () {
      final s = Stats()
        ..record(win())
        ..record(win())
        ..record(const GameResult(lang: 'en', length: 5, tries: 6, used: 6, won: false));
      expect(s.streak, 0);
      expect(s.bestStreak, 2);
    });
    test('last_breath needs 4+ tries', () {
      final r = win(used: 3, tries: 3);
      final s = Stats()..record(r);
      final lb = achievements.firstWhere((x) => x.id == 'last_breath');
      expect(lb.test(s, r), isFalse);
      final r2 = win(used: 6, tries: 6);
      expect(lb.test(s, r2), isTrue);
    });
  });
}
