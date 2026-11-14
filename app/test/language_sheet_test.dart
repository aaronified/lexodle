import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/language_sheet.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const langs = [
    Language('en', 'English', 'English', [5]),
    Language('fr', 'Français', 'French', [5]),
    Language('hu', 'Magyar', 'Hungarian', [5]),
  ];
  String? result = 'unset';

  Future<void> open(WidgetTester tester) async {
    result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showLanguageSheet(
                context,
                langs: langs,
                current: 'fr',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every language and marks the current one', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('language-sheet')), findsOneWidget);
    for (final l in langs) {
      expect(find.byKey(ValueKey('language-${l.code}')), findsOneWidget);
      expect(find.text(l.name), findsOneWidget);
      if (l.wikt != l.name) expect(find.text(l.wikt), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('language-fr')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a language returns its code', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('language-hu')));
    await tester.pumpAndSettle();
    expect(result, 'hu');
    expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
  });

  testWidgets('back returns null', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
  });

  testWidgets('the close icon returns null', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('language-close')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
