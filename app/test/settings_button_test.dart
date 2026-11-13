import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/achievements_page.dart';
import 'package:lexodle/how_to.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_settings_page.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/today_page.dart';
import 'package:lexodle/words_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  /// [page] on top of a bare home, so it has a back button; the settings route
  /// is a marker page.
  Future<void> pumpOver(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) => s.name == Routes.settings
              ? const Scaffold(body: Text('settings page'))
              : page,
        ),
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> opensSettings(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('settings-button'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  }

  final pages = <String, Widget>{
    'today': const Scaffold(body: TodayPage()),
    'words': const WordsPage(),
    'achievements': const AchievementsPage(),
    'mastery': const MasteryPage(),
    'history': const HistoryPage(),
    'playstyle': const PlaystylePage(),
    'mode settings': const ModeSettingsPage(),
  };

  for (final e in pages.entries) {
    testWidgets('${e.key} has the settings button, top right', (tester) async {
      await pumpOver(tester, e.value);
      await opensSettings(tester);
    });
  }

  testWidgets('words, as a tab, has it in its header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    await tester.pumpWidget(
      MaterialApp(
        home: const WordsPage(),
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) => const Scaffold(body: Text('settings page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    await opensSettings(tester);
  });

  testWidgets('how to play has a back button and the settings button', (
    tester,
  ) async {
    await pumpOver(tester, const Scaffold(body: SizedBox()));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const HowToPage()));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await opensSettings(tester);
  });
}
