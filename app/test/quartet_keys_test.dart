import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

void main() {
  const a = Mark.absent, g = Mark.correct;

  test('a letter nobody tried stays a plain key while one board is done', () {
    // board 4 has all its letters, so it rules q out; the other boards do not
    final keys = quartetKeys(
      guessed: const {},
      live: [true, true, true, true],
      ruled: [
        {},
        {},
        {},
        {'q'},
      ],
    );
    expect(keys['q'], [null, null, null, null]);
  });

  test('every board in play ruling a letter out greys the whole key', () {
    final keys = quartetKeys(
      guessed: const {},
      live: [true, true, true, true],
      ruled: [
        {'q'},
        {'q'},
        {'q'},
        {'q'},
      ],
    );
    expect(keys['q'], [a, a, a, a]);
  });

  test('a solved board does not hold the others back', () {
    final keys = quartetKeys(
      guessed: const {},
      live: [false, true, true, true],
      ruled: [
        {},
        {'q'},
        {'q'},
        {'q'},
      ],
    );
    expect(keys['q'], [a, a, a, a]);
  });

  test('what the guesses marked is kept, and a found letter is not greyed', () {
    final keys = quartetKeys(
      guessed: {
        'e': [g, null, null, null],
        't': [a, a, null, null],
      },
      live: [true, true, true, true],
      // (a board never rules out a letter it has found)
      ruled: [
        {'t'},
        {'e', 't'},
        {'e', 't'},
        {'e', 't'},
      ],
    );
    // green on one board: the key is not certain on every board
    expect(keys['e'], [g, null, null, null]);
    // absent on two and ruled out on the rest: all grey
    expect(keys['t'], [a, a, a, a]);
  });

  test('a grey hint shows on its own board, and all grey when all agree', () {
    var keys = quartetKeys(
      guessed: const {},
      live: [true, true, true, true],
      ruled: [{}, {}, {}, {}],
      hinted: {
        'z': {1},
      },
    );
    expect(keys['z'], [null, a, null, null]);
    keys = quartetKeys(
      guessed: const {},
      live: [true, true, true, true],
      ruled: [
        {'z'},
        {},
        {'z'},
        {'z'},
      ],
      hinted: {
        'z': {1},
      },
    );
    expect(keys['z'], [a, a, a, a]);
  });
}
