import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill_calc.dart';
import 'package:lexodle/logic.dart';

void main() {
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

  test('a worked example: one word alone, three together', () {
    // 'bake' tells itself from the rest; cake, fake and lake all show the same
    // colours against it (the first letter absent, then three greens)
    final w = walkGroups(['bake', 'cake', 'fake', 'lake'], 'bake', null);
    expect(w.words, 4);
    expect(w.groups, hasLength(2));
    final big = w.groups.first;
    expect(big.words, ['cake', 'fake', 'lake']);
    expect(big.marks, [Mark.absent, Mark.correct, Mark.correct, Mark.correct]);
    expect(big.chance, 0.75);
    expect(big.bits, closeTo(0.415, 0.001));
    // 0.75 x 0.75 x 4
    expect(big.share, closeTo(2.25, 1e-9));
    final alone = w.groups.last;
    expect(alone.words, ['bake']);
    expect(alone.marks, everyElement(Mark.correct));
    expect(alone.chance, 0.25);
    expect(alone.bits, 2);
    expect(alone.share, closeTo(0.25, 1e-9));
    // E = 2.25 + 0.25, H = 0.75 x 0.415 + 0.25 x 2
    expect(w.expectedLeft, closeTo(2.5, 1e-9));
    expect(w.expectedBits, closeTo(0.8113, 0.0001));
  });

  test('a guess that fits nowhere splits nothing: one group, no bits', () {
    final w = walkGroups(words, 'flit', null);
    expect(w.groups.length, lessThan(words.length));
    final none = walkGroups(words, 'zzzz', null);
    expect(none.groups, hasLength(1));
    expect(none.expectedBits, 0);
    expect(none.expectedLeft, words.length);
  });

  test('it agrees with the scoring the skill is made from', () {
    for (final weights in [
      null,
      {for (final (i, w) in words.indexed) w: (i + 1) * 7},
    ]) {
      for (final guess in ['bake', 'flit', 'mura', 'crow', 'wake']) {
        final walk = walkGroups(words, guess, weights);
        final s = splitStats(words, guess, weights);
        expect(walk.groups.length, s.groups, reason: '$guess groups');
        expect(
          walk.groups
              .map((g) => g.words.length)
              .reduce((a, b) => a > b ? a : b),
          s.largest,
          reason: '$guess largest',
        );
        expect(walk.expectedLeft, closeTo(s.e, 1e-9), reason: '$guess E');
        expect(walk.expectedBits, closeTo(s.h, 1e-9), reason: '$guess H');
        expect(walk.total, closeTo(s.total, 1e-9));
      }
    }
  });

  test(
    'the chances add up to one, the shares to E, the words to all of them',
    () {
      final w = walkGroups(words, 'mura', {
        for (final (i, x) in words.indexed) x: i + 1,
      });
      expect(w.groups.fold(0.0, (s, g) => s + g.chance), closeTo(1, 1e-9));
      expect(
        w.groups.fold(0.0, (s, g) => s + g.share),
        closeTo(w.expectedLeft, 1e-9),
      );
      expect(w.groups.fold(0, (s, g) => s + g.words.length), words.length);
      expect(
        w.groups.fold(0.0, (s, g) => s + g.chance * g.bits),
        closeTo(w.expectedBits, 1e-9),
      );
    },
  );

  test('the groups are the likeliest first, and each has its own colours', () {
    final w = walkGroups(words, 'make', null);
    for (var i = 1; i < w.groups.length; i++) {
      expect(w.groups[i].mass, lessThanOrEqualTo(w.groups[i - 1].mass));
    }
    // every word of a group shows exactly the group's colours
    for (final g in w.groups) {
      for (final word in g.words) {
        expect(evaluate(word, 'make'), g.marks, reason: word);
      }
    }
    // and no two groups show the same
    final seen = {for (final g in w.groups) g.marks.map((m) => m.index).join()};
    expect(seen.length, w.groups.length);
  });

  test('the answer marks its own group, and only that one', () {
    final w = walkGroups(words, 'make', null, answer: 'take');
    final held = w.groups.where((g) => g.holdsAnswer).toList();
    expect(held, hasLength(1));
    expect(held.single.words, contains('take'));
    expect(w.landed, same(held.single));
    expect(walkGroups(words, 'make', null).landed, isNull);
  });

  test('skill is the expected bits over the best, as the scoring has it', () {
    final w = walkGroups(words, 'bake', null);
    expect(w.skill(w.expectedBits), 100);
    expect(w.skill(w.expectedBits * 2), closeTo(50, 1e-9));
    expect(w.skill(0), 100, reason: 'nothing to beat');
  });
}
