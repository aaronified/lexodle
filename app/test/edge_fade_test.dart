import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/edge_fade.dart';

void main() {
  Future<void> show(WidgetTester tester, double contentWidth) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: EdgeFade(
              scrollKey: const ValueKey('scroll'),
              child: SizedBox(width: contentWidth, height: 20),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  EdgeFadeState state(WidgetTester t) => t.state(find.byType(EdgeFade));

  testWidgets('nothing to scroll: no fade at either end', (tester) async {
    await show(tester, 100);
    expect(state(tester).fadeLeft, isFalse);
    expect(state(tester).fadeRight, isFalse);
  });

  testWidgets(
    'more to the right only at the start, to the left only at the end',
    (tester) async {
      await show(tester, 600);
      expect(state(tester).fadeLeft, isFalse);
      expect(state(tester).fadeRight, isTrue);
      await tester.drag(
        find.byKey(const ValueKey('scroll')),
        const Offset(-150, 0),
      );
      await tester.pump();
      expect(state(tester).fadeLeft, isTrue);
      expect(state(tester).fadeRight, isTrue);
      await tester.drag(
        find.byKey(const ValueKey('scroll')),
        const Offset(-900, 0),
      );
      await tester.pump();
      expect(state(tester).fadeLeft, isTrue);
      expect(state(tester).fadeRight, isFalse);
    },
  );
}
