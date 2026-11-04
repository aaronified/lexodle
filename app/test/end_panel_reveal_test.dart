import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  testWidgets('under the end panel the boards run on, to be shown when it is '
      'lowered', (tester) async {
    const size = Size(420, 1700);
    await tester.binding.setSurfaceSize(size);
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          bank: bank,
          mode: GameMode.classic,
          practice: true,
          daily: const Daily('', 'crane', length: 5, tries: 1),
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    for (final ch in 'stare'.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.textContaining('the word was'), findsWidgets, reason: 'over');
    // the boards' scroll view reaches the foot of the screen, under the panel
    final bottom = tester.getBottomLeft(
      find.byKey(const ValueKey('boards-scroll')),
    );
    final screen = tester.getSize(find.byType(MaterialApp)).height;
    expect(bottom.dy, greaterThan(screen - 40));
  });
}
