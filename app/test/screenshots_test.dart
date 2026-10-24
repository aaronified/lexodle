// The screenshots in the README, taken from the real screens rendered at phone
// size, in the app's own fonts and a dark theme, from seeded state, so they can
// be taken again whenever the interface changes. Not part of a normal run:
//
//   LEXODLE_SCREENSHOTS=1 flutter test test/screenshots_test.dart
//
// (PowerShell: $env:LEXODLE_SCREENSHOTS = 1.) The PNGs are written to
// docs/screenshots/ at the top of the repository.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/background.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/learn.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/replay.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fonts.dart';

/// A phone, in logical pixels; the pictures are twice that.
const phone = Size(412, 860);

final skip = Platform.environment.containsKey('LEXODLE_SCREENSHOTS')
    ? null
    : 'set LEXODLE_SCREENSHOTS=1 to take the README screenshots';

/// The day the screenshots are of (a Saturday), so the week is the same each time.
final today = DateTime(2026, 10, 24, 10);

/// The language the pictures are in. Its flag is an SVG like every other, so
/// any language would draw.
const lang = 'en';

/// The words that are only a to z: a test keyboard cannot type an accent.
List<String> plain(List<String> words) => [
  for (final w in words)
    if (RegExp(r'^[a-z]+$').hasMatch(w)) w,
];

