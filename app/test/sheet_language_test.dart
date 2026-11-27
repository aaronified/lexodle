import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/language_picker.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/sheet_language.dart';
import 'package:lexodle/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sheetLanguage.reset();
  });

  Widget app(bool sheet) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          const TopBar(slider: Text('the app slider')),
          if (sheet)
            const Positioned(
              top: 300,
              child: SheetLanguageScope(child: Text('a sheet')),
            ),
        ],
      ),
    ),
  );

  testWidgets('the top bar shows the app slider, and the sheet takes it over', (
    tester,
  ) async {
    await appState.load();
    await tester.pumpWidget(app(false));
    expect(find.text('the app slider'), findsOneWidget);
    await tester.pumpWidget(app(true));
    await tester.pump();
    // the pill of the sheet: all to begin with
    expect(find.text('the app slider'), findsNothing);
    expect(find.byKey(const ValueKey('language-slider')), findsOneWidget);
    expect(sheetLanguage.selected, allLanguages);
    expect(sheetLanguage.language, isNull);
    // choosing a language is the sheet's, not the app's
    final app0 = appState.lang;
    sheetLanguage.select('fr');
    await tester.pump();
    expect(sheetLanguage.language, 'fr');
    expect(appState.lang, app0);
    // closing gives the bar back
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(find.text('the app slider'), findsOneWidget);
  });
}
