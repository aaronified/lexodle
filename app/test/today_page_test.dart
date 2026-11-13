import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/first_run/mode_lesson_page.dart';
import 'package:lexodle/main.dart';
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
    await tester.tap(row(GameMode.relay));
    await tester.pump();
    expect(
      find.text('the game over and review screens remain as they are'),
      findsOneWidget,
    );
  });

  testWidgets('free play is one line on a narrow phone', (tester) async {
    veteran();
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TodayPage())),
    );
    await tester.pump();
    final text = find.descendant(
      of: find.byKey(const ValueKey('today-free-play')),
      matching: find.text('free play'),
    );
    expect(text, findsOneWidget);
    // one line of 14 px text is well under two lines' height
    expect(tester.getSize(text).height, lessThan(24));
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-primary')),
        matching: find.text('continue lockdown'),
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
    expect(find.byKey(const ValueKey('today-free-play')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-primary')),
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
    await show(tester);
    expect(find.text('how it works ›'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-new-quartet')));
    await tester.pumpAndSettle();
    expect(find.byType(ModeLessonPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-close')));
    await tester.pumpAndSettle();
    expect(find.byType(ModeLessonPage), findsNothing);
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

  Future<List<String>> showRouted(WidgetTester tester) async {
    final pushed = <String>[];
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: TodayPage()),
        onGenerateRoute: (r) {
          pushed.add(r.name ?? '');
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
    final want = {
      5: Routes.history,
      6: Routes.gameModes,
      9: Routes.words,
      24: Routes.learn,
    };
    for (final e in want.entries) {
      await tester.pumpWidget(const SizedBox());
      appState.introCardsDone.clear();
      appState.stats.played = e.key;
      appState.lex.veteran = false;
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
  });

  testWidgets('a veteran sees no card', (tester) async {
    veteran();
    await show(tester);
    expect(find.textContaining('today-new-'), findsNothing);
    expect(find.text('new'), findsNothing);
  });
}
