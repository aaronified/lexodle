import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/changelog.dart';

void main() {
  test('one summary per line, blanks dropped', () {
    expect(parseChangelog('a\n\n  b  \n'), ['a', 'b']);
    expect(parseChangelog(''), isEmpty);
  });

  testWidgets('the dialog lists the summaries and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChangelog(context, const ['one', 'two']),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('· one'), findsOneWidget);
    expect(find.text('· two'), findsOneWidget);
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(find.text('· one'), findsNothing);
  });
}
