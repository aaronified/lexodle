import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

void main() {
  const abc = 'abcdefghijklmnopqrstuvwxyz';
  final letters = abc.split('');

  Set<String> ruled(String answer, List<String> guesses) => ruledOut(
    guesses,
    [for (final g in guesses) evaluate(answer, g)],
    answer.length,
    letters,
  );

  test('nothing is ruled out until every letter of the word is found', () {
    expect(ruled('young', ['tares', 'child']), isEmpty);
    // o, u, g and l found: four of five
    expect(ruled('young', ['tares', 'child', 'bumpy']), isEmpty);
  });

  test('once all five are found, every other letter is out', () {
    // the screen of the report: o, u, g, l, m make the five letters of the word
    final out = ruled('mogul', ['tares', 'child', 'young', 'bumpy']);
    expect(out, containsAll(['t', 'a', 'r', 'e', 's', 'c', 'h', 'i', 'd']));
    expect(out, isNot(containsAll(['o'])));
    for (final l in ['m', 'o', 'g', 'u', 'l']) {
      expect(out.contains(l), isFalse, reason: l);
    }
    expect(out.length, 21);
  });

  test('a repeated letter counts as many times as one guess showed it', () {
    // sleep has two e: one guess showing both e settles the five letters
    final out = ruled('sleep', ['geese', 'plank']);
    // s, l, e, e, p are found: g and k and the rest are out
    expect(out.contains('g'), isTrue);
    expect(out.contains('s'), isFalse);
    expect(out.contains('e'), isFalse);
    expect(out.contains('p'), isFalse);
    expect(out.contains('l'), isFalse);
  });

  test('a letter shown once of two is not enough to close the word', () {
    // the second e of sleep is not found yet: four letters of five
    expect(ruled('sleep', ['slate', 'plump']), isEmpty);
  });
}
