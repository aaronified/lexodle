import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart' hide freshLetters;
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/styles_lesson.dart';
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

  group('luck, explained', () {
    test('over every answer it averages nothing, whatever the guess', () {
      for (final guess in ['bark', 'bake', 'cola', 'zzzz']) {
        final s = luckSpread(words, guess, null);
        expect(s.mean, closeTo(0, 1e-9), reason: guess);
      }
      final law = {for (final (i, w) in words.indexed) w: (i + 1) * 9};
      expect(luckSpread(words, 'bark', law).mean, closeTo(0, 1e-9));
    });

    test('the biggest group is the unluckiest, the smallest the luckiest', () {
      final s = luckSpread(words, 'bark', null);
      expect(s.rows.length, greaterThan(2));
      final lucks = [for (final r in s.rows) r.luck];
      // the groups run from the biggest, so luck only goes up
      for (var i = 1; i < lucks.length; i++) {
        expect(lucks[i], greaterThanOrEqualTo(lucks[i - 1]));
      }
      expect(lucks.first, lessThan(0));
      expect(lucks.last, greaterThan(0));
    });

    test('a guess that splits nothing has no luck to have', () {
      final s = luckSpread(words, 'zzzz', null);
      expect(s.rows, hasLength(1));
      expect(s.rows.single.luck, 0);
    });

    test('it is the luck the grading would give an answer in that group', () {
      // the same number as scoring the guess for an answer of that group
      final s = luckSpread(words, 'bark', null);
      for (final r in s.rows) {
        final answer = r.group.words.first;
        final after = filterEligible(words, 'bark', evaluate(answer, 'bark'));
        final m = scoreGuess(words, 'bark', after.length, afterWords: after);
        expect(m.luck, closeTo(r.luck, 1e-9), reason: answer);
      }
    });
  });

  testWidgets('the examples are real guesses that count as the habit', (
    tester,
  ) async {
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    final law = bank.law(4, Draw.sigmoid);
    final pos = (await tester.runAsync(
      () => openingPosition(bank: bank, length: 4, draw: Draw.sigmoid),
    ))!;
    expect(pos.eligible.length, greaterThanOrEqualTo(earlyFrom));
    expect(pos.marks, hasLength(4));
    final ex = openingExamples(
      pos: pos,
      guessable: bank.guessable(4),
      weights: law,
    );
    expect(
      [for (final e in ex) e.behaviour],
      [Behaviour.gambler, Behaviour.maximiser, Behaviour.eliminator],
    );
    for (final e in ex) {
      // an example that qualifies counts, by the same rule, as what it shows
      if (e.qualifies) {
        expect(e.profile.behaviour, e.behaviour, reason: e.word);
      }
      expect(e.profile.phase, Phase.early);
      expect(e.walk.words, pos.eligible.length);
    }
    final max = ex.firstWhere((e) => e.behaviour == Behaviour.maximiser);
    expect(max.qualifies, isTrue);
    expect(max.profile.rank, lessThanOrEqualTo(topRank));
    // the eliminator is not one of the best splits, but clears letters
    final elim = ex.firstWhere((e) => e.behaviour == Behaviour.eliminator);
    expect(elim.qualifies, isTrue);
    expect(elim.profile.fresh, greaterThanOrEqualTo(freshLetters));
    expect(elim.profile.rank!, greaterThan(topRank));
    expect(elim.profile.skill, lessThan(max.profile.skill));
    // a gambler, when there is one, is risky
    final gam = ex.firstWhere((e) => e.behaviour == Behaviour.gambler);
    if (gam.qualifies) {
      expect(gam.profile.risk!, greaterThanOrEqualTo(gamblerRisk));
    }
  });

  testWidgets(
    'the closing examples: a closer that fits, a prober that does not',
    (tester) async {
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final seen = <Behaviour>[];
      final found = (await tester.runAsync(
        () => closingExamples(
          bank: bank,
          length: 4,
          draw: Draw.sigmoid,
          attempts: 150,
          onFound: (e) => seen.add(e.behaviour),
        ),
      ))!;
      expect(found, isNotEmpty);
      expect(seen.toSet(), found.map((e) => e.behaviour).toSet());
      for (final e in found) {
        final fits = e.question.eligible.contains(e.best.word);
        expect(
          fits,
          e.behaviour == Behaviour.closer,
          reason: e.behaviour.label,
        );
        // the other kind, when offered, wins less often than the best
        final other = e.other;
        if (other != null) {
          expect(other.win!, lessThan(e.best.win! + 1e-9));
        }
      }
      // each kind is found once
      expect(found.map((e) => e.behaviour).toSet(), hasLength(found.length));
    },
  );
}
