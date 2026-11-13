import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _day(int ago) => DateTime.now()
    .subtract(Duration(days: ago))
    .toIso8601String()
    .substring(0, 10);

void _prepare() {
  appState.lang = 'en';
  appState.stats = Stats();
  appState.ach = {
    'wins': AchState(times: 2, dates: [_day(5), _day(0)], value: 30),
    'played': AchState(times: 1, dates: [_day(1)], value: 40),
    'quick': AchState(times: 4, dates: [_day(9), _day(8), _day(7), _day(6)]),
    'last_try': AchState(times: 1, dates: [_day(3)], value: 1),
    'skill_avg': AchState(times: 2, dates: [_day(4), _day(2)]),
  };
}

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 60000));
  await tester.pumpWidget(
    const MaterialApp(
      home: AchievementsPage(),
      onGenerateRoute: onGenerateRoute,
    ),
  );
  await tester.pump();
}

/// The listed achievements, top to bottom.
List<String> _listed(WidgetTester tester) {
  final ids = [
    for (final a in achievements)
      if (find.byKey(ValueKey('${a.id}-row')).evaluate().isNotEmpty) a.id,
  ];
  double y(String id) => tester.getTopLeft(find.byKey(ValueKey('$id-row'))).dy;
  return ids..sort((a, b) => y(a).compareTo(y(b)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.ach = {};
    appState.stats = Stats();
  });

  testWidgets('recent: the three newest, newest first, with when', (
    tester,
  ) async {
    _prepare();
    await _open(tester);
    final recent = find.byKey(const ValueKey('recent'));
    expect(recent, findsOneWidget);
    // wins today, played yesterday, skill_avg 2 days ago; last_try (3) is out
    for (final id in ['wins', 'played', 'skill_avg']) {
      expect(find.byKey(ValueKey('recent-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const ValueKey('recent-last_try')), findsNothing);
    expect(find.byKey(const ValueKey('recent-quick')), findsNothing);
    double y(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('recent-$id'))).dy;
    expect(y('wins'), lessThan(y('played')));
    expect(y('played'), lessThan(y('skill_avg')));
    String when(String id) =>
        tester.widget<Caption>(find.byKey(ValueKey('recent-when-$id'))).text;
    expect(when('wins'), 'today');
    expect(when('played'), 'yesterday');
    expect(when('skill_avg'), '2 days ago');
    // the level reached: its name and medal
    final wins = achievements.firstWhere((a) => a.id == 'wins');
    expect(
      find.descendant(of: recent, matching: find.text(wins.levels[1].name)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: recent,
        matching: find.text(wins.levels[1].medal.name),
      ),
      findsWidgets,
    );
  });

  testWidgets('recent: hidden when nothing is earned', (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('recent')), findsNothing);
    expect(find.byKey(const ValueKey('sort-closest')), findsOneWidget);
  });

  test('days ago', () {
    final now = DateTime(2026, 11, 13, 20);
    expect(daysAgo('2026-11-13', now), 'today');
    expect(daysAgo('2026-11-12', now), 'yesterday');
    expect(daysAgo('2026-11-03', now), '10 days ago');
  });

  testWidgets('no sort until one is tapped; tapping it again undoes it', (
    tester,
  ) async {
    _prepare();
    await _open(tester);
    final standard = _listed(tester);
    expect(standard.take(5), [
      'wins',
      'played',
      'quick',
      'last_try',
      'skill_avg',
    ]);
    await tester.tap(find.byKey(const ValueKey('sort-medal')));
    await tester.pump();
    expect(_listed(tester), isNot(standard));
    await tester.tap(find.byKey(const ValueKey('sort-medal')));
    await tester.pump();
    expect(_listed(tester), standard);
  });

  testWidgets('closest: highest ratio first, maxed last', (tester) async {
    _prepare();
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('sort-closest')));
    await tester.pump();
    final l = _listed(tester);
    // played 40/50, wins 30/100, last_try 1/10, then the rest
    expect(l.take(3), ['played', 'wins', 'last_try']);
    expect(l.last, 'quick');
  });

  testWidgets('medal: highest medal first, ties in the current order', (
    tester,
  ) async {
    _prepare();
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('sort-medal')));
    await tester.pump();
    // platinum, then the two silvers, then the two bronzes
    expect(_listed(tester).take(5), [
      'quick',
      'wins',
      'skill_avg',
      'played',
      'last_try',
    ]);
  });

  testWidgets('a to z: by the name shown', (tester) async {
    _prepare();
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('sort-a to z')));
    await tester.pump();
    final mine = appState.achOf('en');
    String name(Achievement a) {
      final d = (mine[a.id]?.times ?? 0).clamp(0, a.count);
      return a.levels[d == 0 ? 0 : d - 1].name.toLowerCase();
    }

    final expected = [for (final a in achievements) a]
      ..sort((x, y) => name(x).compareTo(name(y)));
    expect(_listed(tester), [for (final a in expected) a.id]);
  });

  testWidgets('the sort works within the medal filter', (tester) async {
    _prepare();
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('medal-filter-bronze')));
    await tester.pump();
    expect(_listed(tester), ['played', 'last_try']);
    await tester.tap(find.byKey(const ValueKey('sort-a to z')));
    await tester.pump();
    // "last breath" before "persistent"
    expect(_listed(tester), ['last_try', 'played']);
    await tester.tap(find.byKey(const ValueKey('sort-closest')));
    await tester.pump();
    expect(_listed(tester), ['played', 'last_try']);
    await tester.tap(find.byKey(const ValueKey('medal-filter-silver')));
    await tester.pump();
    expect(_listed(tester), ['wins', 'skill_avg']);
  });
}