/// A game worth showing, from the word list: an answer, and two guesses that
/// each give some greens and some yellows without giving it away.
(String, String, String) demo(List<String> words) {
  final pool = plain(words);
  bool ok(String answer, String guess, int greens) {
    if (answer == guess) return false;
    final m = evaluate(answer, guess);
    return m.where((x) => x == Mark.correct).length == greens &&
        m.contains(Mark.present);
  }

  for (final a in pool.take(400)) {
    for (final g1 in pool.take(400)) {
      if (!ok(a, g1, 1)) continue;
      for (final g2 in pool.take(400)) {
        if (g2 != g1 && ok(a, g2, 2)) return (a, g1, g2);
      }
    }
  }
  throw StateError('no demonstration game in this list');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);
  tearDown(() {
    analyseWhilePlaying = false;
    dailyClock = DateTime.now;
  });

  Future<WordBank> english(WidgetTester t) async => (await t.runAsync(
    () async => WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == lang),
    ),
  ))!;

  /// A phone-sized window, and the app's state as the screenshots want it: a
  /// player a few weeks in, with a streak, a playstyle and some games.
  Future<WordBank> prepare(
    WidgetTester t, {
    GameMode mode = GameMode.classic,
  }) async {
    t.view.physicalSize = phone * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(
      lang: lang,
      length: 5,
      tries: 6,
      pool: 3000,
      mode: mode,
      helper: Helper.full,
      themeMode: ThemeMode.dark,
    );
    dailyClock = () => today;
    final bank = await english(t);

    // a week of dailies, with a streak running into it
    appState.dailyLog = {
      for (var d = 11; d <= 23; d++)
        '2026-10-$d': d == 14 || d == 20 || d == 23 ? dailyDouble : dailySolved,
    };
    appState.dailyBest = 12;

    // about forty weeks of play, a player getting sharper: skill climbs from the
    // low sixties to about ninety, daring wanders, luck is luck, and the odd
    // week is skipped, so the lines have gaps
    final rng = Random(3);
    final pool = bank.answers(5, 3000);
    final plays = <(DateTime, double)>[]; // when, and how far along (0 to 1)
    for (var week = 39; week >= 0; week--) {
      if (week > 3 && rng.nextInt(7) == 0) continue; // a week off
      for (var k = 0; k < 2 + rng.nextInt(4); k++) {
        plays.add((
          DateTime(
            2026,
            10,
            24,
            19,
            30,
          ).subtract(Duration(days: week * 7 + rng.nextInt(7), hours: k)),
          (39 - week) / 39,
        ));
      }
    }
    plays.sort((a, b) => a.$1.compareTo(b.$1));
    final h = History();
    for (final (i, (day, along)) in plays.indexed) {
      final guesses = [
        for (var k = 0; k < 3 + i % 3; k++) pool[rng.nextInt(400)],
      ];
      h.add(
        at: day.toUtc().millisecondsSinceEpoch,
        lang: lang,
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: [pool[rng.nextInt(400)]],
        won: i % 9 != 4,
        daily: i % 6 == 0 ? '2026-10-${(i % 20) + 1}' : '',
        guesses: [
          for (var k = 0; k < guesses.length; k++)
            GuessRow(
              game: 0,
              n: k,
              word: guesses[k],
              skill: (62 + 28 * along + rng.nextInt(14) - 7)
                  .clamp(0, 100)
                  .toDouble(),
              luck: rng.nextInt(100) - 50.0,
              daring: (30 + 25 * (1 - along) + rng.nextInt(24)).toDouble(),
              risk: .5,
              before: 600 ~/ (k + 1),
              after: 300 ~/ (k + 1),
            ),
        ],
      );
    }
    appState.history = h;
    appState.styleId = 'maverick';
    appState.stylesHeld = {'steady', 'analyst', 'maverick'};
    appState.styleChanges = 2;
    return bank;
  }

  /// Draws what is on screen, once its assets have been read, to a PNG.
  Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
    // the icons are SVG assets, read with real file IO
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = (await t.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final data = (await t.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    ))!;
    final file = File('../docs/screenshots/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(data.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${file.lengthSync()} bytes)');
  }

  Widget framed(GlobalKey key, Widget home) => RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.dark),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: home,
      onGenerateRoute: onGenerateRoute,
    ),
  );

  Future<void> type(WidgetTester t, String word) async {
    for (final ch in word.split('')) {
      await t.sendKeyEvent(
        ch == ' '
            ? LogicalKeyboardKey.space
            : LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
  }

  testWidgets('home', (t) async {
    await prepare(t);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: const LexodleApp()));
    await t.pumpAndSettle();
    await shot(t, key, 'home');
  }, skip: skip != null);

  testWidgets('a daily in play, with a blank pencilled in', (t) async {
    final bank = await prepare(t);
    analyseWhilePlaying = true;
    final key = GlobalKey();
    final (answer, first, second) = demo(bank.answers(5, 3000));
    final daily = Daily('2026-10-24', answer);
    await t.pumpWidget(framed(key, GamePage(bank: bank, daily: daily)));
    await t.pump();
    for (final w in [first, second]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    // the scoring of the guesses is worked out in the background
    await t.pump(const Duration(seconds: 20));
    // the answer, with the third letter not worked out yet
    await type(t, '${answer.substring(0, 2)} ${answer.substring(3)}');
    await t.pump();
    await shot(t, key, 'game');
  }, skip: skip != null);

  testWidgets('a quartet', (t) async {
    final bank = await prepare(t, mode: GameMode.quartet);
    final key = GlobalKey();
    await t.pumpWidget(
      framed(key, MultiGamePage(bank: bank, random: Random(11))),
    );
    await t.pump();
    final words = plain(bank.answers(5, 600));
    for (final w in [words[3], words[40], words[200]]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await shot(t, key, 'quartet');
  }, skip: skip != null);

  testWidgets('the review of a game', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    final (answer, first, second) = demo(bank.answers(5, 3000));
    final game = GameRow(
      id: 999,
      at: 0,
      lang: lang,
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: [answer],
      won: true,
    );
    final rows = [
      for (final (i, w) in [first, second, answer].indexed)
        GuessRow(game: 999, n: i, word: w),
    ];
    final record = replayClassic(bank, game, rows);
    await t.pumpWidget(framed(key, ReviewPage(record: record)));
    // each step is analysed after the last: let them all land
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(seconds: 10));
      if (find.text('working it out…').evaluate().isEmpty) break;
    }
    await shot(t, key, 'review');
  }, skip: skip != null);

  testWidgets('the history, with a playstyle', (t) async {
    await prepare(t);
    // taller than a phone, so the chart and the first games are both in it
    t.view.physicalSize = const Size(412, 1500) * 2;
    final key = GlobalKey();
    await t.pumpWidget(framed(key, const HistoryPage()));
    await t.pumpAndSettle();
    await shot(t, key, 'history');
  }, skip: skip != null);

  testWidgets('the settings', (t) async {
    await prepare(t);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const LexodleApp(initialRoute: Routes.settings),
      ),
    );
    await t.pumpAndSettle();
    await shot(t, key, 'settings');
  }, skip: skip != null);

  testWidgets('learn mode', (t) async {
    final bank = await prepare(t);
    analyseWhilePlaying = false;
    final key = GlobalKey();
    t.view.physicalSize = const Size(412, 1100) * 2;
    await t.pumpWidget(framed(key, LearnPage(bank: bank, seed: 4)));
    await t.pump();
    for (final w in plain(bank.answers(5, 600)).skip(7).take(1)) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await t.pump(const Duration(seconds: 20));
    await shot(t, key, 'learn');
  }, skip: skip != null);

  testWidgets('the solver', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    t.view.physicalSize = const Size(412, 1100) * 2;
    await t.pumpWidget(framed(key, SolverPage(bank: bank)));
    await t.pump(const Duration(seconds: 2));
    await type(t, 'crane');
    // the colours the other game showed: c grey, r yellow, a green, n, e grey
    final tiles = find.byType(MarkTile);
    for (final i in [1, 2, 2]) {
      await t.tap(tiles.at(i), warnIfMissed: false);
      await t.pump();
    }
    await t.tap(find.text('add guess'));
    await t.pump(const Duration(seconds: 20));
    await shot(t, key, 'solver');
  }, skip: skip != null);

  testWidgets('the achievements, with their flags', (t) async {
    await prepare(t);
    appState.setAch(lang, {
      'first_light': AchState(times: 1, dates: ['2026-09-02']),
      'one_shot': AchState(times: 2, dates: ['2026-09-20', '2026-10-11']),
      'wins_10': AchState(times: 1, dates: ['2026-09-30'], progress: 4),
      'streak_3': AchState(times: 3, dates: ['2026-10-01']),
      'daily_3': AchState(times: 1, dates: ['2026-10-05'], progress: 6),
      'bilingual': AchState(times: 1, dates: ['2026-10-02']),
    });
    appState.stats.langsWon = {'en', 'fr', 'de'};
    final key = GlobalKey();
    t.view.physicalSize = const Size(412, 1500) * 2;
    await t.pumpWidget(framed(key, const AchievementsPage()));
    await t.pump(const Duration(seconds: 1));
    await shot(t, key, 'achievements');
  }, skip: skip != null);
}
