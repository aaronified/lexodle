import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/choose_dailies_sheet.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/my_dailies.dart';
import 'package:lexodle/today_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(GameMode)? play,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showChooseDailies(context, play: play),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.lang = 'en';
    appState.myDailies = MyDailies();
    appState.stats.played = 10;
    appState.lex.veteran = false;
  });

  testWidgets('a switch adds a daily and drops it again', (tester) async {
    await _open(tester);
    expect(find.text('choose your dailies'), findsOneWidget);
    expect(appState.dailiesOf('en'), [GameMode.classic]);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(appState.dailiesOf('en'), [GameMode.classic, GameMode.quartet]);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(appState.dailiesOf('en'), [GameMode.classic]);
  });

  testWidgets('the last daily cannot be switched off', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('daily-switch-classic')));
    await tester.pumpAndSettle();
    expect(find.text('keep at least one daily'), findsOneWidget);
    expect(appState.dailiesOf('en'), [GameMode.classic]);
  });

  testWidgets('switching a daily off hides it, no confirm, streak stays', (
    tester,
  ) async {
    appState.recordDaily(dailyDate(), dailySolved, mode: GameMode.quartet);
    appState.myDailies = MyDailies()..add('en', GameMode.quartet);
    final streak = appState.dailyStreakFor('en', GameMode.quartet);
    expect(streak, greaterThan(0));
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(find.textContaining('remove it anyway?'), findsNothing);
    expect(appState.dailiesOf('en'), [GameMode.classic]);
    expect(appState.dailyStreakFor('en', GameMode.quartet), streak);
    expect(find.text('hidden · streak $streak'), findsOneWidget);
  });

  testWidgets('the sort slider changes how today is sorted', (tester) async {
    await _open(tester);
    expect(find.text('sort today by'), findsOneWidget);
    final start = TodaySort.values.indexOf(appState.todaySort);
    await tester.tap(find.byKey(const ValueKey('sort-next')));
    await tester.pumpAndSettle();
    expect(appState.todaySort, TodaySort.values[start + 1]);
    await tester.tap(find.byKey(const ValueKey('sort-prev')));
    await tester.pumpAndSettle();
    expect(appState.todaySort, TodaySort.values[start]);
  });

  testWidgets('dragging a handle stores the order and sets my order', (
    tester,
  ) async {
    appState.myDailies = MyDailies()..add('en', GameMode.quartet);
    await _open(tester);
    expect(appState.todaySort, isNot(TodaySort.mine));
    final first = find.byKey(const ValueKey('daily-row-classic'));
    final second = find.byKey(const ValueKey('daily-row-quartet'));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));

    final handle = find.descendant(
      of: first,
      matching: find.byIcon(Icons.drag_indicator),
    );
    final g = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    await g.moveBy(const Offset(0, 80));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(appState.todaySort, TodaySort.mine);
    expect(
      appState.dailyOrder.indexOf(GameMode.quartet),
      lessThan(appState.dailyOrder.indexOf(GameMode.classic)),
    );
  });

  testWidgets('play is offered only for a hidden open daily', (tester) async {
    GameMode? played;
    await _open(tester, play: (m) async => played = m);
    // classic is on, quartet is hidden
    expect(find.byKey(const ValueKey('daily-play-classic')), findsNothing);
    expect(find.byKey(const ValueKey('daily-play-quartet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-play-quartet')));
    await tester.pumpAndSettle();
    expect(played, GameMode.quartet);
    expect(find.text('choose your dailies'), findsNothing);
  });

  testWidgets('without a play callback there is no play button', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('daily-play-quartet')), findsNothing);
  });

  testWidgets('before every mode opens, only open modes are listed', (
    tester,
  ) async {
    appState.stats.played = 5;
    await _open(tester);
    expect(find.byKey(const ValueKey('daily-switch-quartet')), findsOneWidget);
    expect(find.text('lockdown'), findsNothing);
    expect(find.text('geography'), findsNothing);
    expect(find.textContaining('not open yet'), findsNothing);
    expect(find.textContaining('more games'), findsNothing);
  });

  testWidgets('from every mode on, locked modes are greyed, no count', (
    tester,
  ) async {
    appState.stats.played = 6;
    await _open(tester);
    expect(find.byKey(const ValueKey('daily-switch-lockdown')), findsNothing);
    expect(find.text('lockdown'), findsOneWidget);
    expect(find.textContaining('not open yet'), findsWidgets);
    expect(find.textContaining('more games'), findsNothing);
  });

  testWidgets('geography is not listed for another language', (tester) async {
    appState.stats.played = 40;
    appState.lang = 'fr';
    await _open(tester);
    expect(find.text('geography'), findsNothing);
    appState.lang = 'en';
  });
}
