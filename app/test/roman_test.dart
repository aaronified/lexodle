import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No word list holds a Roman numeral: xviii passes a dictionary but is no word
/// to guess, and a daily could be set to it.
void main() {
  final roman = RegExp(
    r'^m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$',
  );

  test(
    'no list has a Roman numeral, and real words that look like one stay',
    () {
      final lists = Directory('assets/words')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'));
      expect(lists, isNotEmpty);
      for (final f in lists) {
        for (final line in f.readAsLinesSync()) {
          final w = line.split('\t').first;
          expect(roman.hasMatch(w), isFalse, reason: '$w in ${f.path}');
        }
      }
      // words made of the same letters, which are words
      final en = File('assets/words/en.txt').readAsStringSync();
      for (final w in ['vivid', 'civil', 'livid', 'mimic']) {
        expect(en, contains('\n$w\t'), reason: w);
      }
    },
  );
}
