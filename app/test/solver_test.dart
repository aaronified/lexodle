import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('solver narrows the words and recommends a guess', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4);
    // word files are read with real file IO, which fake-async cannot await
    final bank = (await tester.runAsync(() async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'))))!;

    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    // recommend() yields to the event loop; advance the fake clock past it
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('recommended guess'), findsOneWidget);
    expect(find.textContaining('possible words'), findsOneWidget);

    // a guess with every tile left grey rules out all words sharing its letters
    for (final ch in 'mais'.split('')) {
      await tester.sendKeyEvent(LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch);
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));

    final undo = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'undo last'));
    expect(undo.onPressed, isNotNull); // the guess is in the history
    expect(find.text('recommended guess'), findsOneWidget);
  });
}
