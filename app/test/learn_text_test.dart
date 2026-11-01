import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_text.dart';
import 'package:lexodle/logic.dart';

void main() {
  // Eight words where some guesses split them much better than others.
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
  const probes = [...words, 'flit', 'crow', 'mura'];

  Future<GuessReport> report(String guess, String answer) async {
    final land = await analyseGuesses(words, probes, k: 3);
    final m = evaluate(answer, guess);
    return reportGuess(
      before: words,
      guess: guess,
      after: filterEligible(words, guess, m),
      landscape: land,
    );
  }

  test('a guess that splits nothing is graded low and says why', () async {
    // every word shares _ake, so 'bake' tells apart only itself
    final r = await report('bake', 'cake');
    expect(r.skill, lessThan(60));
    expect(r.asGoodAsAny, isFalse);
    expect(r.yourGroups, lessThan(r.bestGroups));
    expect(learnVerdict(r), startsWith('skill '));
    expect(learnVerdict(r), contains('the best: '));
    final why = learnWhy(r);
    expect(why.first, startsWith('your bake: '));
    expect(why[1], startsWith('the best, ${r.bestWord}: '));
    expect(why.last, contains('groups, not'));
  });

  test(
    'the best guess is as good as any, and says nothing is better',
    () async {
      final land = await analyseGuesses(words, probes, k: 3);
      final best = land.top.first.word;
      final r = await report(best, 'cake');
      expect(r.skill, closeTo(100, 0.01));
      expect(r.asGoodAsAny, isTrue);
      expect(learnVerdict(r), startsWith('skill 100 · as good as any guess'));
      expect(
        learnWhy(r).last,
        anyOf(contains('no guess splits'), contains('as good:')),
      );
    },
  );

  test('the hint ladder gives the letter, then the word, then why', () async {
    final land = await analyseGuesses(words, probes, k: 3);
    final best = land.top.first.word;
    final why = reportBest(before: words, landscape: land);
    expect(learnHint(0, [best], why), '');
    expect(learnHint(1, [best], why), 'the best guess starts with ${best[0]}');
    expect(learnHint(2, [best], why), 'the best guess: $best');
    expect(learnHint(3, [best], why), contains('groups, the biggest'));
    expect(learnHint(1, const [], null), '');
  });

  test('one word left, or none, has nothing to split', () async {
    final land = await analyseGuesses(['bake'], probes, k: 3);
    final r = reportGuess(
      before: ['bake'],
      guess: 'bake',
      after: ['bake'],
      landscape: land,
    );
    expect(r.trivial, isTrue);
    expect(learnWhy(r), ['one word fitted, so only that word could win']);
  });
}
