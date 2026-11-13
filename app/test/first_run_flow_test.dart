import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/app_shell.dart';
import 'package:lexodle/first_run/first_run_flow.dart';
import 'package:lexodle/first_run/first_run_state.dart';
import 'package:lexodle/first_run/language_theme_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _fake(String name, Map<String, VoidCallback> buttons) => Scaffold(
  body: Column(
    children: [
      Text(name),
      for (final e in buttons.entries)
        TextButton(onPressed: e.value, child: Text('${name}_${e.key}')),
    ],
  ),
);

FirstRunScreens _screens([List<String>? log]) => FirstRunScreens(
  language: (start, skip) => _fake('language', {'start': start, 'skip': skip}),
  game: (done, close, practice) =>
      _fake(practice ? 'practice' : 'game', {'done': done, 'close': close}),
  gateway: (okay, replay) => _fake('gateway', {'okay': okay, 'replay': replay}),
  offer: (learn, notNow) => _fake('offer', {'learn': learn, 'notnow': notNow}),
  tour: (learn, done) =>
      _fake('tour', {'learn': () => learn(GameMode.quartet), 'done': done}),
  lesson: (mode, done) {
    log?.add(mode.name);
    return _fake('lesson', {'done': done});
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> fresh([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true, ...prefs});
    appState.stats.played = 0;
    appState.lex.veteran = false;
    await appState.load();
    appState.stats.played = 0;
    appState.lex.veteran = false;
    appState.newUi = true;
    FirstRunSignals.chooseDailiesPending = false;
  }

  Future<void> show(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  tearDown(() => appState.newUi = false);

  testWidgets('a new player lands on the language page', (tester) async {
    await fresh();
    await show(
      tester,
      HomeSwitch(screens: FirstRunScreens(game: _screens().game)),
    );
    expect(find.byType(LanguageThemePage), findsOneWidget);
    expect(find.text('start playing'), findsOneWidget);
    expect(find.text('i know how lexodle works'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('the order: game, gateway, offer, tour, gateway, today', (
    tester,
  ) async {
    await fresh();
    final seen = <String>[];
    await show(tester, HomeSwitch(screens: _screens(seen)));
    expect(find.text('language'), findsOneWidget);
    await tap(tester, 'language_start');
    expect(find.text('game'), findsOneWidget);
    await tap(tester, 'game_done');
    expect(appState.firstRunStage, 1);
    expect(find.text('gateway'), findsOneWidget);
    await tap(tester, 'gateway_okay');
    expect(find.text('offer'), findsOneWidget);
    await tap(tester, 'offer_learn');
    expect(find.text('tour'), findsOneWidget);
    await tap(tester, 'tour_learn');
    expect(find.text('lesson'), findsOneWidget);
    await tap(tester, 'lesson_done');
    expect(find.text('tour'), findsOneWidget);
    expect(seen, ['quartet']);
    await tap(tester, 'tour_done');
    expect(find.text('gateway'), findsOneWidget);
    expect(appState.firstRunDone, isFalse);
    await tap(tester, 'gateway_okay');
    expect(appState.firstRunDone, isTrue);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('closing the game and not now both end on the gateway', (
    tester,
  ) async {
    await fresh();
    await show(tester, HomeSwitch(screens: _screens()));
    await tap(tester, 'language_start');
    await tap(tester, 'game_close');
    expect(find.text('gateway'), findsOneWidget);
    await tap(tester, 'gateway_okay');
    await tap(tester, 'offer_notnow');
    expect(find.text('gateway'), findsOneWidget);
    await tap(tester, 'gateway_okay');
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('i know how lexodle works skips to today, dailies sheet once', (
    tester,
  ) async {
    await fresh();
    await show(tester, HomeSwitch(screens: _screens()));
    await tap(tester, 'language_skip');
    expect(appState.firstRunDone, isTrue);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('game'), findsNothing);
    expect(find.text('choose your dailies'), findsWidgets);
    expect(FirstRunSignals.chooseDailiesPending, isFalse);
  });

  testWidgets('a veteran never sees the first run', (tester) async {
    await fresh();
    appState.stats.played = 3;
    await show(tester, HomeSwitch(screens: _screens()));
    expect(find.text('language'), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);

    await fresh();
    appState.lex.veteran = true;
    await show(tester, HomeSwitch(screens: _screens()));
    expect(find.text('language'), findsNothing);
  });

  test('the stage is read from storage, and finishing saves it', () async {
    SharedPreferences.setMockInitialValues({'firstRunStage': 1});
    await appState.load();
    expect(appState.firstRunStage, 1);
    expect(appState.firstRunDone, isFalse);
    appState.setFirstRunStage(2);
    expect(appState.firstRunDone, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('firstRunStage'), 2);
  });

  testWidgets('the stage is kept: a half-done first run resumes', (
    tester,
  ) async {
    await fresh();
    await show(tester, HomeSwitch(screens: _screens()));
    await tap(tester, 'language_start');
    await tap(tester, 'game_done');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('firstRunStage'), 1);
    // a new start: the game is not played again
    await appState.load();
    await show(tester, const SizedBox());
    await show(tester, HomeSwitch(screens: _screens()));
    expect(find.text('gateway'), findsOneWidget);
    expect(find.text('game'), findsNothing);
  });

  testWidgets('practice replay from you returns to you', (tester) async {
    await fresh({'firstRunStage': 2});
    appState.newUi = true;
    await show(tester, AppShell(screens: _screens()));
    await tap(tester, 'you');
    expect(find.byType(YouPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('you-help')));
    await tester.pumpAndSettle();
    expect(find.text('practice'), findsOneWidget);
    await tap(tester, 'practice_done');
    expect(find.byType(YouPage), findsOneWidget);
    expect(find.text('practice'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('you-help')));
    await tester.pumpAndSettle();
    await tap(tester, 'practice_close');
    expect(find.byType(YouPage), findsOneWidget);
  });

  testWidgets('the language page lists languages and sets the theme', (
    tester,
  ) async {
    await fresh();
    final langs = [
      for (final (c, n) in [
        ('en', 'English'),
        ('es', 'Español'),
        ('fr', 'Français'),
        ('de', 'Deutsch'),
      ])
        Language(c, n, n, const [5]),
    ];
    var started = false;
    await show(
      tester,
      LanguageThemePage(
        onStart: () => started = true,
        onSkip: () {},
        languages: Future.value(langs),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('english'), findsOneWidget);
    expect(find.text('deutsch'), findsNothing);
    await tap(tester, '1 more languages');
    await tap(tester, 'deutsch');
    expect(appState.lang, 'de');
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pump();
    expect(appState.themeMode, ThemeMode.dark);
    await tap(tester, 'start playing');
    expect(started, isTrue);
    appState.setup(lang: 'en', themeMode: ThemeMode.light);
  });
}
