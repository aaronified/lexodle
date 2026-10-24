import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/background.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<GuessRow> rows(List<String> words, {double skill = 70}) => [
  for (var i = 0; i < words.length; i++)
    GuessRow(
      game: 0,
      n: i,
      word: words[i],
      skill: skill,
      luck: 5,
      daring: 30,
      risk: .4,
      before: 100 - i * 10,
      after: 90 - i * 10,
    ),
];

GameRow addGame(
  History h, {
  bool won = true,
  GameMode mode = GameMode.classic,
  List<String> guesses = const ['crane', 'slate'],
  String daily = '',
  int at = 1000,
}) => h.add(
  at: at,
  lang: 'en',
  mode: mode,
  length: 5,
  tries: 6,
  pool: 3000,
  answers: mode.multi ? ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'] : ['slate'],
  won: won,
  guesses: rows(guesses),
  daily: daily,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the tables', () {
    test('a game and its guesses are two tables, joined by the game id', () {
      final h = History();
      final a = addGame(h, guesses: ['crane', 'slate']);
      final b = addGame(h, guesses: ['adieu', 'stone', 'slate']);
      expect(a.id, isNot(b.id));
      expect(h.games, [a, b]);
      expect(h.guessesOf(a.id).map((g) => g.word), ['crane', 'slate']);
      expect(h.guessesOf(b.id).map((g) => g.word), ['adieu', 'stone', 'slate']);
      expect(h.guesses.length, 5);
      expect(h.guesses.every((g) => g.game == a.id || g.game == b.id), isTrue);
      expect(h.guessesOf(999), isEmpty);
      expect(h.byId(b.id), b);
      expect(h.byId(999), isNull);
    });

    test('the guesses keep every fact needed to score the game again', () {
      final h = History();
      final g = addGame(h, daily: '2026-10-24');
      expect(g.answers, ['slate']);
      expect(g.lang, 'en');
      expect(g.length, 5);
      expect(g.tries, 6);
      expect(g.pool, 3000);
      expect(g.won, isTrue);
      expect(g.isDaily, isTrue);
      expect(g.daily, '2026-10-24');
      expect(g.at, 1000);
      expect(g.version, metricsVersion);
    });

    test('ids are never reused, even after old games are dropped', () {
      final h = History();
      final ids = <int>[];
      for (var i = 0; i < historyCap + 5; i++) {
        ids.add(addGame(h, at: i).id);
      }
      expect(ids.toSet().length, ids.length);
      expect(ids, orderedEquals([...ids]..sort()));
    });

    test('only the last games are kept, with their guesses', () {
      final h = History();
      final first = addGame(h, at: 0);
      for (var i = 1; i < historyCap + 10; i++) {
        addGame(h, at: i);
      }
      expect(h.games.length, historyCap);
      expect(h.byId(first.id), isNull);
      expect(h.guessesOf(first.id), isEmpty);
      expect(h.games.first.at, 10);
      // no guess row is left pointing at a dropped game
      final ids = {for (final g in h.games) g.id};
      expect(h.guesses.every((g) => ids.contains(g.game)), isTrue);
    });

    test('the recent classic games are the ones a playstyle is read from', () {
      final h = History();
      for (var i = 0; i < 130; i++) {
        addGame(h, at: i);
        if (i % 10 == 0) addGame(h, mode: GameMode.quartet, at: i);
      }
      final recent = h.recentClassic();
      expect(recent.length, 100);
      expect(recent.every((g) => g.isClassic), isTrue);
      expect(recent.last.at, 129, reason: 'newest last');
      expect(recent.first.at, 30);
      expect(h.recentClassic(5).length, 5);
      expect(History().recentClassic(), isEmpty);
    });

    test('a daily is a classic game, so it counts', () {
      final h = History();
      addGame(h, daily: '2026-10-24');
      expect(h.recentClassic().length, 1);
    });
  });

  group('when the maths changes', () {
    test('games saved under an older version are stale', () {
      final h = History();
      final a = addGame(h);
      addGame(h);
      expect(h.stale(), isEmpty);
      h.games[0] = a.withVersion(metricsVersion - 1);
      expect(h.stale().map((g) => g.id), [a.id]);
    });

    test(
      'working a game out again replaces its numbers and clears the stamp',
      () {
        final h = History();
        final a = addGame(h, guesses: ['crane', 'slate']);
        h.games[0] = a.withVersion(0);
        h.replaceGuesses(a.id, rows(['crane', 'slate'], skill: 95));
        expect(h.guessesOf(a.id).map((g) => g.skill), [95, 95]);
        expect(h.guessesOf(a.id).map((g) => g.game), [a.id, a.id]);
        expect(h.stale(), isEmpty);
        expect(
          h.guesses.length,
          2,
          reason: 'the old rows are gone, not added to',
        );
        // the facts of the game are untouched
        expect(h.byId(a.id)!.answers, ['slate']);
      },
    );

    test('replacing the guesses of a game that is gone does nothing', () {
      final h = History();
      addGame(h);
      h.replaceGuesses(999, rows(['crane']));
      expect(h.guesses.length, 2);
    });
  });

  group('saving and reading', () {
    test('what is written is read back', () {
      final h = History();
      addGame(h, daily: '2026-10-24', at: 5);
      addGame(h, mode: GameMode.relay, won: false, at: 6);
      final back = History.fromJson(jsonDecode(jsonEncode(h.toJson())));
      expect(back.games.length, 2);
      expect(back.games[0].daily, '2026-10-24');
      expect(back.games[1].mode, GameMode.relay);
      expect(back.games[1].won, isFalse);
      expect(back.games[1].answers.length, 4);
      expect(back.guesses.length, h.guesses.length);
      final g = back.guessesOf(back.games[0].id).first;
      expect(g.word, 'crane');
      expect(g.skill, 70);
      expect(g.daring, 30);
      expect(g.risk, .4);
      // and new games carry on from the highest id
      final next = addGame(back);
      expect(next.id, greaterThan(back.games[1].id));
    });

    test('a guess without a daring stays without one', () {
      final h = History();
      h.add(
        at: 1,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['slate'],
        won: true,
        guesses: [const GuessRow(game: 0, n: 0, word: 'slate', skill: 100)],
      );
      final back = History.fromJson(jsonDecode(jsonEncode(h.toJson())));
      expect(back.guesses.single.daring, isNull);
    });

    test('scores are kept to three decimals', () {
      final h = History();
      h.add(
        at: 1,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['slate'],
        won: true,
        guesses: [
          const GuessRow(game: 0, n: 0, word: 'slate', skill: 87.123456),
        ],
      );
      final back = History.fromJson(jsonDecode(jsonEncode(h.toJson())));
      expect(back.guesses.single.skill, 87.123);
    });

    test('anything that is not a history is refused, whole', () {
      Map<String, Object?> good() {
        final h = History();
        addGame(h);
        return jsonDecode(jsonEncode(h.toJson())) as Map<String, Object?>;
      }

      void refuses(Object? raw, String why) => expect(
        () => History.fromJson(raw),
        throwsFormatException,
        reason: why,
      );

      refuses(null, 'null');
      refuses('text', 'a string');
      refuses({'games': 1, 'guesses': []}, 'games not a list');
      refuses({'games': [], 'guesses': 'x'}, 'guesses not a list');

      var j = good();
      ((j['games'] as List)[0] as Map)['answers'] = ['abc'];
      refuses(j, 'an answer of the wrong length');

      j = good();
      ((j['games'] as List)[0] as Map)['mode'] = 9;
      refuses(j, 'a mode that is not one');

      j = good();
      ((j['games'] as List)[0] as Map)['won'] = 'yes';
      refuses(j, 'won is not a bool');

      j = good();
      ((j['games'] as List)[0] as Map)['answers'] = [];
      refuses(j, 'no answer');

      j = good();
      ((j['guesses'] as List)[0] as Map)['s'] = 500;
      refuses(j, 'a skill out of range');

      j = good();
      ((j['guesses'] as List)[0] as Map)['w'] = 5;
      refuses(j, 'a word that is not text');

      j = good();
      (j['games'] as List).add((j['games'] as List)[0]);
      refuses(j, 'the same game twice');

      j = good();
      j['guesses'] = [];
      refuses(j, 'a game with no guesses');

      j = good();
      j['games'] = List.filled(historyCap + 1, (j['games'] as List)[0]);
      refuses(j, 'too many games');
    });

    test('a guess whose game is not there is dropped, not an error', () {
      final h = History();
      addGame(h);
      final j = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      (j['guesses'] as List).add({
        'g': 777,
        'n': 0,
        'w': 'orphan',
        's': 1,
        'l': 0,
        'r': 0,
        'b': 0,
        'a': 0,
      });
      final back = History.fromJson(j);
      expect(back.guesses.length, 2);
      expect(back.guesses.any((g) => g.word == 'orphan'), isFalse);
    });
  });

  group('kept by the app', () {
    test('a recorded game is saved, and comes back after a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.recordHistory(
        lang: 'fr',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['crane'],
        won: true,
        guesses: rows(['adieu', 'crane']),
        daily: '2026-10-24',
        now: DateTime.utc(2026, 10, 24, 12),
      );
      expect(
        s.history.games.single.at,
        DateTime.utc(2026, 10, 24, 12).millisecondsSinceEpoch,
      );

      final again = AppState();
      await again.load();
      expect(again.history.games.length, 1);
      expect(again.history.games.single.daily, '2026-10-24');
      expect(again.history.guessesOf(again.history.games.single.id).length, 2);
    });

    test(
      'a damaged history is ignored and does not stop the rest loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'history': '{"games": [{"id": "x"}], "guesses": []}',
          'lang': 'fr',
          'stats': jsonEncode(Stats().toJson()),
        });
        final s = AppState();
        await s.load();
        expect(s.lang, 'fr');
        expect(s.history.games, isEmpty);
      },
    );

    test('the backup holds the history and a restore brings it back', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.recordHistory(
        lang: 'fr',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['crane'],
        won: true,
        guesses: rows(['adieu', 'crane']),
      );
      final text = backupToText(s);
      // history rides in one compact line, not indented over hundreds of lines
      expect(text.split('\n').where((l) => l.contains('"history"')).length, 1);
      expect(text.split('\n').length, lessThan(200));
      final backup = parseBackup(text);
      expect(backup.history!.games.length, 1);

      final other = AppState();
      await other.load();
      other.restore(
        settings: backup.settings,
        stats: backup.stats,
        ach: backup.achievements,
        history: backup.history,
      );
      expect(other.history.games.single.answers, ['crane']);
    });

    test('a backup from before the history leaves the history alone', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.recordHistory(
        lang: 'fr',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['crane'],
        won: true,
        guesses: rows(['crane']),
      );
      final j = jsonDecode(backupToText(s)) as Map<String, dynamic>
        ..remove('history');
      final old = parseBackup(jsonEncode(j));
      expect(old.history, isNull);
      s.restore(
        settings: old.settings,
        stats: old.stats,
        ach: old.achievements,
        history: old.history,
      );
      expect(s.history.games.length, 1);
    });

    test('a backup with a bad history is refused', () {
      final s = AppState();
      final j = jsonDecode(backupToText(s)) as Map<String, dynamic>;
      j['history'] = '{"games": 5}';
      expect(() => parseBackup(jsonEncode(j)), throwsFormatException);
      j['history'] = 'not json at all';
      expect(() => parseBackup(jsonEncode(j)), throwsFormatException);
    });

    test('the most history that can be kept still fits a backup', () {
      final s = AppState();
      for (var i = 0; i < historyCap; i++) {
        s.history.add(
          at: i,
          lang: 'en-GB',
          mode: GameMode.classic,
          length: 8,
          tries: 8,
          pool: 6000,
          answers: ['abcdefgh'],
          won: true,
          guesses: [
            for (var n = 0; n < 8; n++)
              GuessRow(
                game: 0,
                n: n,
                word: 'abcdefgh',
                skill: 87.123,
                luck: -12.345,
                daring: 45.678,
                risk: 1.234,
                before: 6000,
                after: 3000,
              ),
          ],
        );
      }
      expect(backupToText(s).length, lessThan(maxBackupBytes));
      expect(parseBackup(backupToText(s)).history!.games.length, historyCap);
    });
  });

  group('playing records a game', () {
    testWidgets('a lost game is saved with its guesses and the answer', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      // the analysis (and so the daring) is worked out while the game is played
      analyseWhilePlaying = true;
      addTearDown(() => analyseWhilePlaying = false);
      await appState.load();
      appState.history = History();
      appState.setup(lang: 'fr', length: 4, tries: 3, pool: 500);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final answer = chooseWord(
        bank.answers(4, 500),
        bank.answerWeights(4, 500),
        Random(7),
      );
      final guesses = bank
          .answers(4, 500)
          .where((w) => w != answer)
          .take(3)
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, random: Random(7)),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      for (final w in guesses) {
        for (final ch in w.split('')) {
          await tester.sendKeyEvent(
            LogicalKeyboardKey(ch.codeUnitAt(0)),
            character: ch,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final h = appState.history;
      expect(h.games.length, 1);
      final g = h.games.single;
      expect(g.lang, 'fr');
      expect(g.mode, GameMode.classic);
      expect(g.length, 4);
      expect(g.tries, 3);
      expect(g.pool, 500);
      expect(g.answers, [answer]);
      expect(g.won, isFalse);
      expect(g.isDaily, isFalse);
      final rowsOf = h.guessesOf(g.id);
      expect(rowsOf.map((r) => r.word), guesses);
      expect(rowsOf.map((r) => r.n), [0, 1, 2]);
      // the scores are cached, and so is the choice the player had
      expect(rowsOf.every((r) => r.skill >= 0 && r.skill <= 100), isTrue);
      expect(rowsOf.first.before, bank.guessable(4).length);
      expect(rowsOf.first.daring, isNotNull, reason: 'the analysis had landed');
    });
  });
}
