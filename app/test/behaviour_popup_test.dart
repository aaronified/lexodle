import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/behaviour_popup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/playstyle.dart';

void main() {
  Future<void> open(WidgetTester tester, GuessRow row) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBehaviourPopup(context, row),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  GuessRow row({
    int before = 200,
    int greens = 0,
    double? risk = 10,
    double? rank = 3,
    int fresh = 2,
    bool fits = false,
  }) => GuessRow(
    game: 0,
    n: 0,
    word: 'crane',
    before: before,
    greens: greens,
    risk: risk,
    rank: rank,
    fresh: fresh,
    fits: fits,
  );

  testWidgets('a maximiser says what it is and shows its rank', (tester) async {
    await open(tester, row());
    expect(find.text('maximiser'), findsOneWidget);
    expect(find.text(Behaviour.maximiser.what), findsOneWidget);
    expect(find.textContaining('rank ='), findsOneWidget);
    expect(find.textContaining('3.0%'), findsOneWidget);
    expect(find.textContaining('200 words possible'), findsOneWidget);
  });

  testWidgets('a gambler shows its risk, an eliminator its new letters', (
    tester,
  ) async {
    await open(tester, row(risk: 88, rank: 60));
    expect(find.text('gambler'), findsOneWidget);
    expect(find.textContaining('risk = 88'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await tester.pumpAndSettle();
    await open(tester, row(risk: 10, rank: 60, fresh: 5));
    expect(find.text('eliminator'), findsOneWidget);
    expect(find.textContaining('new letters = '), findsOneWidget);
  });

  testWidgets('an end game closer and prober', (tester) async {
    await open(tester, row(before: 6, fits: true));
    expect(find.text('closer'), findsOneWidget);
    expect(
      find.textContaining('fits the 6 words still possible'),
      findsOneWidget,
    );
    expect(find.textContaining('end game'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await tester.pumpAndSettle();
    await open(tester, row(before: 8, fits: false, rank: 2));
    expect(find.text('prober'), findsOneWidget);
  });

  testWidgets('a guess counted as nothing says why', (tester) async {
    // the middle game: between 16 and 64 words, fewer than three greens
    await open(tester, row(before: 30, greens: 1));
    expect(find.text('not counted'), findsOneWidget);
    expect(find.textContaining('middle game'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await tester.pumpAndSettle();
    await open(tester, row(before: 1));
    expect(find.textContaining('one word left'), findsOneWidget);
  });
}
