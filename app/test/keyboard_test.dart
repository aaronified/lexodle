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
    // a phone: 2 dp beside the row, 2 dp round each key
    expect(last.dx - first.dx, closeTo(420 - 4 - 4, 3));
  });

  testWidgets('a language with no extra letters has no extra row', (
    tester,
  ) async {
    await show(tester, latin.split('').toSet());
    expect(find.text('à'), findsNothing);
    // the three letter rows only
    expect(tester.takeException(), isNull);
  });

  testWidgets('a key not tried yet is outlined, not filled', (tester) async {
    await show(tester, latin.split('').toSet());
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('q'),
              matching: find.byType(InkWell),
            ),
            matching: find.byType(Container),
          )
          .first,
    );
    final d = box.decoration! as BoxDecoration;
    expect(d.color, isNull);
    expect(d.border, isNotNull);
  });

  group('a key under the finger', () {
    Future<void> shown(WidgetTester tester, {bool popups = true}) async {
      await tester.binding.setSurfaceSize(const Size(420, 700));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: LetterKeyboard(
                letters: latin.split('').toSet(),
                onLetter: (_) {},
                onEnter: () {},
                onBack: () {},
                onBlank: () {},
                popups: popups,
              ),
            ),
          ),
        ),
      );
    }

    final popup = find.byKey(const ValueKey('key-popup'));

    testWidgets('a letter shows a popup with its letter, gone when let go', (
      tester,
    ) async {
      await shown(tester);
      expect(popup, findsNothing);
      final g = await tester.startGesture(tester.getCenter(find.text('g')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(popup, findsOneWidget);
      expect(
        find.descendant(of: popup, matching: find.text('g')),
        findsOneWidget,
      );
      // above the key it was pressed on
      expect(
        tester.getCenter(popup).dy,
        lessThan(tester.getCenter(find.text('g').first).dy),
      );
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(popup, findsNothing);
    });

    testWidgets('the key at the edge keeps its popup on the screen', (
      tester,
    ) async {
      await shown(tester);
      final g = await tester.startGesture(tester.getCenter(find.text('q')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(popup, findsOneWidget);
      expect(tester.getTopLeft(popup).dx, greaterThanOrEqualTo(4));
      await g.up();
      await tester.pump();
    });

    testWidgets('enter, delete and the space sink without a popup', (
      tester,
    ) async {
      await shown(tester);
      for (final label in ['enter', '_']) {
        final f = find.text(label);
        if (f.evaluate().isEmpty) continue;
        final g = await tester.startGesture(tester.getCenter(f.first));
        await tester.pump(const Duration(milliseconds: 200));
        expect(popup, findsNothing, reason: label);
        await g.up();
        await tester.pump();
      }
    });

    testWidgets('with popups off nothing shows, the key still works', (
      tester,
    ) async {
      await shown(tester, popups: false);
      final g = await tester.startGesture(tester.getCenter(find.text('g')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(popup, findsNothing);
      await g.up();
      await tester.pump();
    });
  });
}
