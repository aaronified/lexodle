// The screenshots in the README, taken from the real screens rendered at phone
// size, in the app's own fonts and a dark theme, from seeded state, so they can
// be taken again whenever the interface changes. Not part of a normal run:
//
//   LEXODLE_SCREENSHOTS=1 flutter test test/screenshots_test.dart
//
// (PowerShell: $env:LEXODLE_SCREENSHOTS = 1.) The PNGs are written to
// docs/screenshots/ at the top of the repository. The player is a veteran, so
// every tab, mode and row is open; each game shows its timer at 1:23.
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
import 'package:lexodle/first_run/first_game_page.dart';
import 'package:lexodle/lex.dart' show LexEntry;
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/reminders.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/collection.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/learn_guide.dart' show ModeGuidePage;
import 'package:lexodle/game.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/home.dart' show LanguagePopup;
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/learn.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/replay.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ByteData> _bytes(String path) async =>
    ByteData.view((await File(path).readAsBytes()).buffer);

/// A phone, in logical pixels; the pictures are twice that.
const phone = Size(412, 860);

final skip = Platform.environment.containsKey('LEXODLE_SCREENSHOTS')
    ? null
    : 'set LEXODLE_SCREENSHOTS=1 to take the README screenshots';

/// The day the screenshots are of (a Saturday), so the week is the same each time.
final today = DateTime(2026, 10, 24, 10);

