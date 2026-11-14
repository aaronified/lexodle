import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/today_prefs.dart';

void main() {
  test('orderModes: the given order first, the rest in the app order', () {
    final out = orderModes(
      [GameMode.classic, GameMode.quartet, GameMode.relay],
      [GameMode.relay, GameMode.themed],
    );
    expect(out, [GameMode.relay, GameMode.classic, GameMode.quartet]);
  });

  test('dailyOrderFromJson drops damaged and repeated entries', () {
    final i = GameMode.relay.index;
    expect(dailyOrderFromJson([i, 'x', 999, -1, i]), [GameMode.relay]);
    expect(dailyOrderFromJson('nope'), isEmpty);
  });

  test('TodaySort.fromIndex falls back to status', () {
    expect(TodaySort.fromIndex(99), TodaySort.status);
    expect(TodaySort.fromIndex(TodaySort.name.index), TodaySort.name);
  });
}
