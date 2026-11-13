import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/app_shell.dart';
import 'package:lexodle/home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/today_page.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomeSwitch()));
    await tester.pump();
  }

  testWidgets('the old home stays until the preview is on', (tester) async {
    appState.setNewUi(false);
    await show(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('a new player has today and you; the rest come as taught', (
    tester,
  ) async {
    appState.setNewUi(true);
    addTearDown(() => appState.setNewUi(false));
    appState.lex.veteran = false;
    appState.stats.played = 1;
    await show(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text('words'), findsNothing);
    expect(find.text('learn'), findsNothing);
    await tester.tap(find.text('you').last);
    await tester.pump();
    expect(find.byType(YouPage), findsOneWidget);
    appState.stats.played = 9;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    appState.notifyListeners();
    await tester.pump();
    expect(find.text('words'), findsWidgets);
    expect(find.text('learn'), findsNothing);
    appState.stats.played = 24;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    appState.notifyListeners();
    await tester.pump();
    expect(find.text('learn'), findsWidgets);
  });

  testWidgets('a veteran has all four tabs', (tester) async {
    appState.setNewUi(true);
    addTearDown(() => appState.setNewUi(false));
    appState.lex.veteran = true;
    await show(tester);
    for (final t in ['today', 'words', 'learn', 'you']) {
      expect(find.text(t), findsWidgets);
    }
  });
}
