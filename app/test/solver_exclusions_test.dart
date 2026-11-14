import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/clock.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/solver_exclusions.dart';
import 'package:lexodle/words.dart';

/// A progress map that cannot be read.
class _Broken extends MapBase<String, Map<String, dynamic>> {
  @override
  Iterable<MapEntry<String, Map<String, dynamic>>> get entries =>
      throw StateError('broken');
  @override
  Map<String, dynamic>? operator [](Object? key) => null;
  @override
  void operator []=(String key, Map<String, dynamic> value) {}
  @override
  void clear() {}
  @override
  Iterable<String> get keys => const [];
  @override
  Map<String, dynamic>? remove(Object? key) => null;
}

WordBank _bank(Map<int, List<String>> words, {bool anyChar = false}) =>
    WordBank.custom(
      const Language('en', 'English', 'English', [5]),
      words,
      {for (final e in words.entries) e.key: List.filled(e.value.length, 1)},
      curveOrigin: WordBank.defaultCurveOrigin,
      curveWidth: WordBank.defaultCurveWidth,
      anyChar: anyChar,
    );

// a few hundred distinct five-letter strings, enough for the dailies to draw
// from
final _fives = <String>{
  for (var i = 0; i < 600; i++)
    String.fromCharCodes([
      for (final n in [i, i ~/ 26, i * 7, i * 3 + 1, i ~/ 26 * 5 + 2])
        97 + n % 26,
    ]),
}.toList();

final _equations = [
  '12+18=30',
  '15+25=40',
  '13+17=30',
  '14+26=40',
  '16+24=40',
  '11+19=30',
];

void main() {
  late WordBank bank;
  late String today;

  setUp(() {
    dailyClock = () => DateTime.utc(2026, 11, 14, 12);
    today = dailyDate();
    appState.progress = {};
    appState.daily.clear();
    bank = _bank({5: _fives});
  });
  tearDown(() => dailyClock = TrustedClock.now);

  String answer(GameMode m) => Daily.of(bank, today, m)!.answer;

  test(
    'a saved free game keeps its target out, in its language and length',
    () {
      appState.progress['p|en|classic|5|6'] = {'a': 'crane'};
      appState.progress['p|fr|classic|5|6'] = {'a': 'amour'};
      appState.progress['p|en|classic|4|6'] = {'a': 'cafe'};
      expect(SolverExclusions.words('en', 5), {'crane'});
      expect(SolverExclusions.words('fr', 5), {'amour'});
      expect(SolverExclusions.words('en', 4), {'cafe'});
      expect(SolverExclusions.words('de', 5), isEmpty);
    },
  );

  test(
    'a saved quartet, blind or lockdown game counts, and so do all words',
    () {
      appState.progress['p|en|quartet|5|9'] = {
        'a': ['crane', 'slate', 'brick', 'mount'],
      };
      appState.progress['p|en|blind|5|10'] = {'a': 'ghost'};
      appState.progress['p|en|lockdown|5|6'] = {'a': 'plumb'};
      expect(SolverExclusions.words('en', 5), {
        'crane',
        'slate',
        'brick',
        'mount',
        'ghost',
        'plumb',
      });
    },
  );

  test('equations, places and the mastermind are not words', () {
    appState.progress['p|en|equations|5|5'] = {'a': 'eqeqe'};
    appState.progress['p|en|themed|5|6'] = {'a': 'paris'};
    appState.progress['p|en|mastermind|5|0'] = {'a': 'crane'};
    expect(SolverExclusions.words('en', 5), isEmpty);
  });

  test('an unfinished daily answer is excluded, in every word mode', () {
    final out = SolverExclusions.words('en', 5, bank: bank);
    for (final m in [GameMode.classic, GameMode.lockdown, GameMode.blind]) {
      expect(out, contains(answer(m)));
    }
    for (final w in DailyMulti.of(bank, GameMode.quartet, today)!.answers) {
      expect(out, contains(w));
    }
    for (final w in DailyMulti.of(bank, GameMode.relay, today)!.answers) {
      expect(out, contains(w));
    }
  });

  test('a finished daily is not excluded, an unfinished one still is', () {
    final classic = answer(GameMode.classic);
    final others = {
      answer(GameMode.lockdown),
      answer(GameMode.blind),
      ...DailyMulti.of(bank, GameMode.quartet, today)!.answers,
      ...DailyMulti.of(bank, GameMode.relay, today)!.answers,
    };
    appState.saveDaily('en', today, ['crane'], won: false);
    final out = SolverExclusions.words('en', 5, bank: bank);
    expect(out, others);
    // a daily half played (no result yet) is still hidden
    appState.saveDaily('en', today, ['crane']);
    expect(SolverExclusions.words('en', 5, bank: bank), {...others, classic});
    // another mode's finished daily is its own
    appState.saveDaily('en', today, ['crane'], won: true, mode: GameMode.blind);
    expect(
      SolverExclusions.words('en', 5, bank: bank),
      isNot(contains(answer(GameMode.blind))),
    );
  });

  test('another language or length is not excluded', () {
    expect(SolverExclusions.words('fr', 5, bank: bank), isEmpty);
    expect(SolverExclusions.words('en', 4, bank: bank), isEmpty);
  });

  test('the mastermind has no answer to hide', () {
    appState.progress['p|en|mastermind|5|0'] = {'a': ''};
    expect(SolverExclusions.words('en', 5), isEmpty);
    expect(Daily.of(bank, today, GameMode.mastermind)!.answer, isEmpty);
    expect(SolverExclusions.words('en', 5, bank: bank), isNot(contains('')));
  });

  test('equations: a saved game and an unfinished daily are excluded', () {
    final eqs = _bank({
      8: _equations,
      6: ['1+9=10'],
    }, anyChar: true);
    appState.progress['p|en|equations|6|5'] = {'a': '1+9=10'};
    appState.progress['p|fr|equations|8|5'] = {'a': '12+18=30'};
    expect(SolverExclusions.equations(6), {'1+9=10'});
    expect(SolverExclusions.equations(7), isEmpty);
    final daily = Daily.of(eqs, today, GameMode.equations)!.answer;
    expect(SolverExclusions.equations(8, bank: eqs), {'12+18=30', daily});
    appState.saveDaily('en', today, ['x'], won: true, mode: GameMode.equations);
    expect(SolverExclusions.equations(8, bank: eqs), {'12+18=30'});
  });

  test('places: a saved game and an unfinished daily are excluded', () {
    appState.progress['p|en|themed|5|6'] = {'a': 'paris'};
    expect(SolverExclusions.places(), {'paris'});
    final daily = answer(GameMode.themed);
    expect(SolverExclusions.places(bank: bank), {'paris', daily});
    appState.saveDaily('en', today, ['x'], won: false, mode: GameMode.themed);
    expect(SolverExclusions.places(bank: bank), {'paris'});
  });

  test('a failure returns what was found, and never throws', () {
    appState.progress = _Broken();
    expect(SolverExclusions.words('en', 5), isEmpty);
    expect(SolverExclusions.equations(8), isEmpty);
    expect(SolverExclusions.places(), isEmpty);
    // the dailies are still found when the saved games cannot be read
    expect(
      SolverExclusions.words('en', 5, bank: bank),
      contains(answer(GameMode.classic)),
    );
  });
}
