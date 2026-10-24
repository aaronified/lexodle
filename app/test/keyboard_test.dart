import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/keyboard.dart';

void main() {
  const latin = 'abcdefghijklmnopqrstuvwxyz';

  Future<void> show(WidgetTester tester, Set<String> letters) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LetterKeyboard(
              letters: letters,
              onLetter: (_) {},
              onEnter: () {},
              onBack: () {},
            ),
          ),
        ),
      ),
    );
  }

  /// The width of the key that shows [label].
  double keyWidth(WidgetTester tester, String label) => tester
      .getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      )
      .width;

  testWidgets('a short row of extra letters keeps keys of the usual size', (
    tester,
  ) async {
    // eleven extra letters: a row of ten and a row of one
    await show(tester, {...latin.split(''), ...'àçèéíîïòóúü'.split('')});
    final usual = keyWidth(tester, 'q');
    expect(keyWidth(tester, 'à'), closeTo(usual, 1));
    expect(keyWidth(tester, 'ü'), closeTo(usual, 1));
  });

  testWidgets('and sits in the middle of the keyboard, not at one side', (
    tester,
  ) async {
    await show(tester, {...latin.split(''), ...'àçèéíîïòóúü'.split('')});
    final middle = tester.getCenter(find.text('ü')).dx;
    expect(middle, closeTo(420 / 2, 2));
  });

  testWidgets('a short row of three is centred too', (tester) async {
    await show(tester, {...latin.split(''), 'ä', 'ö', 'ü'});
    final keys = [
      for (final l in ['ä', 'ö', 'ü']) tester.getCenter(find.text(l)).dx,
    ];
    expect((keys.first + keys.last) / 2, closeTo(210, 2));
    expect(keyWidth(tester, 'ä'), closeTo(keyWidth(tester, 'q'), 1));
  });

  testWidgets('a full row of ten fills the width as before', (tester) async {
    await show(tester, {...latin.split(''), ...'àçèéíîïòóú'.split('')});
    final first = tester.getTopLeft(
      find.ancestor(of: find.text('à'), matching: find.byType(InkWell)),
    );
    final last = tester.getTopRight(
      find.ancestor(of: find.text('ú'), matching: find.byType(InkWell)),
    );
    expect(last.dx - first.dx, closeTo(420 - 12 - 5, 3));
  });

  testWidgets('a language with no extra letters has no extra row', (
    tester,
  ) async {
    await show(tester, latin.split('').toSet());
    expect(find.text('à'), findsNothing);
    // the three letter rows only
    expect(tester.takeException(), isNull);
  });
}