/// The clock of every game's timer, so a game shows the same time each run:
/// [played] moves it to 1:23 after the first key.
Duration _now = Duration.zero;
Duration clock() => _now;

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

  setUpAll(() async {
    // the app's font, and the Flutter SDK's full icon font (the tests' own is cut
    // down to a few icons, and the tab bar draws others)
    await (FontLoader('JetBrainsMono')
          ..addFont(_bytes('assets/fonts/JetBrainsMono-Regular.ttf'))
          ..addFont(_bytes('assets/fonts/JetBrainsMono-Bold.ttf')))
        .load();
    final root =
        Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.path;
    final full = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    await (FontLoader('MaterialIcons')..addFont(
          full.existsSync()
              ? _bytes(full.path)
              : _bytes('test/fonts/MaterialIcons-Regular.otf'),
        ))
        .load();
  });
  tearDown(() {
    analyseWhilePlaying = false;
    dailyClock = DateTime.now;
  });

  Future<WordBank> english(WidgetTester t, [String code = lang]) async =>
      (await t.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == code),
        ),
      ))!;

  /// The screen down to the keyboard, which is left out of the pictures that
  /// are not about it: the top of the keyboard is where the picture ends.
  Rect aboveKeyboard(WidgetTester t) =>
      Rect.fromLTRB(0, 0, 412, t.getRect(find.byType(LetterKeyboard)).top);

  /// A phone-sized window, and the app's state as the screenshots want it: a
  /// player a few weeks in, with a streak, a playstyle and some games.
  Future<WordBank> prepare(
    WidgetTester t, {
    GameMode mode = GameMode.classic,
    String language = lang,
  }) async {
    t.view.physicalSize = phone * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    _now = Duration.zero;
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(
      lang: language,
      length: 5,
      tries: 6,
      mode: mode,
      helper: Helper.full,
      themeMode: ThemeMode.dark,
    );
    dailyClock = () => today;
    final bank = await english(t, language);

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
    final pool = bank.answers(5);
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
        lang: language,
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: [pool[rng.nextInt(400)]],
        won: i % 9 != 4,
        daily: i % 6 == 0 ? '2026-10-${(i % 20) + 1}' : '',
        ms: 45000 + rng.nextInt(240000),
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
              risk: (3 + 9 * (1 - along) + rng.nextInt(7)).toDouble(),
              gain: .5,
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
    appState.setAch(language, {
      'wins': AchState(times: 1, dates: ['2026-09-02'], value: 12),
      'quick': AchState(
        times: 3,
        dates: ['2026-09-20', '2026-10-11', '2026-10-18'],
        value: 2,
      ),
      'last_try': AchState(times: 1, dates: ['2026-10-03'], value: 1),
      'dailies': AchState(times: 1, dates: ['2026-09-30'], progress: 4),
      'played': AchState(
        times: 2,
        dates: ['2026-09-10', '2026-10-01'],
        value: 113,
      ),
      'daily_streak': AchState(times: 1, dates: ['2026-10-05'], progress: 6),
      'languages': AchState(times: 1, dates: ['2026-10-02']),
    });
    appState.stats.langsWon = {'en', 'fr', 'de'};
    // a veteran: lex is shown from the start, with a balance and free hints
    appState.stats.played = 113;
    for (final m in [GameMode.quartet, GameMode.lockdown, GameMode.blind]) {
      appState.myDailies.add(language, m);
    }
    appState.lex
      ..activated = true
      ..veteran = true
      ..balance = 184
      ..freeHints = 2;
    final at = today.millisecondsSinceEpoch;
    appState.lex.ledger.addAll([
      LexEntry(at - 40 * 864e5.round(), 120, 'grant'),
      LexEntry(at - 26 * 864e5.round(), 3, 'earn:quick:2', language),
      LexEntry(at - 18 * 864e5.round(), 2, 'earn:played:1', language),
      LexEntry(at - 9 * 864e5.round(), 5, 'earn:quick:3', language),
      LexEntry(at - 5 * 864e5.round(), -10, 'hint:grey', language),
      LexEntry(at - 2 * 864e5.round(), 4, 'earn:wins:1', language),
      LexEntry(at - 864e5.round(), -20, 'hint:green', language),
    ]);
    return bank;
  }

  /// Draws what is on screen, once its assets have been read, to a PNG.
  ///
  /// With [crop], a rectangle of the screen in logical pixels, only that part:
  /// the pictures of the README's feature list show the feature, not the page.
  Future<void> shot(
    WidgetTester t,
    GlobalKey key,
    String name, {
    Rect? crop,
  }) async {
    // the icons are SVG assets, read with real file IO
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    var image = (await t.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    if (crop != null) {
      final r = Rect.fromLTRB(
        crop.left * 2,
        crop.top * 2,
        min(crop.right * 2, image.width.toDouble()),
        min(crop.bottom * 2, image.height.toDouble()),
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        r,
        Rect.fromLTWH(0, 0, r.width, r.height),
        ui.Paint(),
      );
      image = await recorder.endRecording().toImage(
        r.width.round(),
        r.height.round(),
      );
    }
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

  /// The game has been played for 1:23: its timer pill reads it.
  Future<void> played(WidgetTester t) async {
    _now = const Duration(seconds: 83);
    await t.pump(const Duration(seconds: 1));
  }

  /// The dailies as they stand on the day: classic solved, the quartet half
  /// played, lockdown missed and blind not started, each with a streak but the
  /// lost one.
  void seedToday() {
    for (final m in [GameMode.quartet, GameMode.blind]) {
      for (var d = 18; d <= 23; d++) {
        appState.recordDaily('2026-10-$d', dailySolved, lang: lang, mode: m);
      }
    }
    appState.recordDaily('2026-10-24', dailySolved);
    appState.recordDaily(
      '2026-10-24',
      dailyMissed,
      lang: lang,
      mode: GameMode.lockdown,
    );
    appState.saveDaily(lang, '2026-10-24', [
      'crane',
      'sloth',
    ], mode: GameMode.quartet);
  }

  /// The shell, on the tab [tab] (today when null).
  Future<GlobalKey> shell(WidgetTester t, [String? tab]) async {
    // the tests' config starts on the old home page; the app is always the shell
    appState.newUi = true;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: const LexodleApp()));
    await t.pumpAndSettle();
    if (tab != null) {
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('tabs')),
          matching: find.text(tab),
        ),
      );
      await t.pumpAndSettle();
    }
    return key;
  }

  testWidgets('the today tab', (t) async {
    await prepare(t);
    seedToday();
    final key = await shell(t);
    await shot(t, key, 'today');
  }, skip: skip != null);

  testWidgets('the you tab', (t) async {
    await prepare(t);
    seedToday();
    t.view.physicalSize = const Size(412, 1000) * 2;
    final key = await shell(t, 'you');
    await shot(t, key, 'you');
  }, skip: skip != null);

  testWidgets('the words tab', (t) async {
    final bank = await prepare(t);
    final won = plain(bank.answers(5)).take(260).toList();
    appState.collection = Collection();
    for (final w in won.skip(20).take(137)) {
      appState.collection.addWord(lang, w);
    }
    appState.savedWords = SavedWords();
    for (final (i, w) in won.take(12).indexed) {
      appState.savedWords.add(
        SavedWord(
          lang: lang,
          word: w,
          date: '2026-10-${10 + i % 14}',
          note: i % 4 == 0 ? 'one to remember' : '',
        ),
      );
    }
    final key = await shell(t, 'words');
    await shot(t, key, 'words');
  }, skip: skip != null);

  testWidgets('a daily in play, with a blank pencilled in', (t) async {
    final bank = await prepare(t);
    analyseWhilePlaying = true;
    final key = GlobalKey();
    final (answer, first, second) = demo(bank.answers(5));
    final daily = Daily('2026-10-24', answer);
    await t.pumpWidget(
      framed(key, GamePage(bank: bank, daily: daily, clock: clock)),
    );
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
    await played(t);
    await shot(t, key, 'game');
    // the feature list shows the board, not the keyboard
    await shot(t, key, 'features/game', crop: aboveKeyboard(t));
  }, skip: skip != null);

  testWidgets('a quartet', (t) async {
    final bank = await prepare(t, mode: GameMode.quartet, language: 'fr');
    final key = GlobalKey();
    await t.pumpWidget(
      framed(key, MultiGamePage(bank: bank, random: Random(11), clock: clock)),
    );
    await t.pump();
    final words = plain(bank.answers(5));
    for (final w in [words[3], words[40], words[200]]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await played(t);
    await shot(t, key, 'quartet');
    await shot(t, key, 'features/quartet', crop: aboveKeyboard(t));
  }, skip: skip != null);

  testWidgets('a lockdown game', (t) async {
    final bank = await prepare(t, mode: GameMode.lockdown, language: 'de');
    appState.setup(hearts: 5);
    final key = GlobalKey();
    await t.pumpWidget(
      framed(
        key,
        GamePage(
          bank: bank,
          random: Random(11),
          mode: GameMode.lockdown,
          clock: clock,
        ),
      ),
    );
    await t.pump();
    final words = plain(bank.answers(5));
    final answer = chooseWord(
      bank.answers(5),
      bank.drawWeights(5, appState.draw),
      Random(11),
    );
    Set<int> greens(String w) => {
      for (var i = 0; i < 5; i++)
        if (evaluate(answer, w)[i] == Mark.correct) i,
    };
    final locked = <int>{};
    // a guess types only the open slots: the greens are locked in already
    Future<void> guess(String w) async {
      await type(
        t,
        [
          for (var i = 0; i < 5; i++)
            if (!locked.contains(i)) w[i],
        ].join(),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      locked.addAll(greens(w));
    }

    String next(int atLeast) => words.firstWhere(
      (w) =>
          w != answer &&
          locked.every((i) => w[i] == answer[i]) &&
          greens(w).length >= atLeast &&
          greens(w).length < 5 &&
          evaluate(answer, w).contains(Mark.present),
    );
    await guess(next(1));
    await guess(next(locked.length + 1));
    // two words that are not in the list: two hearts break
    for (var k = 0; k < 2; k++) {
      await type(t, 'q' * (5 - locked.length));
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      // (an animation starts on the frame after it is asked for)
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      for (var i = locked.length; i < 5; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      }
      await t.pump();
    }
    await played(t);
    await shot(t, key, 'lockdown', crop: aboveKeyboard(t));
  }, skip: skip != null);

  testWidgets('the review of a game', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    final (answer, first, second) = demo(bank.answers(5));
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
      draw: Draw.sigmoid, // how a game is drawn by default
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
    // classic, whose playstyle is the one held
    await t.tap(find.text('classic').first);
    await t.pumpAndSettle();
    await shot(t, key, 'history');
    // the games of the list, each with its link button
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('game-'),
    );
    final first = t.getRect(tiles.first);
    final fourth = t.getRect(tiles.at(3));
    await shot(
      t,
      key,
      'features/share-history',
      crop: Rect.fromLTRB(0, first.top - 6, 412, fourth.bottom + 6),
    );
    // the chart with the overall numbers, and the playstyle on its own (it has
    // a page of its own now, no longer a card of the history)
    Rect card(String k) => t.getRect(find.byKey(ValueKey(k)));
    await shot(
      t,
      key,
      'features/history',
      crop: Rect.fromLTRB(
        0,
        card('overall').top - 12,
        412,
        t.getRect(find.byKey(const ValueKey('playstyle-row'))).bottom + 14,
      ),
    );
    final style = GlobalKey();
    await t.pumpWidget(
      framed(
        style,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [PlaystyleCard(lang)],
          ),
        ),
      ),
    );
    await t.pump();
    await shot(
      t,
      style,
      'features/playstyle',
      crop: Rect.fromLTRB(
        0,
        0,
        412,
        t.getRect(find.byKey(const ValueKey('profile'))).bottom + 24,
      ),
    );
  }, skip: skip != null);

  testWidgets('the settings, from the theme down', (t) async {
    await prepare(t);
    t.view.physicalSize = const Size(412, 2000) * 2;
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
    for (final w in plain(bank.answers(5)).skip(7).take(1)) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await t.pump(const Duration(seconds: 20));
    await shot(t, key, 'learn', crop: aboveKeyboard(t));
    await shot(
      t,
      key,
      'features/learn',
      crop: Rect.fromLTRB(
        0,
        0,
        412,
        t.getTopLeft(find.byKey(const ValueKey('learn-words'))).dy + 150,
      ),
    );
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
    await shot(t, key, 'solver', crop: aboveKeyboard(t));
    await shot(
      t,
      key,
      'features/solver',
      crop: Rect.fromLTRB(
        0,
        0,
        412,
        t.getRect(find.text('recommended guess')).bottom + 70,
      ),
    );
  }, skip: skip != null);

  testWidgets('the achievements, with their flags', (t) async {
    await prepare(t);
    final key = GlobalKey();
    t.view.physicalSize = const Size(412, 1500) * 2;
    await t.pumpWidget(framed(key, const AchievementsPage()));
    await t.pump(const Duration(seconds: 1));
    await shot(t, key, 'achievements');
    // just the first three, as the feature list shows
    await shot(
      t,
      key,
      'features/achievements',
      crop: Rect.fromLTRB(
        0,
        0,
        412,
        t.getRect(find.byKey(const ValueKey('quick-row'))).bottom + 10,
      ),
    );
    // the lex chip opens what lex is earned from
    await t.tap(find.byKey(const ValueKey('lex-chip')));
    await t.pumpAndSettle();
    await shot(
      t,
      key,
      'lex-dropdown',
      crop: Rect.fromLTRB(
        0,
        0,
        412,
        t.getRect(find.byKey(const ValueKey('lex-drop'))).bottom + 24,
      ),
    );
  }, skip: skip != null);

  testWidgets('a blind game, in Indonesian, with a guess pencilled', (t) async {
    final bank = await prepare(t, mode: GameMode.blind, language: 'id');
    appState.setup(blindTries: 10);
    final words = plain(bank.answers(5));
    final answer = words[40];
    final guesses = [words[5], words[90], words[230]];
    final key = GlobalKey();
    await t.pumpWidget(
      framed(
        key,
        GamePage(
          bank: bank,
          mode: GameMode.blind,
          practice: true,
          clock: clock,
          daily: Daily('', answer, length: 5, tries: 10),
        ),
      ),
    );
    await t.pump();
    for (final w in guesses) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    // pencil the second guess as its counts allow: a tap is green, two are
    // yellow, three are grey
    final marks = evaluate(answer, guesses[1]);
    for (var i = 0; i < 5; i++) {
      final taps = switch (marks[i]) {
        Mark.correct => 1,
        Mark.present => 2,
        Mark.absent => 3,
      };
      for (var k = 0; k < taps; k++) {
        await t.tap(find.byKey(ValueKey('tile-1-$i')));
        await t.pump();
      }
    }
    await type(t, words[300].substring(0, 2));
    await played(t);
    await shot(t, key, 'blind', crop: aboveKeyboard(t));
  }, skip: skip != null);

  testWidgets('a themed game: places, with info dots', (t) async {
    await prepare(t, mode: GameMode.themed);
    final places = (await t.runAsync(() async {
      final en = (await WordBank.languages()).firstWhere((l) => l.code == 'en');
      return Geography.load(en);
    }))!;
    final key = GlobalKey();
    await t.pumpWidget(
      framed(
        key,
        GamePage(
          bank: places,
          mode: GameMode.themed,
          practice: true,
          clock: clock,
          daily: Daily('', 'egypt', length: 5, tries: 6),
        ),
      ),
    );
    await t.pump();
    for (final w in ['spain', 'italy', 'nepal']) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await type(t, 'trick');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await played(t);
    await shot(t, key, 'themed', crop: aboveKeyboard(t));
  }, skip: skip != null);

  testWidgets('the choose dailies sheet, every mode open', (t) async {
    await prepare(t);
    seedToday();
    t.view.physicalSize = const Size(412, 1100) * 2;
    final key = await shell(t);
    await t.tap(find.byKey(const ValueKey('today-choose')));
    await t.pumpAndSettle();
    expect(find.byType(Switch), findsWidgets);
    await shot(t, key, 'choose-dailies');
  }, skip: skip != null);

  testWidgets('the learn tab', (t) async {
    await prepare(t);
    t.view.physicalSize = const Size(412, 1400) * 2;
    final key = await shell(t, 'learn');
    await shot(t, key, 'learn-tab');
  }, skip: skip != null);

  testWidgets('how to play it well, the guide of learn', (t) async {
    await prepare(t);
    t.view.physicalSize = const Size(412, 1000) * 2;
    final key = GlobalKey();
    await t.pumpWidget(
      framed(key, const ModeGuidePage(mode: GameMode.classic)),
    );
    await t.pump();
    await shot(t, key, 'learn-guide');
  }, skip: skip != null);

  testWidgets('the language list', (t) async {
    await prepare(t);
    final langs = (await t.runAsync(WordBank.languages))!;
    final key = GlobalKey();
    await t.pumpWidget(
      framed(
        key,
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: LanguagePopup(langs: langs, current: 'hu'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    final box = t.getRect(
      find
          .descendant(
            of: find.byType(LanguagePopup),
            matching: find.byType(Material),
          )
          .first,
    );
    await shot(
      t,
      key,
      'features/languages',
      crop: Rect.fromLTRB(0, box.top - 6, 412, box.bottom + 6),
    );
  }, skip: skip != null);

  testWidgets('sharing a game: the link button and its menu', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    t.view.physicalSize = const Size(412, 700) * 2;
    await t.pumpWidget(
      framed(key, GamePage(bank: bank, random: Random(5), clock: clock)),
    );
    await t.pump();
    final words = plain(bank.answers(5));
    for (final w in [words[8], words[120]]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await t.tap(find.byKey(const ValueKey('share-puzzle')));
    await t.pumpAndSettle();
    await shot(
      t,
      key,
      'features/share',
      crop: const Rect.fromLTRB(0, 0, 412, 330),
    );
  }, skip: skip != null);

  testWidgets('a game with the hint tray open', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    await t.pumpWidget(
      framed(key, GamePage(bank: bank, random: Random(5), clock: clock)),
    );
    await t.pump();
    final words = plain(bank.answers(5));
    for (final w in [words[8], words[120]]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
    }
    await played(t);
    await t.tap(find.byType(HintBar));
    await t.pumpAndSettle();
    await shot(t, key, 'hints');
  }, skip: skip != null);

  testWidgets('the first game, mid-play', (t) async {
    final bank = await prepare(t);
    final key = GlobalKey();
    await t.pumpWidget(
      framed(key, FirstGamePage(onDone: () {}, onClose: () {})),
    );
    await t.pump();
    await t.pump();
    final words = plain(bank.guessable(5));
    for (final w in [words[30], words[400]]) {
      await type(t, w);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      await t.pump(const Duration(seconds: 2));
    }
    if (find.text('got it').evaluate().isNotEmpty) {
      await t.tap(find.text('got it'));
      await t.pump();
    }
    await type(t, words[900].substring(0, 3));
    await t.pump();
    await shot(t, key, 'first-game');
  }, skip: skip != null);

  testWidgets('the mode settings', (t) async {
    await prepare(t);
    t.view.physicalSize = const Size(412, 1300) * 2;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const LexodleApp(initialRoute: Routes.modeSettings),
      ),
    );
    await t.pumpAndSettle();
    await shot(t, key, 'mode-settings');
  }, skip: skip != null);

  testWidgets('the reminders', (t) async {
    await prepare(t);
    Reminders.scheduler = _Phone();
    addTearDown(() => Reminders.scheduler = const NoopScheduler());
    appState.setReminders(
      const ReminderSettings(
        on: true,
        available: true,
        reminders: [
          ReminderTime(),
          ReminderTime(minutes: 20 * 60 + 30),
        ],
      ),
    );
    t.view.physicalSize = const Size(412, 1000) * 2;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const LexodleApp(initialRoute: Routes.reminders),
      ),
    );
    await t.pumpAndSettle();
    await shot(t, key, 'reminders');
  }, skip: skip != null);
}

/// A phone that can schedule notifications, so the reminders page is shown on.
class _Phone implements NotificationScheduler {
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> replaceAll(List<PlannedNudge> plan) async {}
}
