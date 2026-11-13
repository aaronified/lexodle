import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/my_dailies.dart';
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

  testWidgets('a new player gets the new card and the next-up bar', (
    tester,
  ) async {
    appState.stats.played = 4;
    appState.lex.veteran = false;
    await show(tester);
    expect(find.byKey(const ValueKey('today-new-quartet')), findsOneWidget);
    expect(find.text('four words at once'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-next-up')), findsOneWidget);
    expect(find.text('your numbers'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-next-bar')), findsOneWidget);
    // quartet is open at 4, so the choice is there
    expect(find.byKey(const ValueKey('today-choose')), findsOneWidget);
  });

  testWidgets('the choice is hidden until quartet opens', (tester) async {
    appState.stats.played = 2;
    appState.lex.veteran = false;
    await show(tester);
    expect(find.byKey(const ValueKey('today-choose')), findsNothing);
    expect(find.byKey(const ValueKey('today-more')), findsNothing);
  });
}
