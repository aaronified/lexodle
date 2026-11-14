import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/equation_solver.dart';
import 'package:lexodle/equations.dart' show faceOf;
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
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
    expect(find.textContaining('6 equations on my list fit'), findsOneWidget);
    expect(find.textContaining('answers from 6 equations'), findsOneWidget);
    expect(find.textContaining('5 tries left'), findsOneWidget);
    expect(find.text('recommended guess'), findsOneWidget);
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
      find.textContaining('the only equation on my list that fits: 12÷4=3'),
      findsOneWidget,
    );
  });
}
