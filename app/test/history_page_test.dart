import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_review.dart';
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

    expect(find.text('3 games kept · 1 won'), findsOneWidget);
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
}
