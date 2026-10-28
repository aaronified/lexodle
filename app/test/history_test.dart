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
      risk: 30,
      gain: .4,
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
      expect(g.risk, 30);
      expect(g.gain, .4);
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
      expect(back.guesses.single.risk, isNull);
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

    test('the rows are lists, in a fixed order, and are small', () {
      final h = History();
      final g = addGame(h, daily: '2026-10-24', at: 5);
      final j = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      final game = (j['games'] as List).single as List;
      expect(game, [
        g.id,
        5,
        'en',
        0,
        5,
        6,
        3000,
        ['slate'],
        1,
        '2026-10-24',
        metricsVersion,
        1, // drawn by frequency
      ]);
      final guess = (j['guesses'] as List).first as List;
      expect(guess, [g.id, 0, 'crane', 70, 5, 30, 100, 90, .4, null, 0, 0, 0]);
      // a guess without a daring has a null in its place
      h.add(
        at: 6,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['slate'],
        won: true,
        guesses: [const GuessRow(game: 0, n: 0, word: 'slate', skill: 100)],
      );
      final k = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      expect(((k['guesses'] as List).last as List)[5], isNull);
      // and there is no field name in them: about a third of the named form
      final named = jsonEncode({
        'games': [for (final x in h.games) x.toJson()],
        'guesses': [for (final r in h.guesses) r.toJson()],
      });
      expect(jsonEncode(h.toJson()).length, lessThan(named.length * 0.7));
    });

    test(
      'a row from before the frequency flag is read as drawn by frequency',
      () {
        final h = History();
        addGame(h, at: 5);
        final j = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
        ((j['games'] as List).first as List).removeLast();
        expect(History.fromJson(j).games.single.freq, isTrue);
      },
    );

    test('the earlier form, with named fields, is still read', () {
      final h = History();
      addGame(h, daily: '2026-10-24', at: 5);
      addGame(h, won: false, at: 6);
      final named = jsonDecode(
        jsonEncode({
          'games': [for (final g in h.games) g.toJson()],
          'guesses': [for (final r in h.guesses) r.toJson()],
        }),
      );
      final back = History.fromJson(named);
      expect(back.games.length, 2);
      expect(back.games.first.daily, '2026-10-24');
      expect(back.games.last.won, isFalse);
      expect(back.guesses.length, h.guesses.length);
      expect(back.guesses.first.risk, 30);
    });

    test('a bad row of the compact form is refused', () {
      Map<String, dynamic> good() {
        final h = History();
        addGame(h);
        return jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      }

      void refuses(Map<String, dynamic> j, String why) =>
          expect(() => History.fromJson(j), throwsFormatException, reason: why);

      List game(Map<String, dynamic> j) => (j['games'] as List).first as List;
      List guess(Map<String, dynamic> j) =>
          (j['guesses'] as List).first as List;

      var j = good();
      game(j).removeRange(game(j).length - 2, game(j).length);
      refuses(j, 'a game row that is too short');
      j = good();
      game(j)[7] = ['abc'];
      refuses(j, 'an answer of the wrong length');
      j = good();
      game(j)[3] = 9;
      refuses(j, 'a mode that is not one');
      j = good();
      game(j)[8] = 2;
      refuses(j, 'won that is neither 0 nor 1');
      j = good();
      game(j)[1] = -1;
      refuses(j, 'a time before the epoch');
      j = good();
      guess(j).add(1);
      refuses(j, 'a guess row that is too long');
      j = good();
      guess(j)[3] = 500;
      refuses(j, 'a skill out of range');
      j = good();
      guess(j)[2] = 5;
      refuses(j, 'a word that is not text');
      j = good();
      (j['games'] as List)[0] = 'not a row';
      refuses(j, 'a game that is not a row');
    });

    test('anything that is not a history is refused, whole', () {
      // the named form, the one an earlier version wrote
      Map<String, Object?> good() {
        final h = History();
        addGame(h);
        return jsonDecode(
          jsonEncode({
            'games': [for (final g in h.games) g.toJson()],
            'guesses': [for (final r in h.guesses) r.toJson()],
          }),
        ) as Map<String, Object?>;
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
                risk: 45.678,
                gain: 1.234,
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

  group('kept a month at a time', () {
    /// A game ending at [at] (UTC).
    void record(AppState s, DateTime at, {bool won = true}) => s.recordHistory(
      lang: 'en',
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: ['slate'],
      won: won,
      guesses: rows(['crane', 'slate']),
      now: at,
    );

    test('a game belongs to the month it ended in', () {
      final h = History();
      final a = addGame(
        h,
        at: DateTime.utc(2026, 8, 31, 23, 59).millisecondsSinceEpoch,
      );
      final b = addGame(h, at: DateTime.utc(2026, 9, 1).millisecondsSinceEpoch);
      expect(a.month, '2026-08');
      expect(b.month, '2026-09');
      expect(
        monthOf(DateTime.utc(2027, 1, 1).millisecondsSinceEpoch),
        '2027-01',
      );
      expect(h.months(), ['2026-08', '2026-09']);
    });

    test('a chunk holds one month: its games and only their guesses', () {
      final h = History();
      final a = addGame(h, at: DateTime.utc(2026, 8, 5).millisecondsSinceEpoch);
      final b = addGame(h, at: DateTime.utc(2026, 9, 5).millisecondsSinceEpoch);
      final aug = h.chunk('2026-08');
      expect((aug['games'] as List).length, 1);
      expect((aug['games'] as List).single[0], a.id);
      expect((aug['guesses'] as List).length, 2);
      expect(((aug['guesses'] as List).first as List)[0], a.id);
      expect(((h.chunk('2026-09')['guesses'] as List).first as List)[0], b.id);
      expect((h.chunk('1999-01')['games'] as List), isEmpty);
      // chunks put back together are the history
      final back = History.fromChunks([aug, h.chunk('2026-09')]);
      expect(back.games.map((g) => g.id), [a.id, b.id]);
      expect(back.guesses.length, 4);
    });

    test('only the months that changed are marked, until they are saved', () {
      final h = History();
      expect(h.dirtyMonths, isEmpty);
      final a = addGame(h, at: DateTime.utc(2026, 8, 5).millisecondsSinceEpoch);
      addGame(h, at: DateTime.utc(2026, 9, 5).millisecondsSinceEpoch);
      expect(h.dirtyMonths, {'2026-08', '2026-09'});
      h.dirtyMonths.clear();
      addGame(h, at: DateTime.utc(2026, 9, 6).millisecondsSinceEpoch);
      expect(h.dirtyMonths, {'2026-09'}, reason: 'August did not change');
      h.dirtyMonths.clear();
      h.replaceGuesses(a.id, rows(['crane', 'slate'], skill: 90));
      expect(h.dirtyMonths, {'2026-08'}, reason: 'its numbers were replaced');
      h.dirtyMonths.clear();
      h.markAllDirty();
      expect(h.dirtyMonths, {'2026-08', '2026-09'});
    });

    test('a month is written for each, with an index, and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      record(s, DateTime.utc(2026, 8, 5));
      record(s, DateTime.utc(2026, 8, 20));
      record(s, DateTime.utc(2026, 9, 5), won: false);
      record(s, DateTime.utc(2026, 10, 24));
      final p = await SharedPreferences.getInstance();
      expect(p.getStringList(AppState.historyIndexKey), [
        '2026-08',
        '2026-09',
        '2026-10',
      ]);
      for (final m in ['2026-08', '2026-09', '2026-10']) {
        expect(p.getString(AppState.historyChunkKey(m)), isNotNull, reason: m);
      }
      expect(
        p.getString('history'),
        isNull,
        reason: 'no single string any more',
      );
      expect(s.history.dirtyMonths, isEmpty);

      final again = AppState();
      await again.load();
      expect(
        again.history.games.map((g) => g.at),
        s.history.games.map((g) => g.at),
      );
      expect(again.history.games.map((g) => g.won), [true, true, false, true]);
      expect(again.history.guesses.length, 8);
    });

    test('finishing a game rewrites only its month', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      record(s, DateTime.utc(2026, 8, 5));
      record(s, DateTime.utc(2026, 9, 5));
      // mark August's chunk, to see whether it is touched
      final p = await SharedPreferences.getInstance();
      await p.setString(AppState.historyChunkKey('2026-08'), 'UNTOUCHED');
      final september = p.getString(AppState.historyChunkKey('2026-09'));
      record(s, DateTime.utc(2026, 10, 24));
      expect(p.getString(AppState.historyChunkKey('2026-08')), 'UNTOUCHED');
      expect(p.getString(AppState.historyChunkKey('2026-09')), september);
      expect(p.getString(AppState.historyChunkKey('2026-10')), isNotNull);
      expect(p.getStringList(AppState.historyIndexKey)!.length, 3);
      // a second game in the same month rewrites that month, and only it
      record(s, DateTime.utc(2026, 10, 25));
      expect(p.getString(AppState.historyChunkKey('2026-08')), 'UNTOUCHED');
      final october = jsonDecode(
        p.getString(AppState.historyChunkKey('2026-10'))!,
      );
      expect((october['games'] as List).length, 2);
    });

    test(
      'the history of an earlier version, in one string, moves into months',
      () async {
        final h = History();
        addGame(h, at: DateTime.utc(2026, 8, 5).millisecondsSinceEpoch);
        addGame(h, at: DateTime.utc(2026, 10, 5).millisecondsSinceEpoch);
        // once as the named rows of the first version
        final named = jsonEncode({
          'games': [for (final g in h.games) g.toJson()],
          'guesses': [for (final r in h.guesses) r.toJson()],
        });
        for (final old in [named, jsonEncode(h.toJson())]) {
          SharedPreferences.setMockInitialValues({'history': old});
          final s = AppState();
          await s.load();
          expect(s.history.games.length, 2);
          final p = await SharedPreferences.getInstance();
          expect(p.getString('history'), isNull, reason: 'the old key is gone');
          expect(p.getStringList(AppState.historyIndexKey), [
            '2026-08',
            '2026-10',
          ]);
          expect(p.getString(AppState.historyChunkKey('2026-08')), isNotNull);
          final again = AppState();
          await again.load();
          expect(again.history.games.length, 2);
        }
      },
    );

    test('a damaged month is left out and the others are kept', () async {
      final h = History();
      addGame(h, at: DateTime.utc(2026, 8, 5).millisecondsSinceEpoch);
      addGame(h, at: DateTime.utc(2026, 10, 5).millisecondsSinceEpoch);
      SharedPreferences.setMockInitialValues({
        AppState.historyIndexKey: ['2026-08', '2026-09', '2026-10', '2026-11'],
        AppState.historyChunkKey('2026-08'): jsonEncode(h.chunk('2026-08')),
        AppState.historyChunkKey('2026-09'):
            '{"games": [[1,2,3]], "guesses": []}',
        AppState.historyChunkKey('2026-10'): jsonEncode(h.chunk('2026-10')),
        // 2026-11 is in the index but has no chunk
        'lang': 'fr',
      });
      final s = AppState();
      await s.load();
      expect(s.lang, 'fr', reason: 'the rest of the settings still load');
      expect(s.history.games.length, 2);
      expect(s.history.months(), ['2026-08', '2026-10']);
    });

    test(
      'a restored backup replaces the months, and removes the old ones',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = AppState();
        await s.load();
        record(s, DateTime.utc(2026, 8, 5));
        record(s, DateTime.utc(2026, 9, 5));
        final p = await SharedPreferences.getInstance();
        expect(p.getString(AppState.historyChunkKey('2026-08')), isNotNull);

        final other = History();
        addGame(other, at: DateTime.utc(2026, 10, 5).millisecondsSinceEpoch);
        s.restore(
          settings: const {},
          stats: Stats(),
          ach: const {},
          history: other,
        );
        expect(p.getString(AppState.historyChunkKey('2026-08')), isNull);
        expect(p.getString(AppState.historyChunkKey('2026-09')), isNull);
        expect(p.getString(AppState.historyChunkKey('2026-10')), isNotNull);
        expect(p.getStringList(AppState.historyIndexKey), ['2026-10']);
        final again = AppState();
        await again.load();
        expect(again.history.months(), ['2026-10']);
      },
    );

    test('thousands of games are kept, saved and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      final started = Stopwatch()..start();
      // 3,000 games over 25 months
      for (var i = 0; i < 3000; i++) {
        s.history.add(
          at: DateTime.utc(
            2024,
            9,
            1,
          ).add(Duration(hours: i * 6)).millisecondsSinceEpoch,
          lang: 'en',
          mode: GameMode.classic,
          length: 5,
          tries: 6,
          pool: 3000,
          answers: ['slate'],
          won: i % 4 != 0,
          guesses: rows(['crane', 'slate', 'slate']),
        );
      }
      expect(s.history.games.length, 3000);
      s.saveHistory();
      final p = await SharedPreferences.getInstance();
      final months = p.getStringList(AppState.historyIndexKey)!;
      expect(months.length, greaterThan(20));
      // each month is a chunk of its own, none of them huge
      for (final m in months) {
        expect(
          p.getString(AppState.historyChunkKey(m))!.length,
          lessThan(150000),
        );
      }
      final again = AppState();
      await again.load();
      expect(again.history.games.length, 3000);
      expect(again.history.guesses.length, 9000);
      expect(again.history.recentClassic().length, 100);
      expect(started.elapsed, lessThan(const Duration(seconds: 20)));
    });

    test('beyond the cap the oldest go, with their guesses and months', () {
      final h = History();
      final first = addGame(
        h,
        at: DateTime.utc(2020, 1, 1).millisecondsSinceEpoch,
      );
      for (var i = 1; i < historyCap + 5; i++) {
        h.add(
          at: DateTime.utc(
            2021,
            1,
            1,
          ).add(Duration(minutes: i)).millisecondsSinceEpoch,
          lang: 'en',
          mode: GameMode.classic,
          length: 5,
          tries: 6,
          pool: 3000,
          answers: ['slate'],
          won: true,
          guesses: rows(['slate']),
        );
      }
      expect(h.games.length, historyCap);
      expect(h.byId(first.id), isNull);
      expect(h.guessesOf(first.id), isEmpty);
      expect(h.months(), isNot(contains('2020-01')));
      expect(h.dirtyMonths, contains('2020-01'), reason: 'its chunk must go');
      expect(h.guesses.length, historyCap);
    });

    test('a month that has lost all its games is removed, not left empty', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      // fill the cap with one month, then add a game: the oldest month is gone
      s.history.add(
        at: DateTime.utc(2020, 1, 1).millisecondsSinceEpoch,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['slate'],
        won: true,
        guesses: rows(['slate']),
      );
      s.saveHistory();
      final p = await SharedPreferences.getInstance();
      expect(p.getString(AppState.historyChunkKey('2020-01')), isNotNull);
      for (var i = 0; i < historyCap; i++) {
        s.history.add(
          at: DateTime.utc(
            2021,
            1,
            1,
          ).add(Duration(minutes: i)).millisecondsSinceEpoch,
          lang: 'en',
          mode: GameMode.classic,
          length: 5,
          tries: 6,
          pool: 3000,
          answers: ['slate'],
          won: true,
          guesses: rows(['slate']),
        );
      }
      s.saveHistory();
      expect(p.getString(AppState.historyChunkKey('2020-01')), isNull);
      expect(p.getStringList(AppState.historyIndexKey), ['2021-01']);
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
      appState.setup(lang: 'fr', length: 4, tries: 3);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final answer = chooseWord(
        bank.answers(4),
        bank.answerWeights(4),
        Random(7),
      );
      final guesses = bank
          .answers(4)
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
      expect(g.pool, bank.answers(4).length);
      expect(g.answers, [answer]);
      expect(g.won, isFalse);
      expect(g.isDaily, isFalse);
      final rowsOf = h.guessesOf(g.id);
      expect(rowsOf.map((r) => r.word), guesses);
      expect(rowsOf.map((r) => r.n), [0, 1, 2]);
      // the scores are cached, and so is the choice the player had
      expect(rowsOf.every((r) => r.skill >= 0 && r.skill <= 100), isTrue);
      expect(rowsOf.first.before, bank.guessable(4).length);
      expect(rowsOf.first.risk, isNotNull, reason: 'the analysis had landed');
    });
  });
}
