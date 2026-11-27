import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/mode_wheel.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';

void main() {
  test('each mode has its icon, and the file is there', () {
    expect(modeIconName(GameMode.classic), 'target');
    expect(modeIconName(GameMode.relay), 'chess-knight');
    expect(modeIconName(GameMode.blind), 'eye-off');
    expect(modeIconName(GameMode.mastermind), 'brain');
    for (final m in GameMode.values) {
      expect(
        File('assets/icons/${modeIconName(m)}.svg').existsSync(),
        isTrue,
        reason: '${m.name} has no icon file',
      );
    }
  });

  test('the knight has an eye: a hole in its head', () {
    final svg = File('assets/icons/chess-knight.svg').readAsStringSync();
    expect(svg, contains('fill-rule="evenodd"'));
  });

  test('the wins achievements wear their mode\'s icon', () {
    for (final (id, icon) in [
      ('blind_wins', 'eye-off'),
      ('mastermind_wins', 'brain'),
      ('relay_wins', 'chess-knight'),
    ]) {
      final a = achievements.firstWhere((a) => a.id == id);
      expect(a.icon, icon, reason: id);
      expect(File('assets/icons/${a.icon}.svg').existsSync(), isTrue);
    }
  });
}
