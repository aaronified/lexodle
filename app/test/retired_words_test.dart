import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/retired_abbreviations.dart';
import 'package:lexodle/retired_words.dart';
import 'package:lexodle/words.dart';

void main() {
  abbreviationsMain();
  laterMain();
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
      // (the whole list has them; the bank for guesses and free play does not)
      expect(en.daily.valid.contains(w), isTrue, reason: w);
      expect(en.valid.contains(w), isFalse, reason: w);
    }
  });

  test('the later retired words are in the list and apart from the first', () {
    for (final w in retiredEnglishLater) {
      expect(en.daily.valid.contains(w), isTrue, reason: w);
      expect(en.valid.contains(w), isFalse, reason: w);
      expect(retiredEnglish.contains(w), isFalse, reason: w);
    }
    expect(retiredEnglishLater, contains('intnl'));
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
        dailyCurveIndex(
          't',
          d,
          w,
          retired: (i, ds) => ds.compareTo(dailyRetireFrom) >= 0 && i.isEven,
        ),
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

void abbreviationsMain() {
  test('the abbreviations are in the whole list, out of the guesses, and never a daily', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final langs = await WordBank.languages();
    var checked = 0;
    for (final code in ['en', 'es', 'pt', 'nl']) {
      final bank = await WordBank.load(langs.firstWhere((l) => l.code == code));
      final set = retiredAbbreviations[code]!;
      expect(set, isNotEmpty, reason: code);
      for (final w in set) {
        // in the whole list, out of the guesses and of free play
        expect(bank.daily.valid.contains(w), isTrue, reason: '$code $w');
        expect(bank.valid.contains(w), isFalse, reason: '$code $w');
        expect(bank.answers(w.length), isNot(contains(w)), reason: '$code $w');
      }
      for (var n = 0; n < 700; n++) {
        final d = dailyShift(dailyRetireFromLater, n);
        expect(
          set,
          isNot(contains(Daily.of(bank, d)!.answer)),
          reason: '$code $d',
        );
        checked++;
      }
    }
    expect(checked, 2800);
  });
}

void laterMain() {
  late WordBank en;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    en = await WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
    );
  });

  String day(int n) => dailyShift(dailyRetireFromLater, n);

  test('until 27 nov the later words may still be drawn, as before', () {
    // the draw of a day before the cut-off does not look at the later set
    final w = en.curveWeights(5);
    final w2 = [...w, 0];
    for (var n = -20; n < 0; n++) {
      final d = day(n);
      expect(
        dailyCurveIndex(
          'u',
          d,
          w,
          retired: (i, ds) => retiredAnswer('en', en.answers(5)[i], ds),
        ),
        dailyCurveIndex(
          'u',
          d,
          w2,
          retired: (i, ds) =>
              retiredEnglish.contains(en.answers(5)[i]) &&
              ds.compareTo(dailyRetireFrom) >= 0,
        ),
        reason: d,
      );
    }
  });

  test('from 27 nov no daily answer is a later retired word', () {
    for (var n = 0; n < 1500; n++) {
      final d = day(n);
      expect(retiredEnglishLater, isNot(contains(Daily.of(en, d)!.answer)));
      expect(
        retiredEnglishLater,
        isNot(contains(Daily.of(en, d, GameMode.lockdown)!.answer)),
      );
    }
  });

  test('a daily quartet and relay never hold one from 27 nov', () {
    for (var n = 0; n < 200; n++) {
      for (final m in [GameMode.quartet, GameMode.relay]) {
        for (final a in DailyMulti.of(en, m, day(n))!.answers) {
          expect(retiredEnglishLater, isNot(contains(a)));
        }
      }
    }
  });
}
