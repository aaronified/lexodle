import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/equation_solver.dart';
import 'package:lexodle/equations.dart' show faceOf;
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/split_plot.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pool = [
  '1+9=10',
  '2+8=10',
  '3+7=10',
  '4+6=10',
  '5+5=10',
  '6+4=10',
  '12/4=3',
];

WordBank _bank() => WordBank.custom(
  const Language('en', 'English', 'English', [6]),
  {6: _pool},
  {6: List.filled(_pool.length, 1)},
  curveOrigin: WordBank.defaultCurveOrigin,
  curveWidth: WordBank.defaultCurveWidth,
  anyChar: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the marks narrow the equations', () {
    // 1+9=10 against 2+8=10: the signs and the 10 are in place, 1 and 9 are not
    final marks = evaluate('2+8=10', '1+9=10');
    expect(marks.map((m) => m.name), [
      'absent',
      'correct',
      'absent',
      'correct',
      'correct',
      'correct',
    ]);
    expect(filterEligible(_pool, '1+9=10', marks), [
      '2+8=10',
      '3+7=10',
      '4+6=10',
      '5+5=10',
      '6+4=10',
    ]);
  });

  test('the recommendation names an equation of the list', () async {
    final r = await recommendWithin(_pool, _pool, 5);
    expect(_pool, contains(r!.word));
    expect(r.expected, lessThan(_pool.length));
  });

  Future<void> open(
    WidgetTester tester, {
    Set<String> excluded = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(eqLength: 6, eqTries: 5);
    await tester.pumpWidget(
      MaterialApp(
        home: EquationSolverPage(bank: _bank(), excluded: excluded),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the page starts with the pool minus the excluded', (
    tester,
  ) async {
    await open(tester, excluded: const {'1+9=10'});
    expect(find.text('6 equations fit · 5 tries left'), findsOneWidget);
    expect(find.text('alternatives'), findsOneWidget);
  });

  testWidgets('tapping the tiles to green leaves the one equation', (
    tester,
  ) async {
    await open(tester);
    for (final ch in '12/4=3'.split('')) {
      await tester.tap(find.text(faceOf(ch)).last);
    }
    for (var i = 0; i < 6; i++) {
      // grey, then yellow, then green
      final tile = find.byType(MarkTile).at(i);
      for (var k = 0; k < 3; k++) {
        if (tester.widget<MarkTile>(tile).mark == Mark.correct) break;
        await tester.tap(tile);
        await tester.pump();
      }
      expect(tester.widget<MarkTile>(tile).mark, Mark.correct);
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.textContaining('the only equation that fits: 12÷4=3'),
      findsOneWidget,
    );
  });

  Finder chips() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('alt-'),
  );

  Future<void> typeRow(WidgetTester tester, String eq) async {
    for (final ch in eq.split('')) {
      await tester.tap(find.text(faceOf(ch)).last);
    }
    await tester.pump();
  }

  testWidgets('up to five alternatives, the recommended first', (tester) async {
    await open(tester);
    expect(chips(), findsNWidgets(5));
    final r = await recommendWithin(_pool, _bank().guessable(6), 5);
    expect(
      (tester.widget(chips().first) as InkWell).key,
      ValueKey('alt-${r!.word}'),
    );
    expect(find.byType(SplitPlot), findsOneWidget);
    expect(tester.widget<SplitPlot>(find.byType(SplitPlot)).onUse, isNotNull);
  });

  testWidgets('selecting a chip changes the plot; use fills the row', (
    tester,
  ) async {
    await open(tester);
    final before = tester.widget<SplitPlot>(find.byType(SplitPlot)).word;
    await tester.tap(chips().at(1));
    await tester.pump();
    final after = tester.widget<SplitPlot>(find.byType(SplitPlot)).word;
    expect(after, isNot(before));
    await tester.tap(find.byKey(const ValueKey('plot-use')));
    await tester.pump();
    final row = tester
        .widgetList<MarkTile>(find.byType(MarkTile))
        .map((t) => t.ch)
        .join();
    expect(row, after);
  });

  testWidgets('marking a tile of the typed row changes the lit bar', (
    tester,
  ) async {
    await open(tester);
    await typeRow(tester, '1+9=10');
    final plot = find.byType(SplitPlot);
    expect(plot, findsOneWidget);
    expect(tester.widget<SplitPlot>(plot).onUse, isNull);
    final code0 = tester.widget<SplitPlot>(plot).highlight;
    expect(find.byKey(const ValueKey('plot-bar-hl')), findsNothing);
    // the colours 2+8=10 would show against 1+9=10
    for (final i in [1, 3, 4, 5]) {
      for (var k = 0; k < 2; k++) {
        await tester.tap(find.byType(MarkTile).at(i));
        await tester.pump();
      }
    }
    expect(tester.widget<SplitPlot>(plot).highlight, isNot(code0));
    expect(find.byKey(const ValueKey('plot-bar-hl')), findsOneWidget);
  });
}
