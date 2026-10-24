import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/guess_input.dart';

void main() {
  final letters = {...'abcdefghijklmnopqrstuvwxyz'.split('')};

  GuessInput typed(String s, [int length = 5]) {
    final g = GuessInput(length);
    for (final ch in s.split('')) {
      g.type(ch, letters);
    }
    return g;
  }

  test('typing fills the slots in order and parks when full', () {
    final g = typed('abcde');
    expect(g.word, 'abcde');
    expect(g.complete, isTrue);
    expect(g.cursor, 5);
    // a full row ignores more letters, as it always did
    expect(g.type('z', letters), -1);
    expect(g.word, 'abcde');
  });

  test('letters outside the language are ignored', () {
    final g = GuessInput(5);
    expect(g.type('1', letters), -1);
    expect(g.type('é', letters), -1);
    expect(g.cursor, 0);
  });

  test('a blank is a pencil mark: a space or an underscore types it', () {
    final g = GuessInput(5);
    g.type('a', letters);
    g.type(' ', letters);
    g.type('o', letters);
    g.type('_', letters);
    expect(g.slots, ['a', GuessInput.blank, 'o', GuessInput.blank, '']);
    expect(g.hasBlank, isTrue);
    expect(g.complete, isFalse);
  });

  test(
    'after a_ode the cursor waits on the blank, and filling it completes',
    () {
      final g = typed('a ode');
      expect(g.hasBlank, isTrue);
      expect(g.complete, isFalse);
      expect(g.cursor, 1);
      g.type('r', letters);
      expect(g.word, 'arode');
      expect(g.hasBlank, isFalse);
      expect(g.complete, isTrue);
      expect(g.cursor, 5);
    },
  );

  test('a row with an empty slot is not complete and has no blank', () {
    final g = typed('abc');
    expect(g.complete, isFalse);
    expect(g.hasBlank, isFalse);
  });

  test('backspace clears the last typed slot, as before', () {
    final g = typed('abc');
    expect(g.back(), 2);
    expect(g.slots, ['a', 'b', '', '', '']);
    expect(g.cursor, 2);
    g.back();
    g.back();
    expect(g.back(), -1);
    expect(g.cursor, 0);
  });

  test('backspace from a full row clears the last letter', () {
    final g = typed('abcde');
    expect(g.back(), 4);
    expect(g.word.substring(0, 4), 'abcd');
    expect(g.cursor, 4);
  });

  test('select moves the cursor; typing replaces that slot only', () {
    final g = typed('abcde');
    g.select(2);
    expect(g.type('x', letters), 2);
    expect(g.word, 'abxde');
    // nothing else was open, so the row is full again
    expect(g.cursor, 5);
  });

  test(
    'backspace on a selected letter clears it and keeps the cursor there',
    () {
      final g = typed('abcde');
      g.select(1);
      expect(g.back(), 1);
      expect(g.slots, ['a', '', 'c', 'd', 'e']);
      expect(g.cursor, 1);
      g.type('z', letters);
      expect(g.word, 'azcde');
    },
  );

  test('typing after a selected tile moves on to the next open slot', () {
    final g = GuessInput(5);
    g.select(3);
    g.type('d', letters);
    expect(g.cursor, 4);
    g.type('e', letters);
    // the end is reached, so it wraps to the first open slot
    expect(g.cursor, 0);
  });

  test('move steps the cursor and stops at both ends', () {
    final g = typed('ab');
    expect(g.cursor, 2);
    g.move(-1);
    expect(g.cursor, 1);
    g.move(-1);
    g.move(-1);
    g.move(-1);
    expect(g.cursor, 0, reason: 'stops at the left end');
    for (var i = 0; i < 9; i++) {
      g.move(1);
    }
    expect(g.cursor, 4, reason: 'stops on the last slot, not past it');
    expect(g.slots, ['a', 'b', '', '', ''], reason: 'moving writes nothing');
  });

  test('left from a full row selects the last letter; right does nothing', () {
    final g = typed('abcde');
    expect(g.cursor, 5);
    g.move(1);
    expect(g.cursor, 5);
    g.move(-1);
    expect(g.cursor, 4);
    g.type('z', letters);
    expect(g.word, 'abcdz');
  });

  test('moving onto a letter then typing replaces it', () {
    final g = typed('abc');
    g.move(-1);
    g.move(-1);
    g.type('x', letters);
    expect(g.slots, ['a', 'x', 'c', '', '']);
    expect(g.cursor, 3, reason: 'on to the next slot that is not a letter');
  });

  test('select ignores slots outside the row', () {
    final g = typed('ab');
    g.select(9);
    g.select(-1);
    expect(g.cursor, 2);
  });

  test('clear empties the row and rewinds the cursor', () {
    final g = typed('a ode');
    g.clear();
    expect(g.slots, ['', '', '', '', '']);
    expect(g.cursor, 0);
    expect(g.hasBlank, isFalse);
  });

  test('setWord fills the row, as the solver\'s use button does', () {
    final g = GuessInput(5)..setWord('crane');
    expect(g.word, 'crane');
    expect(g.complete, isTrue);
    expect(g.cursor, 5);
  });
}
