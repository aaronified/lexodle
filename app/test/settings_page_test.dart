import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
  });

  Future<void> show(WidgetTester tester, {required bool newUi}) async {
    appState.newUi = newUi;
    await tester.binding.setSurfaceSize(const Size(420, 3600));
    // a fresh tree each time: the page is const, so it would not rebuild
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
  }

  void games(int n) {
    appState.stats.played = n;
    appState.lex.veteran = false;
  }

  testWidgets('settings is one page, the theme first', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    games(500);
    await show(tester, newUi: true);
    expect(find.byKey(const ValueKey('new-look')), findsNothing);
    final order = [
      'theme',
      'touch',
      'backup',
      'updates',
      'log',
      'support lexodle',
      'about',
    ];
    double top(String t) => tester.getTopLeft(find.text(t)).dy;
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
    }
    expect(
      find.byKey(const ValueKey('settings-row-reminders')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-button')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reminders open at game 2, support at game 7', (tester) async {
    Finder reminders() => find.byKey(const ValueKey('settings-row-reminders'));
    games(0);
    await show(tester, newUi: true);
    expect(reminders(), findsNothing);
    expect(find.text('theme'), findsOneWidget);
    expect(find.text('backup'), findsOneWidget);
    expect(find.text("what's new"), findsOneWidget);
    games(1);
    await show(tester, newUi: true);
    expect(reminders(), findsNothing);
    games(2);
    await show(tester, newUi: true);
    expect(reminders(), findsOneWidget);
    games(6);
    await show(tester, newUi: true);
    expect(find.text('support lexodle'), findsNothing);
    games(7);
    await show(tester, newUi: true);
    expect(find.text('support lexodle'), findsOneWidget);
  });

  testWidgets('the what is new row shows the changelog', (tester) async {
    games(0);
    await show(tester, newUi: true);
    final row = find.byKey(const ValueKey('settings-row-whatsnew'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
