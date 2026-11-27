import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/mode_wheel.dart';
import 'package:lexodle/modes.dart';

void main() {
  test('classic is a target, and the file is there', () {
    expect(modeIconName(GameMode.classic), 'target');
    expect(File('assets/icons/target.svg').existsSync(), isTrue);
  });
}
