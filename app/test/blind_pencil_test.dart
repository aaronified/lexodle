import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_pencil.dart';
import 'package:lexodle/logic.dart';

void main() {
  const none = <String, Mark>{};

  test('a letter green elsewhere starts yellow, then green beside it', () {
    final p = BlindPencil(5);
    final rows = [const BlindRow('abcde', 1, 0), const BlindRow('xxaxa', 2, 0)];
    p.tap('a', 0, rows, none);
    expect(p.shown('a', 0, none), Mark.correct);
    p.tap('a', 2, rows, none);
    expect(p.shown('a', 2, none), Mark.present);
    expect(p.shown('a', 0, none), Mark.correct);
    // the rows allow two greens: both stay
    p.tap('a', 2, rows, none);
    expect(p.shown('a', 2, none), Mark.correct);
    expect(p.shown('a', 0, none), Mark.correct);
    expect(p.keyboard(none)['a'], Mark.correct);
  });

  test('when two greens cannot fit, the earlier one turns yellow', () {
    final p = BlindPencil(3);
    // one guess with a at both places and one green: only one can be green
    final rows = [const BlindRow('aab', 1, 1)];
    p.tap('a', 0, rows, none);
    p.tap('a', 1, rows, none);
    expect(p.shown('a', 1, none), Mark.present);
    p.tap('a', 1, rows, none);
    expect(p.shown('a', 1, none), Mark.correct);
    expect(p.shown('a', 0, none), Mark.present);
  });

  test('once every letter is found the rest of the keyboard is grey', () {
    final p = BlindPencil(2);
    final rows = [const BlindRow('ab', 1, 0), const BlindRow('cd', 0, 1)];
    const letters = ['a', 'b', 'c', 'd', 'e'];
    p.tap('a', 0, rows, none);
    expect(p.keyboard(none, letters)['e'], isNull);
    p.tap('c', 0, rows, none);
    final k = p.keyboard(none, letters);
    expect(k['e'], Mark.absent);
    expect(k['b'], Mark.absent);
    expect(k['a'], Mark.correct);
  });

  test('no more letters than the length are in the word', () {
    final p = BlindPencil(2);
    final rows = [const BlindRow('ab', 2, 0), const BlindRow('cx', 2, 0)];
    p.tap('a', 0, rows, none);
    p.tap('b', 1, rows, none);
    // a third letter cannot be green or yellow, so it stays unmarked
    expect(p.tap('c', 0, rows, none), isNotNull);
    expect(p.shown('c', 0, none), isNull);
  });

  test('two letters are not green in one position', () {
    final p = BlindPencil(3);
    final rows = [const BlindRow('abc', 2, 0), const BlindRow('xbz', 2, 0)];
    p.tap('a', 0, rows, none);
    final why = p.tap('x', 0, rows, none);
    expect(why, 'position 1 is already green with a');
    expect(p.shown('x', 0, none), Mark.present);
  });

  test('yellow in every other position leaves only green', () {
    final p = BlindPencil(3);
    final rows = [
      const BlindRow('abc', 1, 1),
      const BlindRow('bac', 1, 1),
      const BlindRow('bca', 1, 1),
    ];
    p.tap('a', 0, rows, none);
    p.tap('a', 0, rows, none);
    p.tap('a', 1, rows, none);
    p.tap('a', 1, rows, none);
    expect(p.yellow['a'], {0, 1});
    expect(p.tap('a', 2, rows, none), isNull);
    expect(p.shown('a', 2, none), Mark.correct);
    // yellow and grey are passed over
    final why = p.tap('a', 2, rows, none);
    expect(why, 'already yellow in all other available positions');
    expect(p.shown('a', 2, none), isNull);
  });

  test('a letter that is yellow cannot be grey', () {
    final p = BlindPencil(5);
    final rows = [const BlindRow('abcde', 1, 1), const BlindRow('xaxxx', 1, 1)];
    p.tap('a', 0, rows, none);
    p.tap('a', 0, rows, none);
    expect(p.shown('a', 0, none), Mark.present);
    // yellow -> grey is allowed only when this was its one mark
    p.tap('a', 1, rows, none);
    p.tap('a', 1, rows, none);
    expect(p.tap('a', 1, rows, none), 'a is already green or yellow');
    expect(p.grey, isEmpty);
  });

  test('a row cannot show more than its counts', () {
    final p = BlindPencil(3);
    final rows = [const BlindRow('abc', 0, 1)];
    final why = p.tap('a', 0, rows, none);
    expect(why, 'row 1 has only 0 in place');
    expect(p.shown('a', 0, none), Mark.present);
  });

  test('the counts settle letters', () {
    final out = BlindPencil.deduce([
      const BlindRow('crane', 0, 0),
    ], 'abcdefg'.split(''));
    expect(out.keys.toSet(), {'c', 'r', 'a', 'n', 'e'});
    expect(out.values.toSet(), {Mark.absent});
    final all = BlindPencil.deduce([
      const BlindRow('abcde', 3, 2),
    ], 'abcdefg'.split(''));
    expect(all['a'], Mark.present);
    expect(all['f'], Mark.absent);
    final p = BlindPencil(5);
    expect(
      p.tap('f', 0, [const BlindRow('abcde', 3, 2)], all),
      'ruled out by the counts',
    );
  });

  test('guesses with no letter in common settle the rest together', () {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    // tares has 3 right letters, found 2: five letters, all of them known
    final out = BlindPencil.deduce([
      const BlindRow('tares', 0, 3),
      const BlindRow('found', 0, 2),
    ], letters.split(''));
    for (final ch in letters.split('')) {
      if ('taresfound'.contains(ch)) {
        expect(out[ch], isNull, reason: ch);
      } else {
        expect(out[ch], Mark.absent, reason: ch);
      }
    }
    // guesses that share a letter may count it twice: nothing is settled
    final shared = BlindPencil.deduce([
      const BlindRow('tares', 0, 3),
      const BlindRow('stand', 0, 2),
    ], letters.split(''));
    expect(shared, isEmpty);
    // not enough yet: 3 and 1 make 4 of 5
    final short = BlindPencil.deduce([
      const BlindRow('tares', 0, 3),
      const BlindRow('found', 0, 1),
    ], letters.split(''));
    expect(short, isEmpty);
    // three guesses can add up too, with a guess that found nothing
    final three = BlindPencil.deduce([
      const BlindRow('tares', 0, 3),
      const BlindRow('found', 0, 2),
      const BlindRow('lymph', 0, 0),
    ], letters.split(''));
    expect(three['z'], Mark.absent);
    expect(three['l'], Mark.absent);
  });

  test('the helper colours only what no other colour can be, and it stays', () {
    // crane has 0 in place and 2 right: no tile of it can be green
    final rows = [const BlindRow('crane', 0, 2), const BlindRow('abcde', 0, 5)];
    final d = BlindPencil.deduce(rows, 'abcdefg'.split(''));
    final f = BlindPencil.forcedTiles(rows, d);
    // abcde has all five letters in the word, none in place: every tile yellow
    expect(f['a@0'], Mark.present);
    expect(f['e@4'], Mark.present);
    final p = BlindPencil(5);
    expect(p.shown('a', 0, d, f), Mark.present);
    // a forced tile cannot be changed
    expect(p.tap('a', 0, rows, d, f), 'set by the helper');
    expect(p.shown('a', 0, d, f), Mark.present);
    // a letter the counts only put in the word is left to the player
    final one = [const BlindRow('abcde', 1, 4)];
    final d1 = BlindPencil.deduce(one, 'abcdefg'.split(''));
    final f1 = BlindPencil.forcedTiles(one, d1);
    expect(f1, isEmpty);
    expect(p.shown('a', 0, d1, f1), isNull);
  });

  test(
    'a row with nothing in place or nothing elsewhere settles its tiles',
    () {
      final rows = [const BlindRow('abcde', 5, 0)];
      final d = BlindPencil.deduce(rows, 'abcdefg'.split(''));
      final f = BlindPencil.forcedTiles(rows, d);
      expect(f['c@2'], Mark.correct);
    },
  );
}
