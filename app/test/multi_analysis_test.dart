import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_analysis.dart';
import 'package:lexodle/words.dart';

GuessMetrics gm(String g, double skill, double luck, int before, int after) =>
    GuessMetrics(
      guess: g,
      skill: skill,
      luck: luck,
      before: before,
      after: after,
      expected: 1,
      groups: 1,
      largest: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the weights', () {
    test('log2 of the words left, and one bit at least', () {
      expect(boardWeight(1), 1);
      expect(boardWeight(2), 1);
      expect(boardWeight(8), closeTo(3, 1e-9));
      expect(boardWeight(1024), closeTo(10, 1e-9));
    });

    test('a guess scores the average of its boards, weighted by them', () {
      // 8 words left on one board (3 bits) at skill 50, 2 on another (1 bit)
      // at skill 100: (3 * 50 + 1 * 100) / 4
      final step = MultiStep(
        'crane',
        [
          BoardStep(0, gm('crane', 50, 20, 8, 3), false),
          BoardStep(1, gm('crane', 100, -10, 2, 1), true),
        ],
        const [[], []],
        finalTry: false,
      );
      expect(step.skill, closeTo(62.5, 1e-9));
      expect(step.luck, closeTo((3 * 20 + 1 * -10) / 4, 1e-9));
      expect(step.solvedNow, 1);
    });

    test('a board with one word left counts one bit, hit or miss', () {
      MultiStep one(double skill) => MultiStep(
        'x',
        [
          BoardStep(0, gm('x', 80, 0, 16, 4), false), // 4 bits at 80
          BoardStep(1, gm('x', skill, 0, 1, 1), skill == 100),
        ],
        const [[], []],
        finalTry: false,
      );
      expect(one(100).skill, closeTo((4 * 80 + 100) / 5, 1e-9));
      expect(one(0).skill, closeTo((4 * 80) / 5, 1e-9));
    });
  });

  group('played against the real word list', () {
    late WordBank bank;
    late List<String> words;

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      );
      words = bank.guessable(5);
    });

    MultiGame play(GameMode mode, int seed, {int tries = 9, int guesses = 6}) {
      final rng = Random(seed);
      final answers = chooseTargets(
        bank.answers(5),
        bank.answerWeights(5),
        4,
        10,
        rng,
      );
      final g = MultiGame(mode, answers, tries, words: words);
      // guess common words, then words that fit the first live board
      for (var i = 0; i < guesses && !g.over; i++) {
        final live = [
          for (var b = 0; b < 4; b++)
            if (g.isLive(b)) b,
        ];
        final fits = g.eligible[live.first];
        final pick = i < 2
            ? words[rng.nextInt(300)]
            : fits[rng.nextInt(fits.length)];
        if (g.guesses.contains(pick)) continue;
        g.guess(pick);
      }
      return g;
    }

    for (final mode in [GameMode.quartet, GameMode.relay]) {
      test('${mode.label}: the answer is never ruled out, counts chain', () {
        for (var seed = 0; seed < 6; seed++) {
          final g = play(mode, seed);
          for (var b = 0; b < 4; b++) {
            if (g.boards[b].marks.isEmpty) continue;
            expect(
              g.eligible[b],
              contains(g.boards[b].answer),
              reason: 'board $b seed $seed',
            );
            // exactly the words that give every mark this board showed
            final brute = [
              for (final w in words)
                if (Iterable<int>.generate(g.boards[b].marks.length).every(
                  (r) => _same(evaluate(w, g.guesses[r]), g.boards[b].marks[r]),
                ))
                  w,
            ];
            expect(g.eligible[b], brute, reason: 'board $b seed $seed');
          }
          // each step's "after" is the next step's "before" for that board
          for (var s = 0; s + 1 < g.steps.length; s++) {
            for (final bs in g.steps[s].boards) {
              for (var k = 0; k < g.steps[s + 1].boards.length; k++) {
                final next = g.steps[s + 1].boards[k];
                if (next.board == bs.board) {
                  expect(next.metrics.before, bs.metrics.after);
                }
              }
            }
          }
        }
      });

      test(
        '${mode.label}: a played step scores what the picker would',
        () async {
          for (var seed = 0; seed < 4; seed++) {
            final g = play(mode, seed, guesses: 5);
            for (final step in g.steps) {
              // every real guess, the played one included: E* per board
              final land = await analyseMulti(step.liveBefore, {
                step.guess,
                ...multiCandidates(step.liveBefore, words),
              }, k: 100000);
              final refined = step.withBests(land.bests);
              final pick = land.picks.firstWhere((p) => p.word == step.guess);
              expect(
                pick.skill,
                closeTo(refined.skill, 1e-9),
                reason: '${step.guess} seed $seed',
              );
            }
          }
        },
      );

      test(
        '${mode.label}: the best pick is never worse than the guess',
        () async {
          final g = play(mode, 3, guesses: 3);
          for (final step in g.steps) {
            final land = await analyseMulti(step.liveBefore, {
              step.guess,
              ...multiCandidates(step.liveBefore, words),
            }, k: 1);
            final refined = step.withBests(land.bests);
            expect(
              land.picks.single.skill,
              greaterThanOrEqualTo(refined.skill - 1e-9),
            );
            expect(refined.skill, inInclusiveRange(0, 100));
          }
        },
      );

      test(
        '${mode.label}: skill is measured against each board\'s best',
        () async {
          final g = play(mode, 2, guesses: 3);
          for (final step in g.steps) {
            final land = await analyseMulti(step.liveBefore, {
              step.guess,
              ...multiCandidates(step.liveBefore, words),
            });
            expect(land.bests.length, step.boards.length);
            final refined = step.withBests(land.bests);
            for (var i = 0; i < refined.boards.length; i++) {
              final m = refined.boards[i].metrics;
              expect(m.ready, isTrue);
              expect(m.best, closeTo(land.bests[i], 1e-12));
              // never better than the best real guess found, never below 0
              expect(m.expected, greaterThanOrEqualTo(land.bests[i] - 1e-9));
              expect(m.skill, inInclusiveRange(0, 100));
            }
          }
        },
      );
    }

    test('a provisional step is not ready until its bests arrive', () async {
      final g = MultiGame(
        GameMode.quartet,
        ['house', 'light', 'brand', 'dying'],
        9,
        words: words,
        provisional: true,
      );
      g.guess('crane');
      expect(g.steps.single.ready, isFalse);
      final land = await analyseMulti(
        g.steps.single.liveBefore,
        words.take(400),
      );
      final refined = g.steps.single.withBests(land.bests);
      expect(refined.ready, isTrue);
      expect(refined.skill, inInclusiveRange(0, 100));
    });

    test(
      'boards that share their words are scored once, at the start',
      () async {
        final g = MultiGame(
          GameMode.quartet,
          ['house', 'light', 'brand', 'dying'],
          9,
          words: words,
        );
        expect(identical(g.eligible[0], g.eligible[1]), isTrue);
        final land = await analyseMulti([
          for (final b in g.eligible) b,
        ], words.take(300));
        expect(
          land.bests.toSet().length,
          1,
          reason: 'the same words, the same E*',
        );
      },
    );

    test('quartet: solved boards drop out of later steps', () {
      final g = MultiGame(
        GameMode.quartet,
        ['house', 'light', 'brand', 'dying'],
        9,
        words: words,
      );
      g.guess('light');
      g.guess('house');
      expect(g.steps[0].boards.map((b) => b.board), [0, 1, 2, 3]);
      expect(g.steps[0].boards[1].solved, isTrue);
      expect(g.steps[1].boards.map((b) => b.board), [0, 2, 3]);
      expect(g.steps[1].liveBefore.length, 3);
      // a solved board is a 1-word pool afterwards: it had one word left
      expect(g.steps[0].boards[1].metrics.after, 1);
    });

    test('quartet: every board starts with the whole list', () {
      final g = MultiGame(
        GameMode.quartet,
        ['house', 'light', 'brand', 'dying'],
        9,
        words: words,
      );
      expect(g.heads.map((h) => h.words), everyElement(words.length));
      expect(g.heads.length, 4);
    });

    test('relay race: the board on is judged alone, later ones wait', () {
      final g = MultiGame(
        GameMode.relay,
        ['house', 'light', 'brand', 'dying'],
        10,
        words: words,
      );
      g.guess('crane');
      expect(g.steps.single.boards.length, 1);
      expect(g.steps.single.boards.single.board, 0);
      expect(g.eligible[1].length, words.length, reason: 'not opened yet');
      expect(g.heads.length, 1);
    });

    test(
      'relay race: a board opens with the earlier guesses already applied',
      () {
        final g = MultiGame(
          GameMode.relay,
          ['house', 'light', 'brand', 'dying'],
          10,
          words: words,
        );
        g.guess('crane');
        g.guess('stone');
        g.guess(
          'house',
        ); // solves board 0, opens board 1 with three guesses on it
        final opened = g.steps.last.opened.single;
        expect(opened.board, 1);
        expect(opened.opensAfter, 3);
        final brute = [
          for (final w in words)
            if ([
              'crane',
              'stone',
              'house',
            ].every((x) => _same(evaluate(w, x), evaluate('light', x))))
              w,
        ];
        expect(opened.words, brute.length);
        expect(opened.total, words.length);
        expect(
          opened.cut,
          greaterThan(90),
          reason: 'three guesses narrow a lot',
        );
        expect(g.heads.last, same(opened));
      },
    );

    test(
      'the last try: luck is the chance of the pick, over the live boards',
      () {
        final g = MultiGame(
          GameMode.quartet,
          ['house', 'light', 'brand', 'dying'],
          2,
          words: words,
        );
        g.guess('crane');
        g.guess('light'); // last try; solves one board of four
        final last = g.steps.last;
        expect(last.finalTry, isTrue);
        for (var i = 0; i < last.boards.length; i++) {
          final b = last.boards[i];
          final n = b.metrics.before;
          // the chance of a win is 1 in n if the guess fits the board, else 0
          final fits = last.liveBefore[i].contains('light');
          final expected = ((b.solved ? 1 : 0) - (fits ? 1 / n : 0)) * 100;
          expect(b.metrics.luck, closeTo(expected, 1e-9));
        }
        expect(g.steps.first.finalTry, isFalse);
      },
    );

    test('without the words it is only the rules, as before', () {
      final g = MultiGame(GameMode.quartet, [
        'house',
        'light',
        'brand',
        'dying',
      ], 9);
      g.guess('light');
      expect(g.steps, isEmpty);
      expect(g.heads, isEmpty);
      expect(g.boards[1].solved, isTrue);
    });
  });
}

bool _same(List<Mark> a, List<Mark> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
