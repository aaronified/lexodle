import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

/// Skill, luck and daring under an answer law: every possible word equally
/// likely (weights null), or each by its weight.
void main() {
  const words = [
    'ream',
    'team',
    'seam',
    'beam',
    'lean',
    'mean',
    'meat',
    'beat',
  ];
  const weights = {
    'ream': 1,
    'team': 40,
    'seam': 3,
    'beam': 9,
    'lean': 20,
    'mean': 100,
    'meat': 7,
    'beat': 30,
  };
  final equal = {for (final w in words) w: 5};

  /// The metrics of [guess] when the answer is [answer], under [law].
  GuessMetrics score(
    String guess,
    String answer,
    Map<String, int>? law, {
    bool finalTry = false,
    int triesLeft = 4,
    double? best,
  }) {
    final after = filterEligible(words, guess, evaluate(answer, guess));
    return scoreGuess(
      words,
      guess,
      after.length,
      finalTry: finalTry,
      solved: guess == answer,
      triesLeft: finalTry ? 1 : triesLeft,
      weights: law,
      afterWords: after,
      best: best,
    );
  }

  /// The mean of [f] over the answers, each by its chance under [law].
  double mean(Map<String, int>? law, double Function(String answer) f) {
    var total = 0, sum = 0.0;
    for (final a in words) {
      final w = law?[a] ?? 1;
      total += w;
      sum += w * f(a);
    }
    return sum / total;
  }

  group('with equal weights it is the unweighted score', () {
    test('every metric is the same as with no weights', () {
      for (final g in ['team', 'lean', 'beat', 'zzzz']) {
        for (final a in words) {
          final u = score(g, a, null);
          final w = score(g, a, equal);
          expect(w.skill, closeTo(u.skill, 1e-9), reason: '$g/$a');
          expect(w.luck, closeTo(u.luck, 1e-9), reason: '$g/$a');
          expect(w.expected, closeTo(u.expected, 1e-9));
          expect(w.risk, closeTo(u.risk, 1e-9));
          expect(w.winChance, closeTo(u.winChance, 1e-12));
        }
      }
    });
  });

  group('luck has mean zero under the law the answer is drawn by', () {
    for (final entry in {'weighted': weights, 'equal': null}.entries) {
      test('${entry.key}: every guess, not the last try', () {
        for (final g in [...words, 'zzzz', 'ears']) {
          final m = mean(entry.value, (a) => score(g, a, entry.value).luck);
          expect(m, closeTo(0, 1e-9), reason: g);
        }
      });
      test('${entry.key}: every guess on the last try', () {
        for (final g in [...words, 'zzzz']) {
          final m = mean(
            entry.value,
            (a) => score(g, a, entry.value, finalTry: true).luck,
          );
          expect(m, closeTo(0, 1e-9), reason: g);
        }
      });
    }

    test(
      'weighted luck differs from equal luck when the weights are uneven',
      () {
        var differs = false;
        for (final a in words) {
          if ((score('team', a, weights).luck - score('team', a, null).luck)
                  .abs() >
              1e-6) {
            differs = true;
          }
        }
        expect(differs, isTrue);
      },
    );
  });

  group('skill under the weights', () {
    test('E is n times the sum of the squared chances of the groups', () {
      final m = score('team', 'mean', weights);
      final groups = <int, int>{};
      var total = 0;
      for (final w in words) {
        total += weights[w]!;
        final k = patternCode(w, 'team');
        groups[k] = (groups[k] ?? 0) + weights[w]!;
      }
      final want =
          words.length *
          groups.values.fold<double>(
            0,
            (a, m) => a + (m / total) * (m / total),
          );
      expect(m.expected, closeTo(want, 1e-9));
    });

    test('the best guess of the analysis scores 100, none more', () async {
      final land = await analyseGuesses(words, words, weights: weights);
      expect(land.skills.first, closeTo(100, 1e-9));
      expect(land.skills.every((s) => s <= 100 + 1e-9 && s >= -1e-9), isTrue);
      final top = land.top.first;
      final m = score(top.word, 'mean', weights, best: land.bestExpected);
      expect(m.skill, closeTo(100, 1e-9));
    });

    test('the analysis finds a different best under the weights', () async {
      final w = await analyseGuesses(words, words, weights: weights);
      final u = await analyseGuesses(words, words);
      expect(w.bestExpected, isNot(closeTo(u.bestExpected, 1e-9)));
    });

    test('two words: the best split scores 100 whatever the weights', () async {
      final two = ['team', 'mean'];
      final land = await analyseGuesses(two, two, weights: weights);
      expect(land.skills.first, closeTo(100, 1e-9));
      final m = scoreGuess(
        two,
        'team',
        1,
        weights: weights,
        afterWords: const ['team'],
        best: land.bestExpected,
      );
      expect(m.skill, closeTo(100, 1e-9));
    });
  });

  group('the last try', () {
    test('skill is the chance of winning against the best chance', () {
      // mean has the most weight, so it is the best last guess
      expect(score('mean', 'mean', weights, finalTry: true).skill, 100);
      final team = score('team', 'mean', weights, finalTry: true).skill;
      expect(team, closeTo(40 / 100 * 100, 1e-9));
      expect(score('zzzz', 'mean', weights, finalTry: true).skill, 0);
    });

    test('with equal chances any word that fits is 100, any other 0', () {
      expect(score('team', 'mean', null, finalTry: true).skill, 100);
      expect(score('zzzz', 'mean', null, finalTry: true).skill, 0);
    });

    test('a perfect split on the last try is not skill', () {
      // ears fits no clue pattern better than a word that fits, but cannot win
      expect(score('ears', 'mean', null, finalTry: true).skill, 0);
    });

    test('luck is the outcome less the weighted chance', () {
      final won = score('team', 'team', weights, finalTry: true).luck;
      final lost = score('team', 'mean', weights, finalTry: true).luck;
      final chance = 40 / words.fold<int>(0, (a, w) => a + weights[w]!);
      expect(won, closeTo((1 - chance) * 100, 1e-9));
      expect(lost, closeTo(-chance * 100, 1e-9));
    });

    test('withBest leaves a last try skill alone', () {
      final m = score('team', 'mean', weights, finalTry: true);
      expect(m.withBest(3).skill, m.skill);
    });
  });

  group('daring under the weights', () {
    test('the chance of winning now is the guess\'s share of the weight', () {
      final total = words.fold<int>(0, (a, w) => a + weights[w]!);
      expect(
        score('mean', 'beat', weights).winChance,
        closeTo(100 / total, 1e-12),
      );
      expect(
        score('team', 'beat', weights).winChance,
        closeTo(40 / total, 1e-12),
      );
      expect(score('zzzz', 'beat', weights).winChance, 0);
      expect(
        score('team', 'beat', null).winChance,
        closeTo(1 / words.length, 1e-12),
      );
    });

    test('a likelier word is less daring, the rest equal', () {
      double daring(double win) =>
          daringOf(possible: true, winChance: win, skill: 50, triesLeft: 4);
      expect(daring(.6), lessThan(daring(.1)));
    });
  });

  group('the risk of a split', () {
    test('equal weights give the usual risk, a tail more', () {
      final u = score('team', 'mean', null).risk;
      final w = score('team', 'mean', weights).risk;
      expect(u, greaterThanOrEqualTo(0));
      expect(w, greaterThanOrEqualTo(0));
      expect(splitRiskMass([1, 1, 1, 1]), closeTo(0, 1e-12));
      expect(splitRiskMass([97, 1, 1, 1]), greaterThan(0.1));
    });
  });

  group('the pool landed in', () {
    test(
      'is the landed mass over the total times the words, when weighted',
      () {
        final m = score('team', 'mean', weights);
        final after = filterEligible(words, 'team', evaluate('mean', 'team'));
        final total = words.fold<int>(0, (a, w) => a + weights[w]!);
        final mass = after.fold<int>(0, (a, w) => a + weights[w]!);
        expect(m.landedSize, closeTo(mass * words.length / total, 1e-9));
        expect(m.landedSize, isNot(m.after.toDouble()));
      },
    );

    test('is the word count when the words are equally likely', () {
      final m = score('team', 'mean', null);
      expect(m.landedSize, closeTo(m.after.toDouble(), 1e-9));
    });
  });

  group('the last try comment', () {
    test('a word that fits but cannot be the answer says so', () {
      // the daily's list holds only some words: ears-like probe fits the clues
      final m = scoreGuess(
        ['team', 'mean'],
        'beam',
        2,
        finalTry: true,
        triesLeft: 1,
      );
      expect(m.possible, isFalse);
      final text = stepComment(
        m: m,
        picks: const [],
        after: const [],
        solved: false,
        finalTry: true,
        guessFits: true,
        guessIsPossible: false,
      );
      expect(text, contains('fits the clues'));
      expect(text, contains('could not win'));
      expect(text, isNot(contains('does not fit')));
    });
  });
}
