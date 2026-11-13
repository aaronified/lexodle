import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
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
    final cs = Theme.of(tester.element(find.byType(StreakWeek))).colorScheme;
    final cell = tester.widget<Container>(
      find.byKey(const ValueKey('sw-month-2026-11-10')),
    );
    expect(
      (cell.decoration as BoxDecoration).border,
      Border.all(color: cs.outlineVariant),
    );
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

  testWidgets('the arrows change the mode and the dots', (tester) async {
    await show(tester);
    expect(find.text('best 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sw-next')));
    await tester.pumpAndSettle();
    expectQuartet(tester);
    await tester.tap(find.byKey(const ValueKey('sw-prev')));
    await tester.pumpAndSettle();
    expect(find.text('best 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('sw-header-mode')), findsOneWidget);
  });

  testWidgets('swiping changes the mode and the dots', (tester) async {
    await show(tester);
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
}
