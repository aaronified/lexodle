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
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
  }

  testWidgets('settings has only what has no other home', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await show(tester, newUi: true);
    expect(find.text('touch'), findsOneWidget);
    expect(find.text('updates'), findsOneWidget);
    expect(find.text('log'), findsOneWidget);
    expect(find.text('about'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-look')), findsOneWidget);
    expect(find.text('theme'), findsNothing);
    expect(find.text('backup'), findsNothing);
    expect(find.text('support lexodle'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
