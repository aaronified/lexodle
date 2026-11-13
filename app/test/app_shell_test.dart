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

  testWidgets('the preview shows four tabs, today first', (tester) async {
    appState.setNewUi(true);
    addTearDown(() => appState.setNewUi(false));
    await show(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TodayPage), findsOneWidget);
    for (final t in ['today', 'words', 'learn', 'you']) {
      expect(find.text(t), findsWidgets);
    }
    await tester.tap(find.text('you').last);
    await tester.pump();
    expect(find.byType(YouPage), findsOneWidget);
  });
}
