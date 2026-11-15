import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';

void main() {
  test('splitGroups counts the words by the colours a guess shows', () {
    final words = ['crane', 'crate', 'slate', 'stare', 'trace'];
    final groups = splitGroups(words, 'crane');
    expect(groups.fold<int>(0, (n, g) => n + g.$2), words.length);
    // sorted: the biggest first
    for (var i = 1; i < groups.length; i++) {
      expect(groups[i - 1].$2, greaterThanOrEqualTo(groups[i].$2));
    }
    // the guess itself is its own group, all green
    final win = markCode(List.filled(5, Mark.correct));
    expect(groups.where((g) => g.$1 == win).single.$2, 1);
  });

  test('markCode matches patternCode', () {
    for (final t in ['crane', 'slate', 'trace']) {
      expect(markCode(evaluate(t, 'crate')), patternCode(t, 'crate'));
    }
  });
}
