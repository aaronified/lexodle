import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

void main() {
  // The key of an opening names its file in the precomputed branch, and the web
  // and the phone have to work out the same one. These values were worked out on
  // the Dart VM and by the same code compiled to JavaScript (where a plain
  // 32-bit multiplication passes 2^53 and rounds), and agreed.
  test('the key of an opening is the same on every platform', () {
    final words = [
      for (var i = 0; i < 12000; i++)
        String.fromCharCodes([
          97 + i % 26,
          97 + (i ~/ 26) % 26,
          97 + (i ~/ 676) % 26,
          100 + i % 7,
          101 + i % 5,
        ]),
    ];
    final w = {
      for (var i = 0; i < words.length; i++)
        words[i]: i < 100 ? 10232929 - i * 7919 : 1000 - i % 997,
    };
    expect(openingKeyOf(words, words, w, false), '12000/12000/false/306626749');
    expect(openingKeyOf(words, words, w, true), '12000/12000/false/986090852');
    expect(
      openingKeyOf(words, words, null, false),
      '12000/12000/true/631271064',
    );
  });
}
