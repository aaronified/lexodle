import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/guess_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an option shows the verdict, and next asks another', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await appState.load();
    appState.setup(lang: 'en', length: 5);
    await tester.pumpWidget(MaterialApp(home: GuessPage(bank: bank, seed: 3)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('guess-option-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('guess-verdict')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('guess-option-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('guess-verdict')), findsOneWidget);
    expect(find.textContaining('skill '), findsWidgets);
    expect(find.byKey(const ValueKey('guess-next')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guess-next')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('guess-verdict')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('guess-option-1')));
    await tester.pump();
    expect(find.textContaining('luck '), findsWidgets);
    expect(find.textContaining('the word was '), findsOneWidget);
  });
}
