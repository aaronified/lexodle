import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app saved at an earlier release must still be there after the
/// update: the fixtures are the preferences an earlier release wrote.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> loadFixture(String name) async {
    final raw = jsonDecode(File('test/fixtures/$name').readAsStringSync());
    SharedPreferences.setMockInitialValues({
      for (final e in (raw as Map).entries) e.key as String: e.value as Object,
    });
    final s = AppState();
    await s.load();
    return s;
  }

  test('what release 0.1.4 saved is read by this one', () async {
    final s = await loadFixture('prefs_v0_1_4.json');
    expect(s.stats.played, 6);
    expect(s.stats.wins, 5);
    expect(s.history.games, hasLength(6));
    expect(s.seenHowTo, isTrue);
  });

  test('reading it back and saving again loses nothing', () async {
    final s = await loadFixture('prefs_v0_1_4.json');
    s.recordHistory(
      lang: 'en',
      mode: s.mode,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: const ['crane'],
      won: true,
      guesses: [GuessRow(game: 0, n: 0, word: 'crane', skill: 90, luck: 0)],
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final again = AppState();
    await again.load();
    expect(again.history.games, hasLength(7));
    expect(again.stats.played, 6);
  });

  group('what cannot be read is not lost with what can', () {
    Map<String, Object> fixture() => {
      for (final e in (jsonDecode(
        File('test/fixtures/prefs_v0_1_4.json').readAsStringSync(),
      ) as Map).entries)
        e.key as String: e.value as Object,
    };

    test('one bad row costs that row, not the month', () async {
      final prefs = fixture();
      final chunk = jsonDecode(prefs['history:2026-10'] as String) as Map;
      (chunk['games'] as List).add([99, 1, 'en', 0, 5, 6, 3000, [], 1, '', 4]);
      final raw = jsonEncode(chunk);
      prefs['history:2026-10'] = raw;
      SharedPreferences.setMockInitialValues(prefs);
      final s = AppState();
      await s.load();
      expect(s.history.games, hasLength(6), reason: 'the readable rows stay');
      final p = await SharedPreferences.getInstance();
      expect(
        p.getString('history:2026-10:unread'),
        raw,
        reason: 'a copy is kept',
      );
    });

    test(
      'a month that is not even JSON is kept aside, the others are read',
      () async {
        final prefs = fixture();
        prefs['history:months'] = ['2026-09', '2026-10'];
        prefs['history:2026-09'] = '{not json';
        SharedPreferences.setMockInitialValues(prefs);
        final s = AppState();
        await s.load();
        expect(s.history.games, hasLength(6));
        final p = await SharedPreferences.getInstance();
        expect(p.getString('history:2026-09:unread'), '{not json');
      },
    );

    test(
      'damaged stats do not stop the history, daily log or settings',
      () async {
        final prefs = fixture();
        prefs['stats'] = '[1,2,3]';
        prefs['haptics'] = false;
        SharedPreferences.setMockInitialValues(prefs);
        final s = AppState();
        await s.load();
        expect(s.history.games, hasLength(6));
        expect(s.haptics, isFalse);
        final p = await SharedPreferences.getInstance();
        expect(p.getString('stats:unread'), '[1,2,3]');
      },
    );

    test(
      'a setting of the wrong kind does not stop the progress being read',
      () async {
        final prefs = fixture();
        prefs['length'] = 'five'; // an int is expected
        SharedPreferences.setMockInitialValues(prefs);
        final s = AppState();
        await s.load();
        expect(s.stats.played, 6);
        expect(s.history.games, hasLength(6));
      },
    );
  });
}
