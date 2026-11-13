import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/first_run/first_game_engine.dart';

int _edit(String a, String b) {
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) d++;
  }
  return d;
}

void main() {
  // the five-letter words of the en list, in file order (most common first)
  final all = <String>[];
  for (final line in File('assets/words/en.txt').readAsLinesSync()) {
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    final w = line.substring(0, tab);
    if (w.length == 5) all.add(w);
  }
  // the mockup's list leaves out the accented words
  final words = [
    for (final w in all)
      if (RegExp(r'^[a-z]{5}$').hasMatch(w)) w,
  ];
  late FirstGameEngine e;
  setUp(() => e = FirstGameEngine(words, random: Random(1)));

  test('the list is the mockup list: 11,727 words, pool of 3000', () {
    expect(words.length, mockupWordCount);
    expect(e.pool.length, 3000);
    expect(e.pool.first, 'about');
    expect(e.pool.last, words[2999]);
    expect(all.length, greaterThan(words.length)); // accented words exist
  });

  test('the five-letter words are sorted by commonness', () {
    final weights = <int>[];
    for (final line in File('assets/words/en.txt').readAsLinesSync()) {
      final tab = line.indexOf('\t');
      if (tab > 0 && line.substring(0, tab).length == 5) {
        weights.add(int.parse(line.substring(tab + 1)));
      }
    }
    for (var i = 1; i < weights.length; i++) {
      expect(weights[i], lessThanOrEqualTo(weights[i - 1]));
    }
  });

  test('the first target is in the pool and fits the pattern', () {
    for (final g in ['crane', 'about', 'slate', 'zebra', 'those']) {
      final c = e.chooseFirst(g);
      expect(e.pool, contains(c.target));
      expect(c.target, isNot(g));
      expect(c.candidates, contains(c.target));
      expect(c.candidates.first, c.target);
      for (final t in c.candidates) {
        expect(patternOf(g, t), c.pattern);
      }
      expect(Shape.classic(c.pattern), isTrue);
    }
  });

  test('suggestions are valid words, not the first guess', () {
    for (final g in ['crane', 'about', 'slate', 'those', 'their']) {
      final c = e.chooseFirst(g);
      final s = e.suggestion(g, c.pattern, c.candidates);
      expect(e.isValid(s), isTrue);
      expect(s, isNot(g));
    }
  });

  test('the suggestion is an anagram of the guess when one is a candidate', () {
    final c = e.chooseFirst('there');
    final s = e.suggestion('there', c.pattern, c.candidates);
    final hasAna = c.candidates.any(
      (w) => w != 'there' && (w.split('')..sort()).join() == 'eehrt',
    );
    if (hasAna) expect((s.split('')..sort()).join(), 'eehrt');
  });

  test('the second target is a candidate with a green', () {
    final c = e.chooseFirst('crane');
    final s = e.suggestion('crane', c.pattern, c.candidates);
    for (final g2 in [s, 'about', 'house']) {
      final t = e.chooseSecond(
        g2,
        candidates: c.candidates,
        suggested: s,
        target: c.target,
      );
      expect(c.candidates, contains(t));
      expect(t, isNot(g2));
    }
    final t = e.chooseSecond(
      s,
      candidates: c.candidates,
      suggested: s,
      target: c.target,
    );
    expect(count(patternOf(s, t), 'g'), greaterThanOrEqualTo(1));
  });

  test('candidate filtering shrinks and keeps the pattern', () {
    var cand = e.pool.toList();
    for (final g in ['crane', 'other', 'sound']) {
      final step = e.filterCandidates(cand, g);
      expect(step.candidates.length, lessThan(cand.length));
      for (final w in step.candidates) {
        expect(patternOf(g, w), step.pattern);
      }
      cand = step.candidates;
    }
    expect(e.filterCandidates(const [], 'crane').candidates, isEmpty);
  });

  test('one letter fix is a valid word one letter away, the most common', () {
    for (final g in ['abouf', 'thein', 'wxuld', 'qwxyz', 'housx']) {
      final f = e.oneLetterFix(g);
      if (f == null) {
        expect(g, 'qwxyz');
        continue;
      }
      final w = g.substring(0, f.index) + f.letter + g.substring(f.index + 1);
      expect(e.isValid(w), isTrue);
      expect(_edit(g, w), 1);
      for (var i = 0; i < 5; i++) {
        for (var k = 97; k < 123; k++) {
          final o =
              g.substring(0, i) + String.fromCharCode(k) + g.substring(i + 1);
          if (o != g && e.isValid(o)) {
            expect(words.indexOf(o), greaterThanOrEqualTo(words.indexOf(w)));
          }
        }
      }
    }
    expect(e.oneLetterFix('abouf')!.letter, 't');
  });

  test('one letter fix works on another valid set', () {
    final f = e.oneLetterFix('paric', valid: {'paris', 'tokyo'});
    expect(f!.index, 4);
    expect(f.letter, 's');
  });

  test('shape pick', () {
    final t = e.pick('crane', Shape.classic);
    expect(e.pool, contains(t));
    expect(Shape.classic(patternOf('crane', t)), isTrue);
    final lock = e.pick('crane', Shape.lock);
    expect(Shape.lock(patternOf('crane', lock)), isTrue);
    final other = e.pick('crane', Shape.classic, [t]);
    expect(other, isNot(t));
    // no word fits: the first allowed pool word
    expect(
      FirstGameEngine.shapePick(
        'about',
        ['about', 'zzzzz', 'yyyyy'],
        Shape.any,
        ['zzzzz'],
      ),
      'yyyyy',
    );
    expect(
      FirstGameEngine.shapePick('about', ['about'], (p) => false, []),
      'about',
    );
  });

  test('game target is the mockup formula', () {
    expect(e.gameTarget(1), e.pool[37]);
    expect(e.gameTarget(31), e.pool[(31 * 37) % 400]);
  });

  test('a seeded random is deterministic', () {
    final a = FirstGameEngine(words, random: Random(7));
    final b = FirstGameEngine(words, random: Random(7));
    expect(
      [for (var i = 0; i < 5; i++) a.randomPoolWord()],
      [for (var i = 0; i < 5; i++) b.randomPoolWord()],
    );
    expect(e.pool, contains(a.randomPoolWord()));
  });

  test('a smaller pool', () {
    final s = FirstGameEngine(words, poolSize: 50);
    expect(s.pool.length, 50);
    expect(s.pool, contains(s.chooseFirst('crane').target));
  });

  group('progress', () {
    test('flags and steps follow the mockup', () {
      var p = const FirstGameProgress();
      p = p.onGuess(tutorial: true);
      expect(p.step, 1);
      p = p.onGuess(tutorial: true);
      expect(p.step, 2);
      p = p.onType('_', tutorial: true);
      expect(p.blank, isTrue);
      expect(p.step, 3);
      p = p.onLocked(tutorial: true);
      expect(p.lock, isTrue);
      expect(p.step, 4); // not yet cleared
      p = p.onClear(tutorial: true);
      expect(p.swipe, isTrue);
      expect(p.step, 5);
      p = p.onHint(tutorial: true);
      expect(p.step, 6);
    });

    test('lock after a clear skips step 4', () {
      final p = const FirstGameProgress(
        step: 3,
        swipe: true,
      ).onLocked(tutorial: true);
      expect(p.step, 5);
    });

    test('delete in step 4 counts as a clear', () {
      final p = const FirstGameProgress(step: 4).onDelete(tutorial: true);
      expect(p.swipe, isTrue);
      expect(p.step, 5);
      expect(
        const FirstGameProgress(step: 3).onDelete(tutorial: true).swipe,
        isFalse,
      );
    });

    test('tap learns the fix only on the arrow tile', () {
      const p = FirstGameProgress(step: 2);
      expect(p.onTap(1, fixIndex: 3, tutorial: true).fix, isFalse);
      final q = p.onTap(3, fixIndex: 3, tutorial: true);
      expect(q.fix, isTrue);
      expect(q.step, 3);
    });

    test('outside the tutorial only the flags change', () {
      var p = const FirstGameProgress();
      p = p
          .onGuess(tutorial: false)
          .onType('_', tutorial: false)
          .onLocked(tutorial: false);
      expect(p.step, 0);
      expect(p.blank && p.lock, isTrue);
    });

    test('coach lines', () {
      const p = FirstGameProgress();
      expect(p.invalidHint(hasFix: true), contains('swipe the row'));
      expect(
        const FirstGameProgress(swipe: true).invalidHint(hasFix: false),
        'not a word.',
      );
      expect(
        p.gameHint(rows: 1, hasGreen: true),
        'double tap a green to lock it.',
      );
      expect(p.gameHint(rows: 2, hasGreen: false), 'press _ for a blank.');
      expect(p.gameHint(rows: 0, hasGreen: false), isNull);
      expect(p.copyWith(lock: true), isNot(p));
      expect(p.copyWith(), p);
    });
  });
}
