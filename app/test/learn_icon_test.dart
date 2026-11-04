import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game_modes_dialog.dart';
import 'package:lexodle/learn_guide.dart';
import 'package:lexodle/learn_home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder hat() =>
      find.byWidgetPredicate((w) => w is TablerIcon && w.name == 'school');

  testWidgets('the learn button of the game modes has the graduation hat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    await appState.load();
    await tester.pumpWidget(const MaterialApp(home: GameModesDialog()));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-learn')),
        matching: hat(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the learn home and a mode guide have it in the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: LearnHomePage(bank: bank)));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(AppBar), matching: hat()),
      findsOneWidget,
    );
    await tester.pumpWidget(
      const MaterialApp(home: ModeGuidePage(mode: GameMode.equations)),
    );
    await tester.pump();
    expect(
      find.descendant(of: find.byType(AppBar), matching: hat()),
      findsOneWidget,
    );
  });
}
