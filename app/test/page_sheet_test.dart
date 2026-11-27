import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/page_sheet.dart';

void main() {
  var taps = 0;
  Future<void> open(WidgetTester tester) async {
    taps = 0;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Stack(
              children: [
                // the app's top bar: it must stay live under the sheet
                Positioned(
                  top: 16,
                  left: 16,
                  child: TextButton(
                    key: const ValueKey('top'),
                    onPressed: () => taps++,
                    child: const Text('top'),
                  ),
                ),
                Center(
                  child: TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => Navigator.push(
                      context,
                      PageSheetRoute<void>(
                        builder: (_) => const PageSheet(
                          title: 'a sheet',
                          child: Text('inside'),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('a sheet rises under the top bar, with its own title and close', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('a sheet'), findsOneWidget);
    expect(find.text('inside'), findsOneWidget);
    // it starts below the top bar (64 high)
    expect(
      tester.getTopLeft(find.byType(PageSheet)).dy,
      greaterThanOrEqualTo(64),
    );
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('a sheet'), findsNothing);
  });

  testWidgets('the top bar stays live while the sheet is open', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('top')));
    expect(taps, 1);
    expect(find.text('a sheet'), findsOneWidget);
  });
}
