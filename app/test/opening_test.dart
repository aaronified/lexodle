import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill_calc.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/opening.dart';
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

  test(
    'the outcomes leave out the first guess being right, likeliest first',
    () {
      final all = openingOutcomes(words, 'make', null, limit: null);
      expect(all, isNotEmpty);
      for (final g in all) {
        expect(g.marks.any((m) => m != Mark.correct), isTrue);
      }
      for (var i = 1; i < all.length; i++) {
        expect(all[i].mass, lessThanOrEqualTo(all[i - 1].mass));
      }
      // with the one where it is right, they are all the words
      final walk = walkGroups(words, 'make', null);
      expect(
        all.fold<int>(0, (s, g) => s + g.words.length) + 1,
        walk.words,
        reason: 'make is the only word that shows all green',
      );
      expect(openingOutcomes(words, 'bark', null, limit: 2), hasLength(2));
    },
  );

  test(
    'the second guesses of a group are its best, and a lone word is itself',
    () async {
      final groups = openingOutcomes(words, 'bake', null, limit: null);
      final big = groups.first;
      expect(big.words.length, greaterThan(1));
      final seconds = await secondGuesses(
        group: big,
        guessable: [...words, 'flit', 'crow'],
        weights: null,
      );
      expect(seconds, isNotEmpty);
      expect(seconds.first.skill, closeTo(100, 0.01));
      // one that fits the group splits it: its expected words left is lower
      final lone = GroupLine(
        marks: const [Mark.absent, Mark.absent, Mark.absent, Mark.absent],
        words: const ['cake'],
        mass: 1,
        chance: 1,
        bits: 0,
        share: 1,
        holdsAnswer: false,
      );
      final one = await secondGuesses(
        group: lone,
        guessable: words,
        weights: null,
      );
      expect(one.single.word, 'cake');
      expect(one.single.canWin, isTrue);
    },
  );

  testWidgets('for a real language the best opener has outcomes that sum up', (
    tester,
  ) async {
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    final land = (await tester.runAsync(
      () => openingLandscape(bank: bank, length: 4, draw: Draw.sigmoid),
    ))!;
    expect(land.top.length, greaterThanOrEqualTo(3));
    final first = land.top.first.word;
    final all = bank.guessable(4);
    final outcomes = openingOutcomes(all, first, bank.law(4, Draw.sigmoid));
    expect(outcomes, hasLength(openingOutcomeCount));
    // the likeliest outcomes hold most of the words
    expect(outcomes.first.words.length, greaterThan(1));
    final seconds = (await tester.runAsync(
      () => secondGuesses(
        group: outcomes.first,
        guessable: all,
        weights: bank.law(4, Draw.sigmoid),
      ),
    ))!;
    expect(seconds, isNotEmpty);
    // playing it leaves fewer words on average than the group had
    expect(seconds.first.expected, lessThan(outcomes.first.words.length));
  });
}
