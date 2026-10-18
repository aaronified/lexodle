import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/modes.dart';

const four = ['house', 'light', 'brand', 'dying'];

void main() {
  test('modes: boards and extra tries', () {
    expect(GameMode.classic.multi, isFalse);
    expect(GameMode.quordle.boards, 4);
    expect(triesFor(GameMode.quordle, 6), 9);
    expect(triesFor(GameMode.sequence, 6), 10);
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
    test('quordle: every guess reaches every unsolved board', () {
      final g = MultiGame(GameMode.quordle, four, 9);
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

    test('quordle: lost when the tries run out', () {
      final g = MultiGame(GameMode.quordle, four, 2);
      g.guess('light');
      g.guess('house');
      expect(g.over, isTrue);
      expect(g.won, isFalse);
      expect(g.solvedCount, 2);
    });

    test('sequence: one board is live at a time, in order', () {
      final g = MultiGame(GameMode.sequence, four, 10);
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

    test('sequence: carried guesses are applied in order to the new board', () {
      final g = MultiGame(GameMode.sequence, [
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
    });

    test('sequence: won only when the last board is solved', () {
      final g = MultiGame(GameMode.sequence, four, 10);
      for (final w in ['house', 'light', 'brand']) {
        g.guess(w);
      }
      expect(g.won, isFalse);
      g.guess('dying');
      expect(g.won, isTrue);
      expect(g.guesses.length, 4);
    });
  });
}
