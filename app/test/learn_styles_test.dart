import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/history.dart' show GuessRow;
import 'package:lexodle/learn_styles.dart';
import 'package:lexodle/logic.dart' hide freshLetters;
import 'package:lexodle/modes.dart';
import 'package:lexodle/opening.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rule is the one the playstyle uses', () {
    Behaviour? b({
      required int before,
      int greens = 0,
      double? risk,
      double? rank,
      int fresh = 0,
      bool fits = false,
    }) => behaviourFor(
      before: before,
      greens: greens,
      risk: risk,
      rank: rank,
      fresh: fresh,
      fits: fits,
    );

    test('the three opening habits, in the order they are counted', () {
      expect(b(before: 500, risk: 75, rank: 3, fresh: 5), Behaviour.gambler);
      expect(b(before: 500, risk: 74, rank: 10, fresh: 5), Behaviour.maximiser);
      expect(
        b(before: 500, risk: 10, rank: 11, fresh: 4),
        Behaviour.eliminator,
      );
      expect(b(before: 500, risk: 10, rank: 11, fresh: 3), isNull);
    });

    test('the two closing habits', () {
      expect(b(before: 10, fits: true), Behaviour.closer);
      expect(b(before: 10, rank: 10), Behaviour.prober);
      expect(b(before: 10, rank: 11), isNull);
      expect(b(before: 2, rank: 0), isNull, reason: 'under 3 words left');
      // three greens known make it the end game
      expect(b(before: 30, greens: 3, fits: true), Behaviour.closer);
    });

    test('the middle game, and one word left, count for no habit', () {
      expect(b(before: 30, fits: true, risk: 90, rank: 0, fresh: 5), isNull);
      expect(b(before: 1, fits: true), isNull);
    });

    test('and the guesses of a played game are counted the same way', () {
      // behaviourOf reads a stored row with the same numbers
      expect(
        behaviourOf(const GuessRowStub(500, risk: 80).row()),
        Behaviour.gambler,
      );
    });
  });

  group('the lines', () {
    StyleProfile p({
      Behaviour? behaviour,
      Phase? phase = Phase.early,
      int before = 500,
      int fresh = 0,
      double? risk = 10,
      double? rank = 50,
    }) => StyleProfile(
      guess: 'tares',
      behaviour: behaviour,
      phase: phase,
      before: before,
      greens: 0,
      fresh: fresh,
      fits: false,
      risk: risk,
      rank: rank,
      skill: 80,
      luck: 0,
    );

    test('each habit says what put the guess in it, with its numbers', () {
      expect(
        styleLine(p(behaviour: Behaviour.gambler, risk: 82)),
        'style: gambler · risk 82, a risk of $gamblerRisk or more',
      );
      expect(
        styleLine(p(behaviour: Behaviour.maximiser, rank: 3)),
        contains('top 3% of the guesses scored'),
      );
      expect(
        styleLine(p(behaviour: Behaviour.eliminator, fresh: 5)),
        contains('5 letters never tried'),
      );
      expect(
        styleLine(p(behaviour: Behaviour.closer, phase: Phase.end)),
        'style: closer · it fits every clue, so it can win',
      );
      expect(
        styleLine(
          p(behaviour: Behaviour.prober, phase: Phase.end, before: 7, rank: 4),
        ),
        contains('it cannot win, but ranks in the top 4% with 7 words left'),
      );
    });

    test('a guess that counts as none says why, by phase', () {
      expect(styleLine(p(phase: null)), contains('one word left'));
      expect(styleLine(p(phase: Phase.middle)), contains('the middle game'));
      final early = styleLine(p(risk: 20, rank: 40, fresh: 2));
      expect(early, contains('not a gamble (risk 20 under $gamblerRisk)'));
      expect(early, contains('not in the top $topRank% (rank 40%)'));
      expect(early, contains('2 fresh letters is under $freshLetters'));
      final end = styleLine(p(phase: Phase.end, before: 9, rank: 30));
      expect(end, contains('does not fit the clues'));
      expect(end, contains('rank 30%, 9 words'));
    });

    test('luck is explained as the answer, never as a choice', () {
      expect(luckExplained(0), startsWith('luck 0 · '));
      final up = luckExplained(40);
      expect(up, startsWith('luck +40 · the answer fell in a smaller group'));
      expect(up, endsWith('that was the answer, not your choice'));
      final down = luckExplained(-25);
      expect(down, startsWith('luck −25 · the answer fell in a bigger group'));
      expect(down, endsWith('that was the answer, not your choice'));
    });
  });

  group('profiling a guess', () {
    // Eight words: the end game (16 or fewer).
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
    const probes = [...words, 'bark', 'cola', 'pale', 'mode', 'flit'];

    Future<StyleProfile> profile(String guess, String answer) async {
      final land = await analyseGuesses(words, probes, k: 3);
      final after = filterEligible(words, guess, evaluate(answer, guess));
      return profileGuess(
        before: words,
        guess: guess,
        after: after,
        landscape: land,
      );
    }

    test(
      'a word that fits the clues in the end game counts as a closer',
      () async {
        final r = await profile('bake', 'cake');
        expect(r.phase, Phase.end);
        expect(r.fits, isTrue);
        expect(r.behaviour, Behaviour.closer);
      },
    );

    test('a probe that splits the words best counts as a prober', () async {
      final land = await analyseGuesses(words, probes, k: 3);
      final best = land.top.first.word;
      // the best split of eight words that differ in one letter is a probe
      expect(words.contains(best), isFalse);
      final r = await profile(best, 'cake');
      expect(r.fits, isFalse);
      expect(r.rank, 0);
      expect(r.behaviour, Behaviour.prober);
    });

    test('a probe that splits badly counts as none', () async {
      final r = await profile('zzzz', 'cake');
      expect(r.fits, isFalse);
      expect(r.behaviour, isNull);
      expect(styleLine(r), contains('does not fit the clues'));
    });

    test(
      'the fresh letters and greens come from the earlier guesses',
      () async {
        final land = await analyseGuesses(words, probes, k: 3);
        final fresh = profileGuess(
          before: words,
          guess: 'bark',
          after: words,
          landscape: land,
          earlier: const ['bake'],
          earlierMarks: [
            [Mark.correct, Mark.correct, Mark.absent, Mark.absent],
          ],
        );
        // only r is new: b, a and k were in bake
        expect(fresh.fresh, 1);
        expect(fresh.greens, 2);
      },
    );

    test(
      'the luck is the answer\'s doing: it averages nothing over answers',
      () async {
        var total = 0.0;
        for (final a in words) {
          total += (await profile('bark', a)).luck;
        }
        expect(total / words.length, closeTo(0, 1e-6));
        // and it is not the same for every answer
        final lucks = {for (final a in words) (await profile('bark', a)).luck};
        expect(lucks.length, greaterThan(1));
      },
    );
  });

  testWidgets(
    'the best opener counts as a maximiser, and some words as eliminators',
    (tester) async {
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final all = bank.guessable(4);
      final law = bank.law(4, Draw.sigmoid);
      final land = (await tester.runAsync(
        () => openingLandscape(bank: bank, length: 4, draw: Draw.sigmoid),
      ))!;
      final first = land.top.first.word;
      final p = profileGuess(
        before: all,
        guess: first,
        after: all,
        landscape: land,
        weights: law,
      );
      expect(p.phase, Phase.early);
      expect(p.behaviour, Behaviour.maximiser);
      expect(p.rank, 0);
      // some word that is not a top split but uses four new letters is one
      final eliminators = [
        for (final w in all.take(400))
          if (profileGuess(
                before: all,
                guess: w,
                after: all,
                landscape: land,
                weights: law,
                earlier: [first],
                earlierMarks: [List.filled(4, Mark.absent)],
              ).behaviour ==
              Behaviour.eliminator)
            w,
      ];
      expect(eliminators, isNotEmpty);
    },
  );
}

/// A stored guess with only what the habit rule reads.
class GuessRowStub {
  const GuessRowStub(this.before, {this.risk});
  final int before;
  final double? risk;
  GuessRow row() =>
      GuessRow(game: 0, n: 0, word: 'tares', before: before, risk: risk);
}
