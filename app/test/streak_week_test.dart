import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/streak_week.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    // friday 2026-11-13, in India
    dailyClock = () => DateTime.utc(2026, 11, 13, 6);
    appState.setup(
      lang: 'en',
      length: 5,
      tries: 6,
      mode: GameMode.classic,
      draw: Draw.sigmoid,
    );
    appState.myDailies.startFrom('en', [GameMode.classic, GameMode.quartet]);
    appState.dailyLogOf('en').clear();
    for (final (d, t) in [
      ('2026-11-07', dailySolved),
      ('2026-11-08', dailyDouble),
      ('2026-11-09', dailyMissed),
      // the 10th is not played
      ('2026-11-11', dailySolved),
      ('2026-11-12', dailySolved),
    ]) {
      appState.recordDaily(d, t, lang: 'en');
    }
    appState.dailyLogOf('en', GameMode.quartet).clear();
  });
  tearDown(() => dailyClock = DateTime.now);

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: StreakWeek())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? colorOf(WidgetTester tester, Key k) =>
      tester.widget<TablerIcon>(find.byKey(k)).color;

  testWidgets('the week shows solved, double, lost, none and today', (
    tester,
  ) async {
    await show(tester);
    final c = Theme.of(tester.element(find.byType(StreakWeek))).colorScheme;
    expect(
      colorOf(tester, const ValueKey('sw-flame-w-2026-11-07-0')),
      c.secondary,
    );
    expect(
      find.byKey(const ValueKey('sw-flame-w-2026-11-08-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sw-skull-w-2026-11-09')), findsOneWidget);
    expect(
      colorOf(tester, const ValueKey('sw-flame-w-2026-11-10-0')),
      c.outlineVariant,
    );
    // today is not played yet, the streak is alive: ongoing, yellow
    expect(
      colorOf(tester, const ValueKey('sw-flame-w-2026-11-13-0')),
      yellowOf(c),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('best 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('sw-month-2026-11-01')), findsNothing);
  });

  testWidgets('the month opens and closes', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('sw-month-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('back to the week'), findsOneWidget);
    expect(find.text('show the month'), findsNothing);
    // the week strip is hidden, the streak line stays
    expect(find.byKey(const ValueKey('sw-week-2026-11-13')), findsNothing);
    expect(find.byKey(const ValueKey('sw-streak-count')), findsOneWidget);
    // the month's days have no edge, like the rest of the app
    final cell = tester.widget<Container>(
      find.byKey(const ValueKey('sw-month-2026-11-10')),
    );
    expect((cell.decoration as BoxDecoration).border, isNull);
    expect(find.text('november'), findsOneWidget);
    expect(find.byKey(const ValueKey('sw-skull-m-2026-11-09')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sw-flame-m-2026-11-08-1')),
      findsOneWidget,
    );
    // a day to come has no mark
    expect(find.byKey(const ValueKey('sw-flame-m-2026-11-20-0')), findsNothing);
    expect(find.text('super solved'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sw-month-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('show the month'), findsOneWidget);
    expect(find.byKey(const ValueKey('sw-week-2026-11-13')), findsOneWidget);
    expect(find.text('november'), findsNothing);
  });

  Color? dot(WidgetTester tester, int i) =>
      ((tester.widget<Container>(find.byKey(ValueKey('sw-dot-$i')))).decoration
              as BoxDecoration)
          .color;

  void expectQuartet(WidgetTester tester) {
    expect(find.text('best 0'), findsOneWidget);
    expect(find.text('quartet'), findsWidgets);
    final c = Theme.of(tester.element(find.byType(StreakWeek))).colorScheme;
    expect(dot(tester, 1), c.onSurface);
    expect(dot(tester, 0), isNot(c.onSurface));
    // no streak and nothing under way: today is a dim flame
    expect(
      colorOf(tester, const ValueKey('sw-flame-w-2026-11-13-0')),
      c.outlineVariant,
    );
  }

  testWidgets('dragging the card changes the mode and the dots', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('best 2'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('sw-swipe')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expectQuartet(tester);
    // no looping: another drag the same way stays on the last mode
    await tester.drag(
      find.byKey(const ValueKey('sw-swipe')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expectQuartet(tester);
    await tester.drag(
      find.byKey(const ValueKey('sw-swipe')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('best 2'), findsOneWidget);
  });

  testWidgets('a short drag settles back on the same mode', (tester) async {
    await show(tester);
    await tester.drag(
      find.byKey(const ValueKey('sw-swipe')),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('best 2'), findsOneWidget);
  });

  testWidgets('the header, the streak and the week follow the finger', (
    tester,
  ) async {
    await show(tester);
    final head = tester.getTopLeft(
      find.byKey(const ValueKey('sw-header-mode')),
    );
    final button = tester.getTopLeft(
      find.byKey(const ValueKey('sw-month-toggle')),
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('sw-swipe'))),
    );
    await g.moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sw-header-mode')).first).dx,
      lessThan(head.dx),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sw-month-toggle'))),
      button,
    );
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the dots sit below the week and above the month button', (
    tester,
  ) async {
    await show(tester);
    final week = tester
        .getBottomLeft(find.byKey(const ValueKey('sw-streak-count')))
        .dy;
    final dot = tester.getTopLeft(find.byKey(const ValueKey('sw-dot-0'))).dy;
    final button = tester
        .getTopLeft(find.byKey(const ValueKey('sw-month-toggle')))
        .dy;
    expect(dot, greaterThan(week));
    expect(dot, lessThan(button));
  });

  Future<void> openMonth(WidgetTester tester) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('sw-month-toggle')));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<InkWell>(find.byKey(ValueKey(key))).onTap != null;

  testWidgets('the month has no earlier month before the first logged day', (
    tester,
  ) async {
    await openMonth(tester);
    // the log starts on 2026-11-07 and today is in november
    expect(enabled(tester, 'sw-month-prev'), isFalse);
    expect(enabled(tester, 'sw-month-next'), isFalse);
  });

  testWidgets('the arrows move between the months the log reaches', (
    tester,
  ) async {
    appState.recordDaily('2026-09-28', dailySolved, lang: 'en');
    await openMonth(tester);
    expect(find.text('november'), findsOneWidget);
    expect(enabled(tester, 'sw-month-prev'), isTrue);
    expect(enabled(tester, 'sw-month-next'), isFalse);
    await tester.tap(find.byKey(const ValueKey('sw-month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('october'), findsOneWidget);
    expect(enabled(tester, 'sw-month-next'), isTrue);
    // a day of that month shows its mark and the days before the log, none
    expect(find.byKey(const ValueKey('sw-month-2026-10-05')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sw-month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('september'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sw-flame-m-2026-09-28-0')),
      findsOneWidget,
    );
    // nothing before the first month of the log
    expect(enabled(tester, 'sw-month-prev'), isFalse);
    await tester.tap(find.byKey(const ValueKey('sw-month-next')));
    await tester.pumpAndSettle();
    expect(find.text('october'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sw-month-next')));
    await tester.pumpAndSettle();
    expect(find.text('november'), findsOneWidget);
    // closing the month and opening it again is back on the current one
    await tester.tap(find.byKey(const ValueKey('sw-month-prev')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sw-month-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sw-month-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('november'), findsOneWidget);
  });

  testWidgets('a month of another year says the year', (tester) async {
    appState.recordDaily('2025-12-30', dailySolved, lang: 'en');
    await openMonth(tester);
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const ValueKey('sw-month-prev')));
      await tester.pumpAndSettle();
    }
    expect(find.text('december 2025'), findsOneWidget);
    expect(enabled(tester, 'sw-month-prev'), isFalse);
  });

  testWidgets('a day with a kept game can be opened, the others cannot', (
    tester,
  ) async {
    appState.history.add(
      at: 1,
      lang: 'en',
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 100,
      answers: const ['crane'],
      won: true,
      daily: '2026-11-11',
      guesses: const [GuessRow(game: 0, n: 0, word: 'crane', skill: 80)],
    );
    appState.history.add(
      at: 2,
      lang: 'en',
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 100,
      answers: const ['crane'],
      won: true,
      daily: '2026-11-12',
      guesses: const [],
    );
    await openMonth(tester);
    // solved with a kept game with guesses: opens
    expect(find.byKey(const ValueKey('sw-open-2026-11-11')), findsOneWidget);
    // solved but nothing to review, not played, to come: no
    expect(find.byKey(const ValueKey('sw-open-2026-11-12')), findsNothing);
    expect(find.byKey(const ValueKey('sw-open-2026-11-10')), findsNothing);
    expect(find.byKey(const ValueKey('sw-open-2026-11-20')), findsNothing);
    // a solved day with no game kept at all
    expect(find.byKey(const ValueKey('sw-open-2026-11-09')), findsNothing);
  });
}
