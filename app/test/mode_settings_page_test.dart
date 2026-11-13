import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_settings_page.dart';
import 'package:lexodle/modes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(mode: GameMode.classic);
    // a veteran has every mode open and known
    appState.lex.veteran = true;
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(const MaterialApp(home: ModeSettingsPage()));
    await tester.pump();
  }

  testWidgets('the note and the daily settings show', (tester) async {
    await show(tester);
    expect(find.text('these change free play only'), findsOneWidget);
    expect(
      find.text('the daily is the same for everyone, and always uses:'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-row-classic')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-row-lockdown')), findsOneWidget);
    expect(find.text('5 letters, 6 tries'), findsWidgets);
    expect(find.text('5 letters, 6 tries, 5 hearts'), findsOneWidget);
    expect(find.text('8 tiles, 5 tries'), findsOneWidget);
  });

  testWidgets('a mode that is not the current one is changed in place', (
    tester,
  ) async {
    await show(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('pill-blind')));
    await tester.tap(find.byKey(const ValueKey('pill-blind')));
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-blind')), findsOneWidget);
    expect(find.byKey(const ValueKey('assist-choice')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('draw-stepper')),
        matching: find.byTooltip('next'),
      ),
    );
    await tester.pumpAndSettle();
    expect(appState.drawOf(GameMode.blind), isNot(Draw.sigmoid));
    expect(appState.drawOf(GameMode.classic), Draw.sigmoid);
    expect(appState.mode, GameMode.classic);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('draws'), contains('blind'));
  });

  testWidgets('an opened mode is offered at once, a locked one is not', (
    tester,
  ) async {
    appState.lex.veteran = false;
    appState.stats.played = 0;
    await show(tester);
    expect(find.byKey(const ValueKey('pill-classic')), findsOneWidget);
    expect(find.byKey(const ValueKey('pill-quartet')), findsNothing);
    expect(find.textContaining('times to change'), findsNothing);
  });
}
