import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game_modes_dialog.dart';
import 'package:lexodle/first_run/mode_lesson_page.dart';
import 'package:lexodle/ladder.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_strip.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/my_dailies.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/today_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String today;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', mode: GameMode.classic);
    today = dailyDate();
    // appState is global: start each test with nothing chosen, logged or saved
    appState.myDailies = MyDailies();
    appState.daily.clear();
    appState.introCardsDone.clear();
    appState.modesTaught.clear();
    appState.lex.veteran = false;
    for (final m in GameMode.values) {
      appState.dailyLogOf('en', m).clear();
    }
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TodayPage())),
    );
    await tester.pump();
  }

  Finder row(GameMode m) => find.byKey(ValueKey('today-row-${m.name}'));

  /// The card steps before [name] are handled, so [name] is the one shown.
  void handledBefore(String name) {
    for (final s in ladder) {
      if (s.name == name) break;
      appState.introCardsDone.add(s.name);
    }
  }

  Finder anyCard() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey &&
        ((w.key as ValueKey).value as Object).toString().startsWith(
          'today-new-',
        ),
  );

  void veteran() {
    appState.stats.played = 50;
    appState.lex.veteran = true;
    for (final m in [GameMode.quartet, GameMode.relay, GameMode.lockdown]) {
      appState.chooseDaily('en', m, on: true);
    }
    appState.recordDaily(today, dailySolved);
    appState.recordDaily(today, dailyMissed, mode: GameMode.relay);
    appState.saveDaily('en', today, ['crane'], mode: GameMode.lockdown);
  }

  testWidgets('counts the dailies solved today, a lost one is not done', (
    tester,
  ) async {
    veteran();
    await show(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('today-count'))).data,
      '1 of 4',
    );
    expect(find.text('dailies done today'), findsOneWidget);
  });

  testWidgets('in progress first, then not started, then done or lost', (
    tester,
  ) async {
    veteran();
    await show(tester);
    final y = [
      for (final m in [
        GameMode.lockdown,
        GameMode.quartet,
        GameMode.classic,
        GameMode.relay,
      ])
        tester.getTopLeft(row(m)).dy,
    ];
    expect(y, [...y]..sort());
    expect(find.text('1 of 6 tries used'), findsOneWidget);
    expect(find.text('not started'), findsOneWidget);
    expect(find.textContaining('continue'), findsWidgets);
  });

  testWidgets('a lost row says missed and that the streak ended', (
    tester,
  ) async {
    veteran();
    await show(tester);
    expect(find.text('missed'), findsOneWidget);
    expect(find.text(' · streak ended'), findsOneWidget);
  });

  testWidgets('the free play strip fits a narrow phone', (tester) async {
    veteran();
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TodayPage())),
    );
    await tester.pump();
    final strip = find.byKey(const ValueKey('mode-strip'));
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip).width, lessThanOrEqualTo(360));
    expect(find.text('free play'), findsOneWidget);
    expect(find.text('classic'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar is pinned with a solid background and a next button', (
    tester,
  ) async {
    veteran();
    await show(tester);
    final bar = find.byKey(const ValueKey('today-bar'));
    expect(tester.getBottomLeft(bar).dy, 1400);
    final box = tester.widget<Container>(bar).decoration! as BoxDecoration;
    expect(box.color, isNotNull);
    expect(box.color!.a, 1);
    expect(find.byKey(const ValueKey('today-free-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-primary')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-free-play')),
        matching: find.text('free play'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('when all are done the bar is a quiet line and free play', (
    tester,
  ) async {
    appState.recordDaily(today, dailySolved);
    await show(tester);
    expect(find.byKey(const ValueKey('today-all-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-primary')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-free-play')),
        matching: find.text('free play'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new player gets the new card and no next-up card', (
    tester,
  ) async {
    appState.stats.played = 4;
    appState.lex.veteran = false;
    handledBefore('quartet');
    await show(tester);
    expect(find.byKey(const ValueKey('today-new-quartet')), findsOneWidget);
    expect(find.text('four words at once'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-next-up')), findsNothing);
    expect(find.text('your numbers'), findsNothing);
    expect(find.byKey(const ValueKey('today-next-bar')), findsNothing);
    // at most one introduction card
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            ((w.key as ValueKey).value as Object).toString().startsWith(
              'today-new-',
            ),
      ),
      findsOneWidget,
    );
    // quartet is open at 4, so the choice is there
    expect(find.byKey(const ValueKey('today-choose')), findsOneWidget);
  });

  testWidgets('the new mode card offers its lesson; a taught mode skips it', (
    tester,
  ) async {
    appState.stats.played = 4;
    appState.lex.veteran = false;
    appState.modesTaught.clear();
    handledBefore('quartet');
    await show(tester);
    expect(find.text('how it works ›'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-new-quartet')));
    await tester.pumpAndSettle();
    expect(find.byType(ModeLessonPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-close')));
    await tester.pumpAndSettle();
    expect(find.byType(ModeLessonPage), findsNothing);
    // backed out: the card stays
    expect(find.byKey(const ValueKey('today-new-quartet')), findsOneWidget);
    expect(appState.introCardsDone, isNot(contains('quartet')));
    appState.markTaught(GameMode.quartet);
    await tester.pump();
    expect(find.byKey(const ValueKey('today-new-quartet')), findsNothing);
    appState.modesTaught.clear();
  });

  testWidgets('the choice is hidden until quartet opens', (tester) async {
    appState.stats.played = 2;
    appState.lex.veteran = false;
    await show(tester);
    expect(find.byKey(const ValueKey('today-choose')), findsNothing);
    expect(find.byKey(const ValueKey('today-more')), findsNothing);
  });

  /// The route arguments of what was pushed, by route name.
  final arguments = <String, Object?>{};

  Future<List<String>> showRouted(WidgetTester tester) async {
    final pushed = <String>[];
    arguments.clear();
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: TodayPage()),
        onGenerateRoute: (r) {
          pushed.add(r.name ?? '');
          arguments[r.name ?? ''] = r.arguments;
          return MaterialPageRoute<void>(
            settings: r,
            builder: (_) => const Scaffold(body: Text('elsewhere')),
          );
        },
      ),
    );
    await tester.pump();
    return pushed;
  }

  testWidgets('a feature card opens its page and is handled for good', (
    tester,
  ) async {
    appState.stats.played = 3;
    appState.lex.veteran = false;
    handledBefore('achievements');
    final pushed = await showRouted(tester);
    final card = find.byKey(const ValueKey('today-new-achievements'));
    expect(card, findsOneWidget);
    expect(find.text('see them ›'), findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.achievements));
    expect(appState.introCardsDone, contains('achievements'));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(card, findsNothing);
  });

  testWidgets('each feature card goes to its page', (tester) async {
    final want = {5: Routes.history, 9: Routes.words, 24: Routes.learn};
    for (final e in want.entries) {
      await tester.pumpWidget(const SizedBox());
      appState.introCardsDone.clear();
      appState.stats.played = e.key;
      appState.lex.veteran = false;
      handledBefore(switch (e.key) {
        5 => 'your numbers',
        9 => 'my words',
        _ => 'learn',
      });
      appState.modesTaught.addAll(GameMode.values);
      final pushed = await showRouted(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              ((w.key as ValueKey).value as Object).toString().startsWith(
                'today-new-',
              ),
        ),
      );
      await tester.pumpAndSettle();
      expect(pushed, contains(e.value), reason: 'game ${e.key}');
    }
    appState.modesTaught.clear();
  });

  testWidgets('free play starts a free game of the mode in view', (
    tester,
  ) async {
    veteran();
    appState.setup(mode: GameMode.quartet);
    final pushed = await showRouted(tester);
    await tester.tap(find.byKey(const ValueKey('today-free-play')));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.play));
    expect(pushed, isNot(contains(Routes.gameModes)));
    expect(find.byType(GameModesDialog), findsNothing);
    expect(appState.mode, GameMode.quartet);
  });

  testWidgets('one open mode: just the rectangle, a tap starts its free play', (
    tester,
  ) async {
    appState.stats.played = 0;
    appState.lex.veteran = false;
    final pushed = await showRouted(tester);
    expect(find.byKey(const ValueKey('mode-strip-box')), findsOneWidget);
    expect(find.text('free play'), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-prev')), findsNothing);
    expect(find.byKey(const ValueKey('mode-next')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('today-free-play')));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.play));
    expect(appState.mode, GameMode.classic);
  });

  testWidgets('several open modes: the strip changes the free play mode', (
    tester,
  ) async {
    veteran();
    final pushed = await showRouted(tester);
    expect(find.byType(ModeStrip), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-prev')), findsNothing);
    // a tap on a neighbour selects it
    await tester.tap(find.byKey(const ValueKey('mode-strip-quartet')));
    await tester.pumpAndSettle();
    expect(appState.mode, GameMode.quartet);
    // a drag turns it too
    await tester.drag(
      find.byKey(const ValueKey('mode-strip')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(appState.mode, isNot(GameMode.quartet));
    final now = appState.mode;
    expect(pushed, isNot(contains(Routes.play)));
    // free play starts the mode the strip shows
    await tester.tap(find.byKey(const ValueKey('today-free-play')));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.play));
    expect(appState.mode, now);
  });

  testWidgets('a daily row opens its own daily and leaves the free play mode', (
    tester,
  ) async {
    veteran();
    appState.setup(mode: GameMode.quartet);
    final pushed = await showRouted(tester);
    await tester.tap(row(GameMode.lockdown));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.daily));
    expect(arguments[Routes.daily], GameMode.lockdown);
    expect(appState.mode, GameMode.quartet);
  });

  testWidgets('a finished daily opens its game, with no placeholder', (
    tester,
  ) async {
    veteran();
    final pushed = await showRouted(tester);
    await tester.tap(row(GameMode.relay));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.daily));
    expect(find.textContaining('remain as they are'), findsNothing);
  });

  testWidgets('a daily row still starts the daily', (tester) async {
    veteran();
    final pushed = await showRouted(tester);
    await tester.tap(row(GameMode.lockdown));
    await tester.pumpAndSettle();
    expect(pushed, contains(Routes.daily));
  });

  testWidgets('the every mode card opens the sheet and is handled', (
    tester,
  ) async {
    appState.stats.played = 6;
    appState.lex.veteran = false;
    handledBefore('every mode');
    appState.modesTaught.add(GameMode.quartet);
    await showRouted(tester);
    expect(find.text('got it ›'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-new-every mode')));
    await tester.pumpAndSettle();
    expect(find.text('choose your dailies'), findsOneWidget);
    expect(appState.introCardsDone, contains('every mode'));
  });

  testWidgets('the skill, luck and risk card just marks done', (tester) async {
    appState.stats.played = 2;
    await show(tester);
    await tester.tap(
      find.byKey(const ValueKey('today-new-skill, luck and risk')),
    );
    await tester.pumpAndSettle();
    expect(appState.introCardsDone, contains('skill, luck and risk'));
    expect(anyCard(), findsNothing);
  });

  testWidgets('a card survives more games', (tester) async {
    appState.stats.played = 2;
    await show(tester);
    expect(
      find.byKey(const ValueKey('today-new-skill, luck and risk')),
      findsOneWidget,
    );
    appState.stats.played = 12;
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(
      find.byKey(const ValueKey('today-new-skill, luck and risk')),
      findsOneWidget,
    );
  });

  testWidgets('cards queue one at a time, oldest first', (tester) async {
    appState.stats.played = 5;
    await show(tester);
    final order = [
      'skill, luck and risk',
      'achievements',
      'quartet',
      'your numbers',
    ];
    for (final name in order) {
      expect(anyCard(), findsOneWidget, reason: name);
      expect(find.byKey(ValueKey('today-new-$name')), findsOneWidget);
      appState.markIntroCardDone(name);
      await tester.pump();
    }
    expect(anyCard(), findsNothing);
  });

  testWidgets('a taught mode has no card', (tester) async {
    appState.stats.played = 4;
    handledBefore('quartet');
    appState.modesTaught.add(GameMode.quartet);
    await show(tester);
    expect(anyCard(), findsNothing);
  });

  testWidgets('geography has no card until the language is english', (
    tester,
  ) async {
    appState.stats.played = 22;
    handledBefore('geography');
    appState.modesTaught.addAll([
      GameMode.quartet, GameMode.relay, GameMode.lockdown, //
      GameMode.blind, GameMode.equations, GameMode.mastermind,
    ]);
    appState.setup(lang: 'fr', mode: GameMode.classic);
    await show(tester);
    expect(anyCard(), findsNothing);
    appState.setup(lang: 'en', mode: GameMode.classic);
    await tester.pump();
    expect(find.byKey(const ValueKey('today-new-geography')), findsOneWidget);
  });

  testWidgets('a new player at no games sees no card', (tester) async {
    appState.stats.played = 0;
    await show(tester);
    expect(anyCard(), findsNothing);
  });

  testWidgets('free play is the strip, with no pending dots', (tester) async {
    appState.stats.played = 4;
    await show(tester);
    expect(find.byType(ModeStrip), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-dot-prev')), findsNothing);
    expect(find.byKey(const ValueKey('daily-dot-next')), findsNothing);
  });

  testWidgets('a veteran sees no card', (tester) async {
    veteran();
    await show(tester);
    expect(find.textContaining('today-new-'), findsNothing);
    expect(find.text('new'), findsNothing);
  });
}
