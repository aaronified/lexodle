import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/retired_words.dart';
import 'package:lexodle/words.dart';

void main() {
  late WordBank en;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    en = await WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
    );
  });

  String day(int n) => dailyShift(dailyRetireFrom, n);

  test('the retired words are all in the list, so guesses stay valid', () {
    for (final w in retiredEnglish) {
      expect(en.valid.contains(w), isTrue, reason: w);
    }
  });

  test('the dailies before the cut-off are drawn as they were', () {
    // two lists with the same odds (the second has a word that is never drawn
    // at the end) keep separate replays, so one can use a retired rule that
    // bites hard and the other none
    final w = en.curveWeights(5);
    final w2 = [...w, 0];
    for (var n = -26; n < 0; n++) {
      final d = day(n);
      expect(
        dailyCurveIndex('t', d, w, retired: (i) => i.isEven),
        dailyCurveIndex('t', d, w2),
        reason: d,
      );
    }
  });

  test('from the cut-off no daily answer is a retired word', () {
    for (var n = 0; n < 1500; n++) {
      final d = day(n);
      expect(retiredEnglish, isNot(contains(Daily.of(en, d)!.answer)));
      expect(
        retiredEnglish,
        isNot(contains(Daily.of(en, d, GameMode.lockdown)!.answer)),
      );
    }
  });

  test('a daily quartet and relay never holds a retired word either', () {
    for (var n = 0; n < 300; n++) {
      for (final m in [GameMode.quartet, GameMode.relay]) {
        for (final a in DailyMulti.of(en, m, day(n))!.answers) {
          expect(retiredEnglish, isNot(contains(a)));
        }
      }
    }
  });

  test('another language keeps its draw', () async {
    final fr = await WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
    );
    expect(Daily.of(fr, day(3))!.answer, isNotEmpty);
  });
}
