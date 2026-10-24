import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_review.dart';
import 'package:lexodle/period_chart.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

int ms(int day, [int hour = 12]) =>
    DateTime(2026, 10, day, hour).toUtc().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordBank bank;
  late List<String> pool;

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  /// The French list read (and cached) before a test pumps a page: assets are
  /// read with real file IO, which fake-async cannot wait for.
  Future<void> load(WidgetTester tester) async {
    await tester.runAsync(() async {
      final langs = await WordBank.languages();
      bank = await WordBank.load(langs.firstWhere((l) => l.code == 'fr'));
    });
    pool = bank.answers(4, 500);
  }

  GameRow addGame(
    History h, {
    required int at,
    required List<String> guesses,
    required bool won,
    GameMode mode = GameMode.classic,
    List<String>? answers,
    String daily = '',
    double skill = 70,
    int version = metricsVersion,
  }) {
    final row = h.add(
      at: at,
      lang: 'fr',
      mode: mode,
      length: 4,
      tries: mode.multi ? 9 : 6,
      pool: 500,
      answers: answers ?? [pool[10]],
      won: won,
      guesses: [
        for (var i = 0; i < guesses.length; i++)
          GuessRow(
            game: 0,
            n: i,
            word: guesses[i],
            skill: skill,
            luck: 0,
            daring: mode.multi ? null : 30,
            before: 50,
            after: 20,
          ),
      ],
      daily: daily,
    );
    if (version != metricsVersion) {
      h.games[h.games.indexWhere((g) => g.id == row.id)] = row.withVersion(
        version,
      );
    }
    return row;
  }

  Future<void> show(WidgetTester tester, History h) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.history = h;
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryPage(),
        onGenerateRoute: onGenerateRoute, // a review is opened by name
      ),
    );
    await tester.pump();
  }

  testWidgets('with no games it says so, and says why there is no style', (
    tester,
  ) async {
    await load(tester);
    appState.styleId = null;
    await show(tester, History());
    expect(find.text('no games yet'), findsOneWidget);
    expect(find.textContaining('finish a game'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data,
      'not rated yet',
    );
    expect(
      find.text(
        'play $minRatedGames more classic games to be given a playstyle',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-icon-unrated')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-skill')), findsNothing);
  });

  testWidgets('the games are listed newest first, with how each went', (
    tester,
  ) async {
    await load(tester);
    final h = History();
    final a = pool[10];
    final old = addGame(
      h,
      at: ms(22),
      guesses: [pool[1], a],
      won: true,
      skill: 80,
    );
    final mid = addGame(
      h,
      at: ms(23),
      guesses: [pool[1], pool[2], pool[3]],
      won: false,
      daily: '2026-10-23',
      skill: 60,
    );
    final quartet = addGame(
      h,
      at: ms(24),
      guesses: [pool[100], pool[101]],
      won: false,
      mode: GameMode.quartet,
      answers: pool.skip(40).take(4).toList(),
      skill: 50,
    );
    await show(tester, h);

    // the overall card adds up every game, not only the ones listed
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('overall-games'))).data,
      '3',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('overall-won'))).data,
      '33%',
    );
    // newest first
    final top = [
      for (final g in [quartet, mid, old])
        tester.getTopLeft(find.byKey(ValueKey('game-${g.id}'))).dy,
    ];
    expect(top[0], lessThan(top[1]));
    expect(top[1], lessThan(top[2]));

    expect(find.text('2026-10-22'), findsOneWidget);
    expect(find.text('2026-10-23 · daily'), findsOneWidget);
    expect(find.text('2026-10-24 · quartet'), findsOneWidget);
    expect(find.text('solved in 2/6'), findsOneWidget);
    expect(find.text('missed'), findsNWidgets(2));
    expect(find.text('skill 80'), findsOneWidget);
    expect(find.text('skill 60'), findsOneWidget);
    expect(find.text('skill 50'), findsOneWidget);
    // the answer is there to look back on
    expect(find.text(a), findsNWidgets(2));
    expect(find.text(pool.skip(40).take(4).join(' ')), findsOneWidget);
  });

  testWidgets('a guess with one word left is not part of a game\'s skill', (
    tester,
  ) async {
    await load(tester);
    final h = History();
    h.add(
      at: ms(24),
      lang: 'fr',
      mode: GameMode.classic,
      length: 4,
      tries: 6,
      pool: 500,
      answers: [pool[10]],
      won: true,
      guesses: [
        const GuessRow(game: 0, n: 0, word: 'aaaa', skill: 60, before: 50),
        const GuessRow(game: 0, n: 1, word: 'bbbb', skill: 100, before: 1),
      ],
    );
    await show(tester, h);
    expect(find.text('skill 60'), findsOneWidget);
  });

  testWidgets(
    'the profile shows the style, what it is read from, and those held',
    (tester) async {
      await load(tester);
      final h = History();
      for (var i = 0; i < 12; i++) {
        addGame(
          h,
          at: ms(1 + i),
          guesses: [pool[1], pool[2], pool[10]],
          won: true,
          skill: 95,
        );
      }
      // every guess scored 95 and was given a daring of 30
      appState.styleId = 'analyst';
      appState.stylesHeld = {'analyst', 'maverick'};
      appState.styleChanges = 1;
      await show(tester, h);
      appState.styleId = 'analyst';
      appState.stylesHeld = {'analyst', 'maverick'};
      appState.styleChanges = 1;
      appState.refresh();
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data,
        'analyst',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-blurb'))).data,
        analyst.blurb,
      );
      expect(
        find.byKey(const ValueKey('profile-icon-analyst')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stat-skill'))).data,
        '95',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stat-daring'))).data,
        '30',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stat-games'))).data,
        '12',
      );
      expect(find.textContaining('changed 1 time'), findsOneWidget);
      // all six are shown; a tap opens what a style is, and whether you have
      // been it (no tooltip: a phone has no hover, and a long press is hidden)
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile')),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      Future<String> detail(Playstyle p) async {
        await tester.tap(find.byKey(ValueKey('dot-${p.id}')));
        await tester.pump();
        return tester
            .widget<Text>(find.byKey(const ValueKey('style-detail')))
            .data!;
      }

      for (final p in playstyles) {
        expect(
          find.byKey(ValueKey('dot-${p.id}')),
          findsOneWidget,
          reason: p.id,
        );
      }
      expect(find.byKey(const ValueKey('style-detail')), findsNothing);
      expect(
        await detail(analyst),
        '${analyst.name}: ${analyst.blurb} (your style now)',
      );
      expect(
        await detail(maverick),
        '${maverick.name}: ${maverick.blurb} (you have been this)',
      );
      expect(
        await detail(wildcard),
        '${wildcard.name}: ${wildcard.blurb} (not yet)',
      );
      expect(await detail(steady), endsWith('(not yet)'));
      // tapping the open one closes it again
      await tester.tap(find.byKey(const ValueKey('dot-steady')));
      await tester.pump();
      expect(find.byKey(const ValueKey('style-detail')), findsNothing);
    },
  );

  testWidgets('the description of a style fits the narrowest phone', (
    tester,
  ) async {
    await load(tester);
    tester.view.physicalSize = const Size(320 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await appState.load();
    appState.history = History();
    appState.styleId = null;
    appState.stylesHeld = {};
    await tester.pumpWidget(
      const MaterialApp(home: HistoryPage(), onGenerateRoute: onGenerateRoute),
    );
    await tester.pump();
    for (final p in playstyles) {
      await tester.tap(find.byKey(ValueKey('dot-${p.id}')));
      await tester.pump();
      final card = tester.getRect(find.byKey(const ValueKey('profile')));
      final text = tester.getRect(find.byKey(const ValueKey('style-detail')));
      expect(text.left, greaterThanOrEqualTo(card.left), reason: p.id);
      expect(text.right, lessThanOrEqualTo(card.right), reason: p.id);
      expect(tester.takeException(), isNull, reason: p.id);
    }
  });

  testWidgets('a game opens its review, rebuilt from its guesses', (
    tester,
  ) async {
    await load(tester);
    final h = History();
    final a = pool[10];
    final g = addGame(h, at: ms(24), guesses: [pool[1], pool[2], a], won: true);
    await show(tester, h);
    await tester.tap(find.byKey(ValueKey('game-${g.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewPage), findsOneWidget);
    final page = tester.widget<ReviewPage>(find.byType(ReviewPage));
    expect(page.record.answer, a);
    expect(page.record.guesses, [pool[1], pool[2], a]);
    expect(page.record.won, isTrue);
    expect(page.record.tries, 6);
    expect(find.text('your first guess'), findsOneWidget);
    // back to the history
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byType(ReviewPage), findsNothing);
  });

  testWidgets('a quartet opens its own review', (tester) async {
    await load(tester);
    final h = History();
    final answers = pool.skip(40).take(4).toList();
    final g = addGame(
      h,
      at: ms(24),
      guesses: [pool[100], pool[101]],
      won: false,
      mode: GameMode.quartet,
      answers: answers,
    );
    await show(tester, h);
    await tester.tap(find.byKey(ValueKey('game-${g.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(MultiReviewPage), findsOneWidget);
    final page = tester.widget<MultiReviewPage>(find.byType(MultiReviewPage));
    expect(page.record.answers, answers);
    expect(page.record.mode, GameMode.quartet);
    expect(page.record.guesses, [pool[100], pool[101]]);
  });

  testWidgets('a game in a language that has gone does not open', (
    tester,
  ) async {
    await load(tester);
    final h = History();
    final row = h.add(
      at: ms(24),
      lang: 'xx',
      mode: GameMode.classic,
      length: 4,
      tries: 6,
      pool: 500,
      answers: ['abcd'],
      won: true,
      guesses: const [GuessRow(game: 0, n: 0, word: 'abcd', skill: 50)],
    );
    await show(tester, h);
    await tester.tap(find.byKey(ValueKey('game-${row.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewPage), findsNothing);
    expect(find.byType(HistoryPage), findsOneWidget);
  });

  testWidgets(
    'games saved under older maths are scored again while it is open',
    (tester) async {
      await load(tester);
      final h = History();
      final a = pool[10];
      final g = addGame(
        h,
        at: ms(24),
        guesses: [pool[1], pool[2], a],
        won: true,
        skill: 3.14,
        version: 0,
      );
      expect(h.stale().length, 1);
      await show(tester, h);
      expect(find.textContaining('scoring 0 of 1 older games'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(h.stale(), isEmpty);
      expect(find.textContaining('older games again'), findsNothing);
      final rows = h.guessesOf(g.id);
      expect(rows.every((r) => r.skill != 3.14), isTrue);
      expect(rows.first.daring, isNotNull);
      expect(h.byId(g.id)!.version, metricsVersion);
      // and the skill the list shows is the new one
      // (a guess with one word left is not part of it)
      final scored = [
        for (final r in rows)
          if (r.before > 1) r.skill,
      ];
      final mean = scored.reduce((x, y) => x + y) / scored.length;
      expect(find.text('skill ${mean.round()}'), findsOneWidget);
    },
  );

  testWidgets('nothing is scored again when nothing is stale', (tester) async {
    await load(tester);
    final h = History();
    addGame(h, at: ms(24), guesses: [pool[1]], won: false);
    await show(tester, h);
    await tester.pumpAndSettle();
    expect(find.textContaining('older games'), findsNothing);
  });

  testWidgets('the style on the home page opens the history', (tester) async {
    await load(tester);
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.history = History();
    appState.styleId = 'maverick';
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('style-chip')));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data,
      'maverick',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsNothing);
  });

  testWidgets('it has an address of its own', (tester) async {
    await load(tester);
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.history = History();
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: Routes.history,
        onGenerateRoute: onGenerateRoute,
        onGenerateInitialRoutes: onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
  });

  group('with thousands of games', () {
    setUp(() => dailyClock = () => DateTime(2026, 10, 24, 12));
    tearDown(() => dailyClock = DateTime.now);

    /// [n] games, one every [hours] hours back from the evening of the 24th.
    History many(int n, {int hours = 4, double skill = 80}) {
      final h = History();
      final end = DateTime(2026, 10, 24, 20);
      for (var i = n - 1; i >= 0; i--) {
        h.add(
          at: end
              .subtract(Duration(hours: i * hours))
              .toUtc()
              .millisecondsSinceEpoch,
          lang: 'fr',
          mode: GameMode.classic,
          length: 4,
          tries: 6,
          pool: 500,
          answers: [pool[i % 50]],
          won: i % 3 != 0,
          guesses: [
            GuessRow(
              game: 0,
              n: 0,
              word: pool[1],
              skill: skill,
              luck: 10,
              daring: 20,
              before: 100,
              after: 50,
            ),
            GuessRow(
              game: 0,
              n: 1,
              word: pool[2],
              skill: skill,
              luck: 10,
              daring: 20,
              before: 50,
              after: 5,
            ),
          ],
        );
      }
      return h;
    }

    Finder tile(History h, int fromNewest) => find.byKey(
      ValueKey('game-${h.games[h.games.length - 1 - fromNewest].id}'),
    );

    testWidgets('only the last ten are listed, newest first', (tester) async {
      await load(tester);
      final h = many(45);
      await show(tester, h);
      for (var k = 0; k < 10; k++) {
        expect(tile(h, k), findsOneWidget, reason: 'the ${k + 1}th newest');
      }
      expect(tile(h, 10), findsNothing, reason: 'the eleventh is not loaded');
      expect(tile(h, 44), findsNothing);
      final top = [
        for (var k = 0; k < 10; k++) tester.getTopLeft(tile(h, k)).dy,
      ];
      expect(top, orderedEquals([...top]..sort()), reason: 'newest at the top');
      expect(find.text('load 10 more · 35 left'), findsOneWidget);
    });

    testWidgets('the overall is of every game, not of the ten shown', (
      tester,
    ) async {
      await load(tester);
      final h = many(45);
      await show(tester, h);
      Text overall(String k) =>
          tester.widget<Text>(find.byKey(ValueKey('overall-$k')));
      expect(overall('games').data, '45');
      // 45 games, every third one (i % 3 == 0) missed: 15 missed, 30 won
      expect(overall('won').data, '67%');
      expect(overall('skill').data, '80');
      expect(overall('daring').data, '20');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('overall-line'))).data,
        contains('luck +10%'),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('overall-line'))).data,
        contains('2.0 guesses to win'),
      );
    });

    testWidgets('load more adds ten at a time, until there are no more', (
      tester,
    ) async {
      await load(tester);
      final h = many(35);
      await show(tester, h);
      final more = find.byKey(const ValueKey('load-more'));
      Future<void> press() async {
        await tester.scrollUntilVisible(more, 300);
        await tester.tap(more);
        await tester.pump();
      }

      expect(find.text('load 10 more · 25 left'), findsOneWidget);
      await press();
      await tester.scrollUntilVisible(tile(h, 19), 300);
      expect(tile(h, 19), findsOneWidget, reason: 'twenty now');
      await tester.scrollUntilVisible(more, 300);
      expect(find.text('load 10 more · 15 left'), findsOneWidget);
      await press();
      await tester.scrollUntilVisible(more, 300);
      expect(find.text('load 5 more · 5 left'), findsOneWidget);
      await press();
      await tester.scrollUntilVisible(tile(h, 34), 300);
      expect(tile(h, 34), findsOneWidget, reason: 'the oldest, last of all');
      expect(more, findsNothing, reason: 'nothing left to load');
    });

    testWidgets('a short history has no button', (tester) async {
      await load(tester);
      await show(tester, many(7));
      expect(find.byKey(const ValueKey('load-more')), findsNothing);
      expect(find.textContaining('load '), findsNothing);
    });

    testWidgets('exactly ten has none either', (tester) async {
      await load(tester);
      await show(tester, many(10));
      expect(find.byKey(const ValueKey('load-more')), findsNothing);
    });

    testWidgets('ten thousand games open at once, and show ten', (
      tester,
    ) async {
      await load(tester);
      final started = Stopwatch()..start();
      final h = many(historyCap, hours: 1);
      await show(tester, h);
      expect(started.elapsed, lessThan(const Duration(seconds: 30)));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('overall-games'))).data,
        '10000',
      );
      expect(find.text('load 10 more · 9990 left'), findsOneWidget);
      expect(tile(h, 9), findsOneWidget);
      expect(tile(h, 10), findsNothing);
    });
  });

  group('how play changed, week by week and month by month', () {
    setUp(() => dailyClock = () => DateTime(2026, 10, 24, 12));
    tearDown(() => dailyClock = DateTime.now);

    /// A game on a day of 2026, with these scores on its two guesses.
    void game(
      History h,
      DateTime day, {
      double skill = 70,
      double luck = 0,
      double? daring = 30,
      bool won = true,
      String lang = 'fr',
    }) {
      h.add(
        at: DateTime(
          day.year,
          day.month,
          day.day,
          12,
        ).toUtc().millisecondsSinceEpoch,
        lang: lang,
        mode: GameMode.classic,
        length: 4,
        tries: 6,
        pool: 500,
        answers: [pool[3]],
        won: won,
        guesses: [
          for (var i = 0; i < 2; i++)
            GuessRow(
              game: 0,
              n: i,
              word: pool[i + 1],
              skill: skill,
              luck: luck,
              daring: daring,
              before: 100,
              after: 10,
            ),
        ],
      );
    }

    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('it starts on the last 50 weeks, with the latest picked', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24), skill: 80, luck: 10, daring: 20);
      game(
        h,
        DateTime(2026, 10, 22),
        skill: 90,
        luck: -20,
        daring: 40,
        won: false,
      );
      await show(tester, h);
      expect(find.text('the last 50 weeks'), findsOneWidget);
      expect(text(tester, 'period-label'), '2026-10-18 to 2026-10-24');
      final detail = text(tester, 'period-detail');
      expect(detail, contains('2 games'));
      expect(detail, contains('50% won'));
      expect(detail, contains('skill 85'));
      expect(detail, contains('daring 30'));
      expect(detail, contains('luck −5%'));
      expect(find.byType(PeriodChart), findsOneWidget);
    });

    testWidgets('months show the same history by calendar month', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24), skill: 80);
      game(h, DateTime(2026, 10, 3), skill: 60);
      game(h, DateTime(2026, 9, 28), skill: 50);
      await show(tester, h);
      await tester.tap(find.text('months'));
      await tester.pump();
      expect(find.text('the last 50 months'), findsOneWidget);
      expect(text(tester, 'period-label'), '2026-10');
      expect(text(tester, 'period-detail'), contains('2 games'));
      expect(text(tester, 'period-detail'), contains('skill 70'));
      // and back to weeks
      await tester.tap(find.text('weeks'));
      await tester.pump();
      expect(find.text('the last 50 weeks'), findsOneWidget);
      expect(text(tester, 'period-label'), '2026-10-18 to 2026-10-24');
    });

    testWidgets('all three lines are drawn, and each can be switched off', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24));
      await show(tester, h);
      Set<PeriodSeries> shown() =>
          tester.widget<PeriodChart>(find.byType(PeriodChart)).shown;
      expect(shown(), {
        PeriodSeries.skill,
        PeriodSeries.luck,
        PeriodSeries.daring,
      });
      await tester.tap(find.byKey(const ValueKey('series-luck')));
      await tester.pump();
      expect(shown(), {PeriodSeries.skill, PeriodSeries.daring});
      await tester.tap(find.byKey(const ValueKey('series-skill')));
      await tester.pump();
      expect(shown(), {PeriodSeries.daring});
      await tester.tap(find.byKey(const ValueKey('series-skill')));
      await tester.pump();
      expect(shown(), {PeriodSeries.skill, PeriodSeries.daring});
      // luck says where its middle is
      expect(find.text('luck (50 = 0%)'), findsOneWidget);
    });

    testWidgets('tapping the chart picks the period under the finger', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24), skill: 80);
      game(h, DateTime(2026, 10, 14), skill: 60);
      await show(tester, h);
      final chart = find.byKey(const ValueKey('period-chart'));
      final rect = tester.getRect(chart);
      // the plot starts after the axis (26 px) and holds 50 slots
      final slot = (rect.width - 26) / 50;
      Offset at(int i) =>
          Offset(rect.left + 26 + slot * (i + .5), rect.center.dy);

      await tester.tapAt(at(48));
      await tester.pump();
      expect(text(tester, 'period-label'), '2026-10-11 to 2026-10-17');
      expect(text(tester, 'period-detail'), contains('1 game'));
      expect(text(tester, 'period-detail'), contains('skill 60'));

      await tester.tapAt(at(0));
      await tester.pump();
      expect(text(tester, 'period-label'), startsWith('2025-'));
      expect(text(tester, 'period-detail'), 'no games');

      await tester.tapAt(at(49));
      await tester.pump();
      expect(text(tester, 'period-label'), '2026-10-18 to 2026-10-24');
      expect(text(tester, 'period-detail'), contains('skill 80'));
      // a tap on the axis, before the first period, picks the first
      await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
      await tester.pump();
      expect(text(tester, 'period-detail'), 'no games');
    });

    testWidgets('dragging along the chart moves the pick', (tester) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24));
      game(h, DateTime(2026, 10, 14), skill: 55);
      await show(tester, h);
      final rect = tester.getRect(find.byKey(const ValueKey('period-chart')));
      final slot = (rect.width - 26) / 50;
      final g = await tester.startGesture(
        Offset(rect.left + 26 + slot * 49.5, rect.center.dy),
      );
      // ten weeks to the left, in steps (a drag has to pass the touch slop)
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset(-slot, 0));
      }
      await tester.pump();
      expect(
        text(tester, 'period-label'),
        '${dailyShift('2026-10-24', -76)} to ${dailyShift('2026-10-24', -70)}',
      );
      await g.up();
    });

    testWidgets('a period says what changed since the last one you played', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24), skill: 80, luck: 20, daring: 10);
      // two weeks earlier (the week between was not played)
      game(h, DateTime(2026, 10, 10), skill: 70, luck: -10, daring: 40);
      await show(tester, h);
      final change = text(tester, 'period-change');
      expect(change, contains('skill +10'));
      expect(change, contains('luck +30%'));
      expect(change, contains('daring −30'));
      expect(change, endsWith('on the last week you played'));
      // a switched-off line is not reported
      await tester.tap(find.byKey(const ValueKey('series-luck')));
      await tester.pump();
      expect(text(tester, 'period-change'), isNot(contains('luck')));
      expect(text(tester, 'period-change'), contains('skill +10'));
    });

    testWidgets('the first period played has nothing to be compared with', (
      tester,
    ) async {
      await load(tester);
      final h = History();
      game(h, DateTime(2026, 10, 24));
      await show(tester, h);
      expect(find.byKey(const ValueKey('period-change')), findsNothing);
    });

    testWidgets('a week that played like a style says which', (tester) async {
      await load(tester);
      final h = History();
      for (var i = 0; i < 12; i++) {
        game(h, DateTime(2026, 10, 24), skill: 95, daring: 10);
      }
      await show(tester, h);
      expect(text(tester, 'period-style'), 'played like a analyst');
      expect(find.byKey(const ValueKey('period-style')), findsOneWidget);
    });

    testWidgets('no history: the chart is there, empty, and says so', (
      tester,
    ) async {
      await load(tester);
      await show(tester, History());
      expect(find.byType(PeriodChart), findsOneWidget);
      expect(text(tester, 'period-detail'), 'no games');
      expect(find.byKey(const ValueKey('period-change')), findsNothing);
      expect(text(tester, 'overall-games'), '0');
      expect(text(tester, 'overall-won'), '–');
      expect(text(tester, 'overall-skill'), '–');
      expect(text(tester, 'overall-line'), 'nothing to add up yet');
    });

    testWidgets('it fits the narrowest phone', (tester) async {
      await load(tester);
      final h = History();
      for (var d = 0; d < 20; d++) {
        game(h, DateTime(2026, 10, 24).subtract(Duration(days: d * 3)));
      }
      tester.view.physicalSize = const Size(320 * 2, 1700 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await appState.load();
      appState.history = h;
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryPage(),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('trend')));
      final chart = tester.getRect(find.byKey(const ValueKey('period-chart')));
      expect(chart.left, greaterThanOrEqualTo(card.left));
      expect(chart.right, lessThanOrEqualTo(card.right));
      await tester.tap(find.text('months'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'games scored with older maths are counted, but not in the lines',
      (tester) async {
        await load(tester);
        final h = History();
        game(h, DateTime(2026, 10, 24), skill: 90);
        // in a language that is not loaded, so the page has nothing to score it
        // with and leaves it as it is (it would otherwise score it again)
        game(h, DateTime(2026, 10, 24), skill: 10, lang: 'xx');
        h.games[1] = h.games[1].withVersion(0);
        await show(tester, h);
        expect(text(tester, 'period-detail'), contains('2 games'));
        expect(text(tester, 'period-detail'), contains('skill 90'));
        expect(text(tester, 'overall-skill'), '90');
        expect(
          text(tester, 'overall-stale'),
          contains('1 game saved under older maths is left out'),
        );
      },
    );
  });
}
