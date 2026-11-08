import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/earned_rows.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameRow row({
  List<String> earned = const [],
  bool largest = false,
  Object? raw,
}) => GameRow(
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
);

List<GuessRow> guesses() => [
  for (var i = 0; i < 2; i++)
    GuessRow(
      game: 0,
      n: i,
      word: ['adieu', 'crane'][i],
      skill: 90,
      luck: 0,
      before: 100,
      after: i == 1 ? 1 : 20,
      gain: 1,
      risk: 0,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('a game row keeps what it earned', () {
    test('as a row and as a map, and an old row has none', () {
      final earned = ['wins:0', 'quick:2'];
      for (final largest in [false, true]) {
        final r = row(earned: earned, largest: largest);
        final back = GameRow.fromAny(r.toRow());
        expect(back.earned, earned);
        expect(back.largest, largest);
        expect(GameRow.fromJson(r.toJson()).earned, earned);
      }
      // none earned: the row is the one it always was
      expect(row().toRow().length, 12);
      expect(row(largest: true).toRow().length, 13);
      expect(GameRow.fromAny(row().toRow()).earned, isEmpty);
      expect(row(earned: earned).toRow().length, 14);
    });

    test('a bad list is refused, not kept', () {
      final j = row().toJson();
      for (final bad in [
        'wins:0',
        ['wins'],
        ['wins:9'],
        ['Wins:0'],
        [1],
        List.filled(61, 'wins:0'),
      ]) {
        expect(
          () => GameRow.fromJson({...j, 'earned': bad}),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
    });

    test(
      'earnedFrom turns them back into achievements, skips the gone, and keeps '
      'only the top level of each',
      () {
        final a = earnedFrom([
          'wins:0',
          'wins:3',
          'nothing_like_it:1',
          'wins:9',
          'wins:1',
        ]);
        expect([for (final x in a) '${x.id}:${x.level}'], ['wins:3']);
      },
    );
  });

  group('kept by the app', () {
    test('what a game earned is saved with it, and comes back', () async {
      final s = AppState();
      await s.load();
      final id = s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['crane'],
        won: true,
        guesses: guesses(),
      );
      expect(s.history.games.single.earned, isEmpty);
      s.markEarned(id, [
        achievementById('wins')!.atLevel(0),
        achievementById('wins')!.atLevel(1),
      ]);
      expect(s.history.games.single.earned, ['wins:0', 'wins:1']);
      final again = AppState();
      await again.load();
      expect(again.history.games.single.earned, ['wins:0', 'wins:1']);
      // nothing earned changes nothing
      s.markEarned(id, const []);
      expect(s.history.games.single.earned, hasLength(2));
      // a game that is not there is left alone
      s.markEarned(999, [achievementById('wins')!.atLevel(0)]);
      expect(s.history.games, hasLength(1));
    });

    test('a backup carries it', () async {
      final s = AppState();
      await s.load();
      final id = s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['crane'],
        won: true,
        guesses: guesses(),
      );
      s.markEarned(id, [achievementById('wins')!.atLevel(0)]);
      final b = parseBackup(backupToText(s));
      expect(b.history!.games.single.earned, ['wins:0']);
    });
  });

  group('shown', () {
    Widget host(Widget w) => MaterialApp(home: Scaffold(body: w));

    testWidgets('under its own heading on the page of a game', (tester) async {
      final a = [
        achievementById('wins')!.atLevel(0),
        achievementById('quick')!.atLevel(1),
      ];
      await tester.pumpWidget(host(EarnedInGame(a)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pump();
      expect(find.text('2 earned in this game'), findsOneWidget);
      expect(find.byKey(const ValueKey('earned-rows')), findsOneWidget);
      // nothing earned, nothing shown
      await tester.pumpWidget(host(const EarnedInGame([])));
      expect(find.byKey(const ValueKey('earned-in-game')), findsNothing);
    });

    testWidgets('a strip on the row, the first few and how many more', (
      tester,
    ) async {
      final many = [
        for (final id in ['wins', 'quick', 'luck', 'bits', 'risk', 'streak'])
          achievementById(id)!.atLevel(0),
      ];
      await tester.pumpWidget(host(EarnedStrip(many)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pump();
      expect(find.text('+2'), findsOneWidget);
      await tester.pumpWidget(host(EarnedStrip(many.take(2).toList())));
      await tester.pump();
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
