import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/lex.dart';
import 'package:lexodle/medal.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Achievement wins(int level) => achievementById('wins')!.atLevel(level);

GameResult game({List<HintKind> hints = const []}) => GameResult(
  lang: 'en',
  length: 5,
  tries: 6,
  used: 3,
  won: true,
  hints: hints,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('earning', () {
    test('medal values: 1, 2, 3, 5', () {
      expect([for (final m in Medal.values) medalValue(m)], [1, 2, 3, 5]);
    });

    test('only the highest level of an achievement in a game pays', () {
      final l = Lex();
      final paid = l.earn(
        [wins(0), wins(1), wins(2), wins(3)],
        lang: 'en',
        today: '2026-11-13',
        hinted: false,
      );
      expect(paid, 5);
      expect(l.balance, 5);
    });

    test('different achievements in one game each pay', () {
      final l = Lex();
      final q = achievementById('quick')!.atLevel(1);
      expect(
        l.earn([wins(0), q], lang: 'en', today: 'd', hinted: false),
        1 + 2,
      );
    });

    test('an achievement pays once a day per language, repeats in full', () {
      final l = Lex();
      int earn(String lang, String day, Achievement a) =>
          l.earn([a], lang: lang, today: day, hinted: false);
      expect(earn('en', '2026-11-13', wins(2)), 3);
      expect(earn('en', '2026-11-13', wins(3)), 0); // same day, same language
      expect(earn('fr', '2026-11-13', wins(2)), 3); // another language
      expect(earn('en', '2026-11-14', wins(2)), 3); // next day, full again
      expect(l.balance, 9);
    });

    test('a hinted game pays nothing and uses up no day', () {
      final l = Lex();
      expect(l.earn([wins(3)], lang: 'en', today: 'd', hinted: true), 0);
      expect(l.balance, 0);
      expect(l.earn([wins(3)], lang: 'en', today: 'd', hinted: false), 5);
    });

    test(
      'recordGame pays, and a hinted game pays 0 but still counts',
      () async {
        final s = AppState();
        await s.load();
        s.recordGame(game(hints: [HintKind.grey]));
        expect(s.lastLex, 0);
        expect(s.lexBalance, 0);
        expect(s.stats.played, 1);
        expect(s.stats.wins, 1);
        s.recordGame(game());
        expect(s.lastLex, greaterThan(0));
        expect(s.lexBalance, s.lastLex);
      },
    );
  });

  group('hints', () {
    test('prices are 10, 25 and 50', () {
      expect([for (final k in HintKind.values) k.price], [10, 25, 50]);
    });

    test('spending, refusal when short, and undo before the next guess', () {
      final l = Lex()..balance = 30;
      final g = GameHints();
      expect(l.spend(g, HintKind.green, guesses: 0), isNull); // 50 > 30
      expect(l.balance, 30);
      expect(g.hinted, isFalse);
      expect(l.spend(g, HintKind.yellow, guesses: 2), isNotNull);
      expect(l.balance, 5);
      expect(g.hinted, isTrue);
      expect(g.kinds, [HintKind.yellow]);
      expect(l.refund(g, guesses: 3), isFalse); // a guess was made since
      expect(l.balance, 5);
      expect(l.refund(g, guesses: 2), isTrue);
      expect(l.balance, 30);
      expect(g.hinted, isFalse);
      expect(l.refund(g, guesses: 2), isFalse); // nothing left to undo
    });

    test('a free hint costs no lex, and is given back by an undo', () {
      final l = Lex();
      expect(l.freeHints, 1);
      final g = GameHints();
      expect(l.spend(g, HintKind.green, guesses: 0, free: true), isNotNull);
      expect(l.freeHints, 0);
      expect(l.balance, 0);
      expect(g.hinted, isTrue); // the game still pays 0 lex
      expect(l.spend(g, HintKind.grey, guesses: 0, free: true), isNull);
      expect(l.refund(g, guesses: 0), isTrue);
      expect(l.freeHints, 1);
      expect(g.hinted, isFalse);
    });

    test('the state buys, saves and restores a hint', () async {
      final s = AppState();
      await s.load();
      s.lex.balance = 40;
      final g = GameHints();
      expect(s.buyHint(g, HintKind.yellow, guesses: 1), isNotNull);
      final again = AppState();
      await again.load();
      expect(again.lexBalance, 15);
      expect(s.undoHint(g, guesses: 1), isTrue);
      expect(s.lexBalance, 40);
    });
  });

  group('veterans', () {
    test('the grant is the medal values of every level held', () {
      final held = {
        'wins': AchState(times: 3), // 1 + 2 + 3
        'quick': AchState(times: 4), // 1 + 2 + 3 + 5
        'played': AchState(), // none held
        'gone': AchState(times: 2), // not an achievement any more
      };
      final other = {'wins': AchState(times: 1)}; // another language: 1
      expect(veteranGrant([held, other]), 6 + 11 + 1);
      expect(veteranGrant(const []), 0);
    });

    test('it is given once at activation, never twice', () {
      final l = Lex();
      expect(l.activate(12, veteran: true), isTrue);
      expect(l.activate(99, veteran: true), isFalse);
      expect(l.balance, 12);
      expect(l.veteran, isTrue);
    });

    test('a veteran player gets it at the first load', () async {
      SharedPreferences.setMockInitialValues({
        'stats': jsonEncode(
          Stats()
            ..played = 40
            ..toJson(),
        ),
        'achievementsVersion': AppState.achievementsVersion,
        'achievementsBy': jsonEncode({}),
      });
      final s = AppState();
      await s.load();
      expect(s.lex.activated, isTrue);
      expect(s.lexUnlocked, isTrue);
    });
  });

  group('unlock', () {
    test('a new player sees lex once the first game has taught it', () async {
      final s = AppState();
      await s.load();
      expect(s.lexUnlocked, isFalse);
      s.stats.played = 1;
      expect(s.lexUnlocked, isTrue);
    });
  });

  group('backup', () {
    test('it round trips the balance, free hints and ledger', () async {
      final a = AppState();
      await a.load();
      a.lex
        ..balance = 77
        ..freeHints = 0;
      a.buyHint(GameHints(), HintKind.grey, guesses: 0);
      a.recordGame(game());
      final p = parseBackup(backupToText(a));
      expect(p.lex, isNotNull);
      final b = AppState();
      await b.load();
      b.restore(
        settings: p.settings,
        stats: p.stats,
        ach: p.achievements,
        languages: p.languages,
        history: p.history,
        learn: p.learn,
        words: p.words,
        collected: p.collected,
        lex: p.lex,
      );
      expect(b.lexBalance, a.lexBalance);
      expect(b.freeHints, 0);
      expect(b.lex.ledger.length, a.lex.ledger.length);
      expect(b.lex.ledger.last.why, a.lex.ledger.last.why);
    });

    test('from before lex it gets the veteran grant once, from its levels', () {
      final a = AppState();
      a.ach['wins'] = AchState(times: 2); // 1 + 2
      final map = jsonDecode(backupToText(a)) as Map<String, dynamic>
        ..remove('lex');
      final p = parseBackup(jsonEncode(map));
      expect(p.lex, isNull);
      final b = AppState();
      b.restore(
        settings: p.settings,
        stats: p.stats,
        ach: p.achievements,
        languages: p.languages,
        history: p.history,
        learn: p.learn,
        words: p.words,
        collected: p.collected,
        lex: p.lex,
      );
      expect(b.lexBalance, 3);
      expect(b.lex.activated, isTrue);
    });
  });
}
