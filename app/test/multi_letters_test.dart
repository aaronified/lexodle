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
    'a daily quartet and relay from 2026-11-01 have at most two words with a doubled letter',
    (tester) async {
      final b = await english(tester);
      for (var day = 1; day <= 10; day++) {
        final date = '2026-11-${day.toString().padLeft(2, '0')}';
        for (final mode in [GameMode.quartet, GameMode.relay]) {
          final d = DailyMulti.of(b, mode, date)!;
          expect(
            d.answers.where(hasRepeatedLetter).length,
            lessThanOrEqualTo(2),
            reason: '$date $mode',
          );
        }
      }
    },
  );
}
