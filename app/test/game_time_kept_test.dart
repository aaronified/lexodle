import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameRow row({int? ms, bool largest = false, List<String> earned = const []}) =>
    GameRow(
      id: 1,
      at: DateTime.utc(2026, 11, 5).millisecondsSinceEpoch,
      lang: 'en',
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 100,
      answers: const ['crane'],
      won: true,
      largest: largest,
      earned: earned,
      ms: ms,
    );

List<GuessRow> guesses() => [
  GuessRow(
    game: 0,
    n: 0,
    word: 'crane',
    skill: 90,
    luck: 0,
    before: 100,
    after: 1,
    gain: 1,
    risk: 0,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the time of a game row', () {
    test('round trips as a row and as a map', () {
      for (final largest in [false, true]) {
        for (final earned in [const <String>[], const ['wins:0']]) {
          final r = row(ms: 83000, largest: largest, earned: earned);
          final a = GameRow.fromAny(r.toRow());
          expect(a.ms, 83000);
          expect(a.largest, largest);
          expect(a.earned, earned);
          expect(GameRow.fromJson(r.toJson()).ms, 83000);
        }
      }
      expect(row(ms: 0).toRow().length, 15);
      expect(GameRow.fromAny(row(ms: 0).toRow()).ms, 0);
    });

    test('a row from before has none, and is written as it was', () {
      expect(row().toRow().length, 12);
      expect(GameRow.fromAny(row().toRow()).ms, isNull);
      expect(GameRow.fromJson(row().toJson()).ms, isNull);
      expect(row().toJson().containsKey('ms'), isFalse);
    });

    test('a bad time is refused', () {
      final j = row().toJson();
      for (final bad in [-1, 'x', 1.5, true]) {
        expect(
          () => GameRow.fromJson({...j, 'ms': bad}),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
    });

    test('the time is kept when the version or earnings change', () {
      final h = History();
      final g = h.add(
        at: 1000,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['crane'],
        won: true,
        guesses: guesses(),
        ms: 4000,
      );
      expect(g.ms, 4000);
      expect(g.withVersion(1).ms, 4000);
      h.setEarned(g.id, ['wins:0']);
      expect(h.byId(g.id)!.ms, 4000);
      expect(History.fromJson(h.toJson()).games.single.ms, 4000);
    });
  });

  group('the app state', () {
    test('recordHistory keeps the time, in a backup too', () async {
      final s = AppState();
      await s.load();
      s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['crane'],
        won: true,
        guesses: guesses(),
        ms: 61000,
      );
      s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['crane'],
        won: true,
        guesses: guesses(),
      );
      expect(s.history.games.map((g) => g.ms), [61000, null]);
      final b = parseBackup(backupToText(s));
      expect(b.history!.games.map((g) => g.ms), [61000, null]);
      final again = AppState();
      await again.load();
      expect(again.history.games.map((g) => g.ms), [61000, null]);
    });

    test('the time played comes back with a game left half played', () async {
      final s = AppState();
      await s.load();
      expect(s.savedElapsedMs('p|en|classic|5|6'), 0);
      s.saveProgress('p|en|classic|5|6', {
        'g': ['adieu'],
      }, ms: 12345);
      s.saveProgress('d|en|2026-11-12|classic', {'g': <String>[]});
      expect(s.savedElapsedMs('p|en|classic|5|6'), 12345);
      expect(s.progressFor('p|en|classic|5|6')!['g'], ['adieu']);
      expect(s.savedElapsedMs('d|en|2026-11-12|classic'), 0);
      final again = AppState();
      await again.load();
      expect(again.savedElapsedMs('p|en|classic|5|6'), 12345);
    });
  });
}
