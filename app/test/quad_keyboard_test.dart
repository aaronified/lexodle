import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget board(Map<String, List<Mark?>> quad, Brightness b) => MaterialApp(
    theme: buildTheme(b),
    home: Scaffold(
      body: LetterKeyboard(
        letters: {'a', 'b', 'c', 'd'},
        quadMarks: quad,
        onLetter: (_) {},
        onEnter: () {},
        onBack: () {},
      ),
    ),
  );

  QuadPainter painter(WidgetTester tester, String letter) {
    final paint = tester.widget<CustomPaint>(
      find.byKey(ValueKey('quad-$letter')),
    );
    return paint.painter! as QuadPainter;
  }

  for (final b in Brightness.values) {
    testWidgets('a key is cut in four, one colour per board (${b.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        board({
          'a': [Mark.correct, Mark.present, Mark.absent, null],
          'b': [null, null, null, null],
        }, b),
      );
      final c = buildTheme(b).colorScheme;
      final p = painter(tester, 'a');
      expect(p.colors, [
        markColors(c, Mark.correct).$1,
        markColors(c, Mark.present).$1,
        markColors(c, Mark.absent).$1,
        null,
      ]);
      // a letter nothing has said anything about is an ordinary key
      expect(find.byKey(const ValueKey('quad-b')), findsNothing);
      expect(find.byKey(const ValueKey('quad-c')), findsNothing);
      // the letters are still all there
      for (final l in ['a', 'b', 'c', 'd']) {
        expect(find.text(l), findsOneWidget);
      }
    });
  }

  testWidgets('the four parts fill the key with no gap between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      board({
        'a': [Mark.correct, Mark.correct, Mark.correct, Mark.correct],
      }, Brightness.dark),
    );
    final key = tester.getRect(find.byKey(const ValueKey('quad-a')));
    expect(key.width, greaterThan(20));
    expect(key.height, 46);
    // one painter covering the whole key, quarters of equal size
    final p = painter(tester, 'a');
    expect(p.colors.length, 4);
    expect(p.colors.toSet().length, 1);
  });

  testWidgets('a tap on a split key still types its letter', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: LetterKeyboard(
            letters: {'a', 'b'},
            quadMarks: {
              'a': [Mark.absent, null, null, null],
            },
            onLetter: typed.add,
            onEnter: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('a'));
    expect(typed, ['a']);
  });
}
