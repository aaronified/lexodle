import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(themeMode: ThemeMode.system, black: false);
  });

  Future<void> show(WidgetTester tester, {VoidCallback? onReplay}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: YouPage(onReplayFirstGame: onReplay ?? () {})),
      ),
    );
    await tester.pump();
  }

  Finder row(String id) => find.byKey(ValueKey('you-row-$id'));

  void player({required int played, required bool veteran}) {
    appState.stats.played = played;
    appState.lex.veteran = veteran;
  }

  testWidgets('a veteran sees every row', (tester) async {
    player(played: 500, veteran: true);
    await show(tester);
    for (final id in [
      'achievements',
      'lex',
      'reminders',
      'playstyle',
      'history',
      'friends',
    ]) {
      expect(row(id), findsOneWidget, reason: id);
    }
    expect(find.text('coming in an upcoming release'), findsOneWidget);
  });

  testWidgets(
    'a new player at game 2 sees no achievements, playstyle, history',
    (tester) async {
      player(played: 2, veteran: false);
      await show(tester);
      expect(row('achievements'), findsNothing);
      expect(row('playstyle'), findsNothing);
      expect(row('history'), findsNothing);
      expect(row('lex'), findsNothing);
      expect(row('reminders'), findsOneWidget);
      expect(row('friends'), findsOneWidget);
    },
  );

  testWidgets('a new player at game 5 sees them, but not lex', (tester) async {
    player(played: 5, veteran: false);
    await show(tester);
    expect(row('achievements'), findsOneWidget);
    expect(row('playstyle'), findsOneWidget);
    expect(row('history'), findsOneWidget);
    expect(row('lex'), findsNothing);
  });

  testWidgets('the theme choice calls setup, and black needs dark', (
    tester,
  ) async {
    player(played: 500, veteran: true);
    await show(tester);
    Switch sw() => tester.widget<Switch>(find.byType(Switch));
    expect(sw().onChanged, isNull);
    await tester.tap(find.text('dark'));
    await tester.pumpAndSettle();
    expect(appState.themeMode, ThemeMode.dark);
    expect(sw().onChanged, isNotNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(appState.blackTheme, isTrue);
    await tester.tap(find.text('light'));
    await tester.pumpAndSettle();
    expect(appState.themeMode, ThemeMode.light);
    expect(appState.blackTheme, isFalse);
  });

  testWidgets('the help button calls back', (tester) async {
    player(played: 500, veteran: true);
    var n = 0;
    await show(tester, onReplay: () => n++);
    await tester.tap(find.byKey(const ValueKey('you-help')));
    expect(n, 1);
  });
}
