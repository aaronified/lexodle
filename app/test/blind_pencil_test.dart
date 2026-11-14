import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_pencil.dart';
import 'package:lexodle/logic.dart';

void main() {
  const none = <String, Mark>{};

  test('a doubled letter can be green in two places', () {
    final p = BlindPencil(3);
    final rows = [const BlindRow('abc', 2, 0), const BlindRow('cab', 2, 0)];
    expect(p.tap('a', 0, rows, none), isNull);
    expect(p.tap('a', 1, rows, none), isNull);
    expect(p.shown('a', 0, none), Mark.correct);
    expect(p.shown('a', 1, none), Mark.correct);
    expect(p.keyboard(none)['a'], Mark.correct);
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
}
