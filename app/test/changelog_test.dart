import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/changelog.dart';

void main() {
  test('one summary per line, blanks dropped', () {
    expect(parseChangelog('a\n\n  b  \n'), ['a', 'b']);
    expect(parseChangelog(''), isEmpty);
  });
}
