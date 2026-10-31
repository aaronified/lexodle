import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/modes.dart';

void main() {
  const words = ['crane', 'sloth', 'pudgy', 'quick'];

  MultiGame play(GameMode mode, List<String> guesses) {
    final g = MultiGame(mode, words, 12);
    for (final w in guesses) {
      g.guess(w);
    }
    return g;
  }

  group('one guess for each of the later three words', () {
    test('a quartet: the others on the guesses after the first', () {
      expect(
        play(GameMode.quartet, [
          'zzzzz',
          'crane',
          'sloth',
          'pudgy',
          'quick',
        ]).lateSingles,
        isTrue,
      );
      // a wasted guess in the middle
      expect(
        play(GameMode.quartet, [
          'crane',
          'sloth',
          'zzzzz',
          'pudgy',
          'quick',
        ]).lateSingles,
        isFalse,
      );
      // not won
      expect(play(GameMode.quartet, ['crane', 'sloth']).lateSingles, isFalse);
    });

    test('a relay race: each later word with a guess of its own', () {
      expect(
        play(GameMode.relay, [
          'zzzzz',
          'crane',
          'sloth',
          'pudgy',
          'quick',
        ]).lateSingles,
        isTrue,
      );
      expect(
        play(GameMode.relay, [
          'crane',
          'zzzzz',
          'sloth',
          'pudgy',
          'quick',
        ]).lateSingles,
        isFalse,
      );
    });

    test('a relay race: a free ride counts', () {
      // sloth is guessed while the first word is on, so it is solved when it opens
      expect(
        play(GameMode.relay, ['sloth', 'crane', 'pudgy', 'quick']).lateSingles,
        isTrue,
      );
    });
  });
}
