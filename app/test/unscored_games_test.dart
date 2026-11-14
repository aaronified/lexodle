import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/analysis.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/collection.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/multi_review.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/replay.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

List<GuessRow> rows(List<String> words) => [
  for (var i = 0; i < words.length; i++)
    GuessRow(
      game: 0,
      n: i,
      word: words[i],
      skill: 70,
      luck: 5,
      risk: 30,
      gain: .4,
      before: 100 - i * 10,
      after: 90 - i * 10,
    ),
];

GameRow addGame(
  History h, {
  bool unscored = false,
  bool won = true,
  int? at,
  String lang = 'en',
  int? ms,
}) => h.add(
  at: at ?? DateTime.now().millisecondsSinceEpoch,
  lang: lang,
  mode: GameMode.classic,
  length: 5,
  tries: 6,
  pool: 3000,
  answers: const ['slate'],
  won: won,
  guesses: rows(['crane', 'slate']),
  unscored: unscored,
  ms: ms,
);

GameRow row({bool unscored = false, int? ms, bool largest = false}) => GameRow(
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
  ms: ms,
  unscored: unscored,
);

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the unscored mark of a row', () {
    test('an old row, and an old map, are scored', () {
      expect(GameRow.fromAny(row().toRow()).unscored, isFalse);
      expect(GameRow.fromJson(row().toJson()).unscored, isFalse);
      expect(row().toRow().length, 12, reason: 'written as it was');
      expect(row().toJson().containsKey('unscored'), isFalse);
      expect(row(ms: 5).toRow().length, 15);
    });

    test('it round trips as a row and as a map, with and without a time', () {
      for (final ms in [null, 0, 83000]) {
        for (final largest in [false, true]) {
          final r = row(unscored: true, ms: ms, largest: largest);
          expect(r.toRow().length, 16);
          final a = GameRow.fromAny(jsonDecode(jsonEncode(r.toRow())));
          expect(a.unscored, isTrue);
          expect(a.ms, ms);
          expect(a.largest, largest);
          final b = GameRow.fromJson(r.toJson());
          expect(b.unscored, isTrue);
          expect(b.ms, ms);
        }
      }
    });

    test('it is kept when the version or earnings change', () {
      final h = History();
      final g = addGame(h, unscored: true, ms: 4000);
      expect(g.withVersion(1).unscored, isTrue);
      expect(g.withEarned(['wins:0']).unscored, isTrue);
      h.setEarned(g.id, ['wins:0']);
      expect(h.byId(g.id)!.unscored, isTrue);
      expect(History.fromJson(h.toJson()).games.single.unscored, isTrue);
    });

    test('a bad value is refused, in a row and in a map', () {
      final j = row(unscored: true).toJson();
      for (final bad in [1, 'x', 0.5, <int>[]]) {
        expect(
          () => GameRow.fromJson({...j, 'unscored': bad}),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
      final r = row(unscored: true, ms: 5).toRow();
      for (final bad in [2, -1, 'x', true, null]) {
        expect(
          () => GameRow.fromAny([...r.take(15), bad]),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
    });

    test('a backup keeps it, and one with a bad value is refused', () async {
      final s = AppState();
      await s.load();
      s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['slate'],
        won: true,
        guesses: rows(['slate']),
        ms: 9000,
        unscored: true,
      );
      s.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['slate'],
        won: true,
        guesses: rows(['slate']),
      );
      final text = backupToText(s);
      final b = parseBackup(text);
      expect(b.history!.games.map((g) => g.unscored), [true, false]);
      final again = AppState();
      await again.load();
      expect(again.history.games.map((g) => g.unscored), [true, false]);

      final j = jsonDecode(text) as Map<String, dynamic>;
      final h = jsonDecode(j['history'] as String) as Map<String, dynamic>;
      (h['games'] as List)[0][15] = 'yes';
      j['history'] = jsonEncode(h);
      expect(() => parseBackup(jsonEncode(j)), throwsFormatException);
    });

    test('a game with no guess is kept only when it is not scored', () {
      final h = History()
        ..add(
          at: 5,
          lang: 'en',
          mode: GameMode.classic,
          length: 5,
          tries: 6,
          pool: 100,
          answers: ['crane'],
          won: false,
          guesses: const [],
          unscored: true,
        );
      expect(History.fromJson(h.toJson()).games.single.unscored, isTrue);
      final (kept, dropped) = History.recover([h.chunk(h.months().single)]);
      expect(kept.games, hasLength(1));
      expect(dropped, 0);
      final scored = History()
        ..add(
          at: 5,
          lang: 'en',
          mode: GameMode.classic,
          length: 5,
          tries: 6,
          pool: 100,
          answers: ['crane'],
          won: false,
          guesses: const [],
        );
      expect(() => History.fromJson(scored.toJson()), throwsFormatException);
      expect(
        History.recover([scored.chunk(scored.months().single)]).$1.games,
        isEmpty,
      );
    });
  });

  group('the aggregates leave an unscored game out', () {
    test('scoredGames, and the games of a playstyle', () {
      final h = History();
      addGame(h);
      final u = addGame(h, unscored: true);
      expect(h.games, hasLength(2));
      expect(h.scoredGames.map((g) => g.id), isNot(contains(u.id)));
      expect(h.scoredGames, hasLength(1));
      expect(h.recent(null), hasLength(1));
      expect(h.recent(GameMode.classic, 100, 'en'), hasLength(1));
      expect(habitsOf(h, mode: GameMode.classic, lang: 'en').games, 1);
      final only = History();
      addGame(only, unscored: true);
      expect(only.recent(null), isEmpty);
      expect(habitsOf(only, mode: GameMode.classic, lang: 'en').games, 0);
      expect(traitsOf(only, mode: GameMode.classic, lang: 'en'), isNull);
    });

    test('a game that is not scored is never stale', () {
      final h = History();
      final u = addGame(h, unscored: true);
      h.games[0] = u.withVersion(1);
      expect(h.stale(), isEmpty);
    });

    test('the weeks, months and days add up the scored games only', () {
      final today = dailyDate();
      final h = History();
      addGame(h);
      addGame(h, unscored: true);
      addGame(h, unscored: true, won: false);
      int games(List<Period> ps) => ps.fold(0, (a, p) => a + p.stats.games);
      expect(games(weeklyPeriods(h, today)), 1);
      expect(games(monthlyPeriods(h, today)), 1);
      expect(games(dailyPeriods(h, today)), 1);
      expect(
        weeklyPeriods(h, today).fold<int>(0, (a, p) => a + p.stats.won),
        1,
      );
    });

    test('the languages played, the achievements and the words won', () async {
      final a = AppState();
      await a.load();
      a.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['clubs'],
        won: true,
        guesses: rows(['clubs']),
      );
      a.recordHistory(
        lang: 'de',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['haeus'],
        won: true,
        guesses: rows(['haeus']),
        unscored: true,
      );
      // listed, but not collected
      expect(a.collection.wordsOf('de'), isEmpty);
      expect(a.collection.wordsOf('en'), ['clubs']);
      expect(a.playedLanguages, isNot(contains('de')));
      expect(a.history.games, hasLength(2));

      a.collection = Collection();
      a.rebuildAchievements();
      expect(a.collection.wordsOf('en'), ['clubs']);
      expect(a.collection.wordsOf('de'), isEmpty);
      expect(a.ach['played']?.value, 1);
      expect(a.ach['wins']?.value, 1);
    });

    test('a restored backup collects the words of scored games only', () async {
      final a = AppState();
      await a.load();
      a.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['clubs'],
        won: true,
        guesses: rows(['clubs']),
      );
      a.recordHistory(
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: ['tours'],
        won: true,
        guesses: rows(['tours']),
        unscored: true,
      );
      final backup = parseBackup(backupToText(a));
      final b = AppState();
      await b.load();
      b.restore(
        settings: backup.settings,
        stats: backup.stats,
        ach: backup.achievements,
        history: backup.history,
      );
      expect(b.history.games, hasLength(2));
      expect(b.collection.wordsOf('en'), ['clubs']);
    });
  });

  group('the screens', () {
    late WordBank bank;

    Future<void> load(WidgetTester tester) async {
      await tester.runAsync(() async {
        final langs = await WordBank.languages();
        bank = await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
      });
      await tester.binding.setSurfaceSize(const Size(420, 1900));
      await appState.load();
      appState.lang = 'en';
    }

    testWidgets('the history list shows the tag; the overall card does not '
        'count the game', (tester) async {
      await load(tester);
      final h = History();
      final a = addGame(h, at: DateTime.now().millisecondsSinceEpoch - 5000);
      final u = addGame(h, unscored: true);
      appState.history = h;
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryPage(),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.byKey(ValueKey('game-${a.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('game-${u.id}')), findsOneWidget);
      expect(find.text('not scored'), findsOneWidget);
      expect(find.byKey(ValueKey('unscored-${u.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('unscored-${a.id}')), findsNothing);
      expect(
        textOf(
          tester.widget<Text>(find.byKey(const ValueKey('overall-games'))),
        ),
        '1',
      );
    });

    testWidgets('the achievements page counts the scored games played', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      addGame(h);
      addGame(h, unscored: true);
      addGame(h, unscored: true, won: false);
      appState.history = h;
      appState.ach = {};
      appState.stats = Stats();
      await tester.binding.setSurfaceSize(const Size(420, 4000));
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsPage(),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      Finder value(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(Text),
      );
      final played = tester.widgetList<Text>(value('played')).map(textOf);
      expect(played.first, '1');
      final won = tester.widgetList<Text>(value('won')).map(textOf);
      expect(won.first, '1');
    });

    testWidgets('the review of an unscored game says so where skill would be', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      final answer = bank.answers(5)[10];
      final u = h.add(
        at: 5,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: [answer],
        won: true,
        guesses: rows([bank.answers(5)[3], answer]),
        unscored: true,
      );
      final s = h.add(
        at: 6,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 100,
        answers: [answer],
        won: true,
        guesses: rows([bank.answers(5)[3], answer]),
      );
      for (final (g, scored) in [(u, false), (s, true)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(record: replayClassic(bank, g, h.guessesOf(g.id))),
            onGenerateRoute: onGenerateRoute,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('not-scored')),
          scored ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('made or opened from a link: it does not count'),
          scored ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pill-skill')),
          scored ? findsOneWidget : findsNothing,
        );
      }
    });

    testWidgets('the review of an unscored quartet says so', (tester) async {
      await load(tester);
      final words = ['crane', 'plumb', 'ghost', 'fifty'];
      final h = History();
      final u = h.add(
        at: 5,
        lang: 'en',
        mode: GameMode.quartet,
        length: 5,
        tries: 9,
        pool: 100,
        answers: words,
        won: false,
        guesses: rows(['crane']),
        unscored: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MultiReviewPage(
            record: replayMulti(bank, u, h.guessesOf(u.id)),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('not-scored')), findsOneWidget);
      expect(
        find.text('made or opened from a link: it does not count'),
        findsOneWidget,
      );
    });

    Future<void> play(
      WidgetTester tester,
      Widget page, {
      List<String> words = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(home: page, onGenerateRoute: onGenerateRoute),
      );
      await tester.pump();
      for (final w in words) {
        for (final ch in w.split('')) {
          await tester.sendKeyEvent(_key(ch), character: ch);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
    }

    String snapshot() => [
      appState.stats.played,
      appState.stats.wins,
      appState.stats.streak,
      appState.dailyStreak,
      appState.unlockedCount,
      appState.lexBalance,
      appState.styleIdOf('en'),
      appState.collection.total,
      appState.freeHints,
      jsonEncode(appState.ach.map((k, v) => MapEntry(k, v.toJson()))),
    ].join('|');

    testWidgets('a made puzzle played to the end writes one unscored row and '
        'scores nothing', (tester) async {
      await load(tester);
      final before = snapshot();
      await play(
        tester,
        GamePage(
          bank: bank,
          practice: true,
          chosen: true,
          daily: const Daily('', 'crane', length: 5, tries: 6),
        ),
        words: ['stare', 'crane'],
      );
      expect(find.text('not scored'), findsOneWidget);
      expect(find.text('practice · not counted'), findsNothing);
      final games = appState.history.games;
      expect(games, hasLength(1));
      final g = games.single;
      expect(g.unscored, isTrue);
      expect(g.won, isTrue);
      expect(g.mode, GameMode.classic);
      expect(g.ms, isNotNull);
      expect(g.answers, ['crane']);
      expect(g.daily, '');
      expect(appState.history.guessesOf(g.id).map((r) => r.word), [
        'stare',
        'crane',
      ]);
      expect(snapshot(), before);
      expect(appState.history.scoredGames, isEmpty);
      final s = summarise(appState.history, appState.history.scoredGames);
      expect((s.games, s.scored, s.skill), (0, 0, 0));
      expect(appState.history.recent(null), isEmpty);
      expect(appState.collection.wordsOf('en'), isEmpty);
      // and it is still there after a restart
      final again = AppState();
      await again.load();
      expect(again.history.games.single.unscored, isTrue);
    });

    testWidgets('a lost made puzzle is listed too, once', (tester) async {
      await load(tester);
      await play(
        tester,
        GamePage(
          bank: bank,
          practice: true,
          chosen: true,
          daily: const Daily('', 'crane', length: 5, tries: 2),
        ),
        words: ['stare', 'slate'],
      );
      expect(appState.history.games, hasLength(1));
      expect(appState.history.games.single.won, isFalse);
      expect(appState.history.games.single.unscored, isTrue);
      expect(appState.stats.played, 0);
    });

    testWidgets('a daily opened as practice leaves the real daily alone', (
      tester,
    ) async {
      await load(tester);
      final date = dailyDate();
      final before = snapshot();
      await play(
        tester,
        GamePage(
          bank: bank,
          practice: true,
          daily: Daily(date, 'crane', length: 5, tries: 6),
        ),
        words: ['crane'],
      );
      expect(appState.dailyFor('en', date, GameMode.classic), isNull);
      expect(appState.dailyLogOf('en'), isEmpty);
      expect(appState.history.games.single.unscored, isTrue);
      expect(appState.history.games.single.daily, '');
      expect(snapshot(), before);
    });

    testWidgets('a made puzzle that times out with no guess writes a row', (
      tester,
    ) async {
      await load(tester);
      var now = Duration.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            practice: true,
            chosen: true,
            clock: () => now,
            limit: const Duration(minutes: 1),
            daily: const Daily('', 'crane', length: 5, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(_key('a'), character: 'a');
      await tester.pump();
      now += const Duration(seconds: 61);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('time is up'), findsOneWidget);
      final g = appState.history.games.single;
      expect((g.unscored, g.won, g.ms), (true, false, 60000));
      expect(appState.history.guessesOf(g.id), isEmpty);
      expect(appState.stats.played, 0);
      now += const Duration(minutes: 5);
      await tester.pump(const Duration(minutes: 5));
      expect(appState.history.games, hasLength(1), reason: 'once');
      // it is read back, and listed with nothing to open
      final again = AppState();
      await again.load();
      expect(again.history.games.single.unscored, isTrue);
    });

    testWidgets('a mastermind that times out has a word that fits', (
      tester,
    ) async {
      await load(tester);
      var now = Duration.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.mastermind,
            practice: true,
            chosen: true,
            clock: () => now,
            limit: const Duration(minutes: 1),
            daily: const Daily('', 'crane', length: 5, tries: 0),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(_key('a'), character: 'a');
      await tester.pump();
      now += const Duration(seconds: 61);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      final again = AppState();
      await again.load();
      final g = again.history.games.single;
      expect(g.unscored, isTrue);
      expect(g.answers.single.length, 5);
    });

    testWidgets('a link that carries guesses is not written', (tester) async {
      await load(tester);
      await play(
        tester,
        GamePage(
          bank: bank,
          practice: true,
          replay: const ['stare'],
          daily: const Daily('', 'crane', length: 5, tries: 6),
        ),
        words: ['crane'],
      );
      expect(find.text('not scored'), findsOneWidget);
      expect(appState.history.games, isEmpty);
    });

    testWidgets('a quartet made puzzle played to the end writes one row', (
      tester,
    ) async {
      await load(tester);
      final words = ['crane', 'plumb', 'ghost', 'fifty'];
      final before = snapshot();
      await play(
        tester,
        MultiGamePage(
          bank: bank,
          practice: true,
          daily: DailyMulti('', GameMode.quartet, words, length: 5, tries: 9),
        ),
        words: words,
      );
      expect(find.text('not scored'), findsOneWidget);
      final g = appState.history.games.single;
      expect((g.unscored, g.won, g.mode), (true, true, GameMode.quartet));
      expect(g.answers, words);
      expect(g.ms, isNotNull);
      expect(snapshot(), before);
      expect(appState.history.scoredGames, isEmpty);
    });

    testWidgets('a quartet that times out with no guess writes a row', (
      tester,
    ) async {
      await load(tester);
      var now = Duration.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: MultiGamePage(
            bank: bank,
            practice: true,
            clock: () => now,
            limit: const Duration(minutes: 1),
            daily: DailyMulti(
              '',
              GameMode.quartet,
              ['crane', 'plumb', 'ghost', 'fifty'],
              length: 5,
              tries: 9,
            ),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(_key('a'), character: 'a');
      await tester.pump();
      now += const Duration(seconds: 61);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      final g = appState.history.games.single;
      expect((g.unscored, g.won, g.ms), (true, false, 60000));
      expect(appState.history.guessesOf(g.id), isEmpty);
    });
  });
}
