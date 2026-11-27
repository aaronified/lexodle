import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/mode_wheel.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';

void main() {
  test('mastermind is a brain, and every mode icon has its file', () {
    expect(modeIconName(GameMode.mastermind), 'brain');
    for (final m in GameMode.values) {
      expect(
        File('assets/icons/${modeIconName(m)}.svg').existsSync(),
        isTrue,
        reason: '${m.name} has no icon file',
      );
    }
  });

  test('the mastermind wins achievement wears the same brain', () {
    final a = achievements.firstWhere((a) => a.id == 'mastermind_wins');
    expect(a.icon, 'brain');
    expect(File('assets/icons/${a.icon}.svg').existsSync(), isTrue);
  });
}
