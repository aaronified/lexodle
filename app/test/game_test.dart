import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('play a game through the real UI and lose it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();

    expect(find.text('lexodle'), findsOneWidget);
    await tester.tap(find.text('play'));
    await tester.pumpAndSettle();
    // the word file is read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(find.text('3 tries left'), findsOneWidget);

    // Guess three real words from the bank, none of them the answer except by
    // luck; whichever way it ends the game must reach the result panel.
    final bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'));
    final words = bank.answers(4).take(3).toList();
    for (final w in words) {
      for (final ch in w.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('again'), findsOneWidget);
    expect(appState.stats.played, 1);
  });
}

LogicalKeyboardKey _key(String ch) =>
    LogicalKeyboardKey(ch.codeUnitAt(0));
