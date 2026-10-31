import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WordBank> english(WidgetTester tester) async => (await tester.runAsync(
    () async => WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
    ),
  ))!;

  testWidgets('a draw that keeps words apart does not favour doubled letters', (
    tester,
  ) async {
    final all = (await english(tester)).answers(5);
    final weights = List.filled(all.length, 1);
    final rng = Random(7);
    var repeated = 0, total = 0;
    for (var i = 0; i < 200; i++) {
      for (final w in chooseTargets(all, weights, 4, 0, rng)) {
        total++;
        if (hasRepeatedLetter(w)) repeated++;
      }
    }
    expect(repeated / total, lessThan(0.02));
  });

  testWidgets(
    'a daily quartet and relay from 2026-11-01 do not favour doubled letters',
    (tester) async {
      final b = await english(tester);
      var repeated = 0, total = 0;
      for (var day = 0; day < 40; day++) {
        final date = dailyShift(dailyShareFrom, day);
        for (final mode in [GameMode.quartet, GameMode.relay]) {
          for (final w in DailyMulti.of(b, mode, date)!.answers) {
            total++;
            if (hasRepeatedLetter(w)) repeated++;
          }
        }
      }
      // about a fifth of English words have a letter twice
      expect(repeated / total, lessThan(0.35));
    },
  );
}
