import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';

const four = ['house', 'light', 'brand', 'dying'];

void main() {
  test('modes: boards and extra tries', () {
    expect(GameMode.classic.multi, isFalse);
    expect(GameMode.quartet.boards, 4);
    expect(triesFor(GameMode.quartet, 6), 9);
    expect(triesFor(GameMode.relay, 6), 10);
    expect(triesFor(GameMode.classic, 6), 6);
  });

  group('chooseTargets', () {
    // four families on disjoint letters: any one word from each of four
    // families shares nothing, two from the same family always do
    final words = [
      for (final fam in ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx'])
        for (var skip = 0; skip < 6; skip++)
          [
            for (var i = 0; i < 6; i++)
              if (i != skip) fam[i],
          ].join(),
    ];
    final weights = List.filled(words.length, 1);

    int overlaps(List<String> t) => [
      for (var i = 0; i < t.length; i++)
        for (var j = i + 1; j < t.length; j++) sharesLetter(t[i], t[j]),
    ].where((x) => x).length;

    test('four different words', () {
      final t = chooseTargets(words, weights, 4, 15, Random(1));
      expect(t.toSet().length, 4);
    });

    test('at 0% the words share no letter when the list allows it', () {
      // the families leave a disjoint choice available every time
      for (var seed = 0; seed < 40; seed++) {
        final t = chooseTargets(words, weights, 4, 0, Random(seed));
        expect(overlaps(t), 0, reason: '$t');
      }
    });

    test('at 30% words overlap more often than at 0%', () {
      int total(int pct) => [
        for (var s = 0; s < 200; s++)
          overlaps(chooseTargets(words, weights, 4, pct, Random(s))),
      ].fold(0, (a, b) => a + b);
      expect(total(30), greaterThan(total(0)));
    });

    test('falls back to the least overlap when none is possible', () {
      final same = ['aaaab', 'aaaac', 'aaaad', 'aaaae', 'aaaaf'];
      final t = chooseTargets(same, List.filled(5, 1), 4, 0, Random(2));
      expect(t.length, 4);
      expect(t.toSet().length, 4);
    });

    test('never returns more words than exist', () {
      final t = chooseTargets(['abcde', 'fghij'], [1, 1], 4, 0, Random(3));
      expect(t.length, 2);
    });
  });

  group('MultiGame', () {
    test('quartet: every guess reaches every unsolved board', () {
      final g = MultiGame(GameMode.quartet, four, 9);
      g.guess('light');
      expect(g.boards[1].solved, isTrue);
      expect(g.boards[0].marks.length, 1);
      g.guess('house');
      expect(g.boards[1].marks.length, 1, reason: 'a solved board stops');
      expect(g.boards[0].marks.length, 2);
      expect(g.solvedCount, 2);
      expect(g.won, isFalse);
      g.guess('brand');
      g.guess('dying');
      expect(g.won, isTrue);
      expect(g.over, isTrue);
    });

    test('quartet: lost when the tries run out', () {
      final g = MultiGame(GameMode.quartet, four, 2);
      g.guess('light');
      g.guess('house');
      expect(g.over, isTrue);
      expect(g.won, isFalse);
      expect(g.solvedCount, 2);
    });

    test('relay race: one board is live at a time, in order', () {
      final g = MultiGame(GameMode.relay, four, 10);
      expect(g.active, 0);
      expect(g.isLive(0), isTrue);
      expect(g.isLocked(1), isTrue);
      g.guess('light'); // not the first word: goes to board 0 only
      expect(g.boards[0].marks.length, 1);
      expect(g.boards[1].marks, isEmpty);
      g.guess('house'); // solves board 0; board 1 opens with 'light' applied
      expect(g.boards[0].solved, isTrue);
      expect(g.boards[1].solved, isTrue, reason: 'light was already guessed');
      expect(g.active, 2, reason: 'and the next one opens');
      expect(g.isLive(2), isTrue);
      expect(g.isLocked(3), isTrue);
    });

    test(
      'relay race: carried guesses are applied in order to the new board',
      () {
        final g = MultiGame(GameMode.relay, [
          'house',
          'brand',
          'light',
          'dying',
        ], 10);
        g.guess('dying');
        g.guess('house');
        expect(g.active, 1);
        expect(g.boards[1].marks.length, 2);
        expect(g.boards[1].solved, isFalse);
      },
    );

    test('relay race: won only when the last board is solved', () {
      final g = MultiGame(GameMode.relay, four, 10);
      for (final w in ['house', 'light', 'brand']) {
        g.guess(w);
      }
      expect(g.won, isFalse);
      g.guess('dying');
      expect(g.won, isTrue);
      expect(g.guesses.length, 4);
    });

    group('letter marks for the keyboard', () {
      test('per board, the best mark each letter has shown', () {
        final g = MultiGame(GameMode.quartet, four, 9);
        g.guess('light');
        g.guess('house');
        final marks = g.letterMarks();
        // brute force: for every board and letter, the best of its marks
        for (var b = 0; b < 4; b++) {
          final best = <String, Mark>{};
          for (final guess in g.guesses.take(g.boards[b].marks.length)) {
            final m = evaluate(four[b], guess);
            for (var i = 0; i < guess.length; i++) {
              final old = best[guess[i]];
              if (old == null || m[i].index < old.index) best[guess[i]] = m[i];
            }
          }
          for (final e in best.entries) {
            expect(marks[e.key]![b], e.value, reason: 'board $b ${e.key}');
          }
        }
        // hand-checked: 'l' is green on light (board 1), absent on house
        expect(marks['l']![1], Mark.correct);
        expect(marks['l']![0], Mark.absent);
        // 'h' is in the right place in house, which was guessed second
        expect(marks['h']![0], Mark.correct, reason: 'house, second guess');
        // a letter no guess has used is not there at all
        expect(marks['z'], isNull);
      });

      test('a relay race colours the keyboard by the active board alone', () {
        final g = MultiGame(GameMode.relay, four, 10);
        g.guess('light');
        g.guess('house'); // solves board 0; board 1 (light) opens, solved too
        final active = g.active!;
        expect(active, 2, reason: 'brand is the board on');
        final m = g.marksOf(active);
        // 'brand' vs the guesses carried onto it: exactly what evaluate says
        for (final guess in g.guesses) {
          final e = evaluate(four[active], guess);
          for (var i = 0; i < guess.length; i++) {
            expect(m[guess[i]]!.index, lessThanOrEqualTo(e[i].index));
          }
        }
        expect(m.containsKey('z'), isFalse);
      });

      test('a board that has not seen a letter has no mark for it', () {
        final g = MultiGame(GameMode.relay, four, 10);
        g.guess('light');
        // the relay is on board 0, so only it has been marked
        final m = g.letterMarks()['l']!;
        expect(m[0], isNotNull);
        expect(m.skip(1), everyElement(isNull));
      });

      test('a solved board keeps what it showed, and stops adding', () {
        final g = MultiGame(GameMode.quartet, four, 9);
        g.guess('light'); // solves board 1
        g.guess('dying');
        final m = g.letterMarks();
        expect(m['l']![1], Mark.correct);
        // 'y' came after board 1 was solved, so board 1 never saw it
        expect(m['y']![1], isNull);
        expect(m['y']![3], Mark.correct);
      });
    });
  });
}
