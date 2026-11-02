import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/sequence.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const four = ['bake', 'cake', 'fake', 'lake'];
  const eight = [
    'bake',
    'cake',
    'fake',
    'lake',
    'make',
    'rake',
    'take',
    'wake',
  ];

  test(
    'a worked example: two words that find two answers and pair the rest',
    () {
      final s = scoreSequence(four, ['bake', 'cake'], null);
      // bake and cake are each alone; fake and lake show the same colours twice
      expect(s.groups, 3);
      expect(s.alone, 2);
      expect(s.largest, 2);
      // after one word: {bake} and {cake, fake, lake}, 0.25 x 2 + 0.75 x 0.415
      expect(s.cumulativeBits[0], closeTo(0.8113, 0.0001));
      // after two: 0.25 x 2 + 0.25 x 2 + 0.5 x 1
      expect(s.bits, closeTo(1.5, 1e-9));
      expect(s.cumulativeBits, hasLength(2));
      // E = 4 x (1/16 + 1/16 + 1/4)
      expect(s.expectedLeft, closeTo(1.5, 1e-9));
      // the next guess wins in 3 of the 4 cases (one word of each group)
      expect(s.by4, closeTo(0.75, 1e-9));
      // and the guess after wins every one: fake, then lake
      expect(s.by5, closeTo(1.0, 1e-9));
    },
  );

  test(
    'more words never tell less, and the order does not change the total',
    () {
      final a = scoreSequence(eight, ['bark', 'cola', 'pale'], null);
      for (var i = 1; i < a.cumulativeBits.length; i++) {
        expect(
          a.cumulativeBits[i],
          greaterThanOrEqualTo(a.cumulativeBits[i - 1]),
        );
      }
      final b = scoreSequence(eight, ['pale', 'bark', 'cola'], null);
      expect(b.bits, closeTo(a.bits, 1e-9));
      expect(b.groups, a.groups);
      expect(b.expectedLeft, closeTo(a.expectedLeft, 1e-9));
    },
  );

  test('a word that splits nothing adds nothing', () {
    final one = scoreSequence(eight, ['bark'], null);
    final two = scoreSequence(eight, ['bark', 'zzzz'], null);
    expect(two.bits, closeTo(one.bits, 1e-9));
    expect(two.groups, one.groups);
  });

  test('it agrees with splitStats for one word, weighted or not', () {
    for (final weights in [
      null,
      {for (final (i, w) in eight.indexed) w: (i + 1) * 5},
    ]) {
      final s = scoreSequence(eight, ['bark'], weights);
      final st = splitStats(eight, 'bark', weights);
      expect(s.groups, st.groups);
      expect(s.largest, st.largest);
      expect(s.bits, closeTo(st.h, 1e-9));
      expect(s.expectedLeft, closeTo(st.e, 1e-9));
    }
  });

  test(
    'the chance of winning by the next guess is a chance, and by5 >= by4',
    () {
      final s = scoreSequence(eight, ['bark', 'cola', 'pale'], null);
      expect(s.by4, inInclusiveRange(0, 1));
      expect(s.by5, inInclusiveRange(s.by4, 1));
      // alone answers are found outright
      expect(s.by4, greaterThanOrEqualTo(s.alone / s.answers));
    },
  );

  test('the weights make the likelier words count for more', () {
    final even = scoreSequence(four, ['bake'], null);
    final skewed = scoreSequence(
      four,
      ['bake'],
      {'bake': 100, 'cake': 1, 'fake': 1, 'lake': 1},
    );
    expect(skewed.bits, lessThan(even.bits), reason: 'bake is nearly certain');
    expect(skewed.by4, greaterThan(even.by4));
  });

  test('the skill is the bits against the best found, held to 100', () {
    final good = scoreSequence(eight, ['bark', 'cola', 'pale'], null);
    final poor = scoreSequence(eight, ['bark'], null);
    expect(sequenceSkill(good, good), 100);
    expect(sequenceSkill(poor, good), lessThan(100));
    expect(sequenceSkill(good, poor), 100, reason: 'better than the benchmark');
    expect(
      sequenceSkill(poor, good),
      closeTo(poor.bits / good.bits * 100, 1e-9),
    );
  });

  group('the search', () {
    test('it finds a sequence at least as good as any it was started from', () {
      final job = SequenceJob(
        eight,
        [...eight, 'bark', 'cola', 'pale', 'mode', 'flit', 'crow'],
        ['bark', 'mode'],
        null,
      );
      final seq = greedySequence(job);
      expect(seq, hasLength(sequenceLength));
      expect(seq.toSet(), hasLength(sequenceLength));
      final found = scoreSequence(eight, seq, null);
      // better than a sequence of the same words in a worse order of choice
      final naive = scoreSequence(eight, ['bark', 'flit', 'crow'], null);
      expect(found.bits, greaterThanOrEqualTo(naive.bits));
      // and it finds all of the answers apart if the pool can
      expect(found.groups, greaterThan(3));
    });

    test('a start word that is not first can still end up in the best', () {
      final job = SequenceJob(
        eight,
        ['bark', 'cola', 'pale', 'mode'],
        ['bark', 'cola'],
        null,
      );
      final seq = greedySequence(job);
      expect(seq.first, anyOf('bark', 'cola'));
    });

    test('nothing to search gives nothing', () {
      expect(greedySequence(const SequenceJob([], [], [], null)), isEmpty);
      expect(
        greedySequence(SequenceJob(four, ['bake'], const [], null)),
        isEmpty,
      );
    });

    testWidgets('for a real language it beats a sequence of common words', (
      tester,
    ) async {
      clearSequenceBenchmarks();
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final all = bank.guessable(4);
      final best = (await tester.runAsync(
        () => benchmarkSequence(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          firsts: all.take(2).toList(),
        ),
      ))!;
      expect(best.words, hasLength(sequenceLength));
      expect(best.answers, all.length);
      final common = scoreSequence(
        all,
        all.take(3).toList(),
        bank.law(4, Draw.sigmoid),
      );
      expect(best.bits, greaterThan(common.bits));
      expect(best.by5, greaterThan(best.by4));
      // kept: asking again does not search again
      final again = (await tester.runAsync(
        () => benchmarkSequence(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          firsts: all.take(2).toList(),
        ),
      ))!;
      expect(
        identical(again, best),
        isTrue,
        reason: 'kept, not searched again',
      );
      expect(again.words, best.words);
      expect(best.groups, greaterThan(10));
    });
  });
}
