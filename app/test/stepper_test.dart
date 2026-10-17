import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/stepper_choice.dart';

const _items = <(int, String, String?)>[
  (1, 'off', 'nothing until the end'),
  (2, 'skill only', 'skill after each guess'),
  (3, 'skill + luck', 'skill and luck'),
  (4, 'full help', 'everything'),
];

/// A slider that keeps its own selection, like the home screen's does.
class _Host extends StatefulWidget {
  const _Host({required this.log, this.start = 2});
  final List<int> log;
  final int start;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int value = widget.start;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: StepperChoice<int>(
            items: _items,
            selected: value,
            onChanged: (v) {
              widget.log.add(v);
              setState(() => value = v);
            },
          ),
        ),
      ),
    ),
  );
}

final _viewport = find.byKey(const ValueKey('step-viewport'));
IconButton _chevron(WidgetTester t, String tip) => t.widget<IconButton>(
  find.widgetWithIcon(
    IconButton,
    tip == 'next' ? Icons.chevron_right : Icons.chevron_left,
  ),
);

double _opacity(WidgetTester t, String key) =>
    t.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

void main() {
  testWidgets('shows the label and its subtitle, and a dot per position', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(log: []));
    expect(find.text('skill only'), findsOneWidget);
    expect(find.text('skill after each guess'), findsOneWidget);
    expect(find.text('off'), findsNothing); // one at a time
  });

  testWidgets('the chevrons step, and dim at the ends', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log, start: 1));
    expect(_chevron(tester, 'prev').onPressed, isNull); // first: nothing before
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('skill only'), findsOneWidget);
    expect(log, [2]);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.tap(find.byIcon(Icons.chevron_right), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('full help'), findsOneWidget);
    expect(_chevron(tester, 'next').onPressed, isNull); // last: nothing after
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('skill + luck'), findsOneWidget);
  });

  testWidgets(
    'a drag moves the value with the pointer: out fades, next fades in',
    (tester) async {
      final log = <int>[];
      await tester.pumpWidget(_Host(log: log));
      final g = await tester.startGesture(tester.getCenter(_viewport));
      // the first movement only gets past the touch slop; the next ones drag
      await g.moveBy(const Offset(-40, 0));
      await g.moveBy(const Offset(-40, 0));
      await tester.pump();

      // part-way: the current value has slid left and faded, its neighbour is
      // arriving from the right and fading up
      final current = _opacity(tester, 'step-current');
      final incoming = _opacity(tester, 'step-incoming');
      expect(current, inExclusiveRange(0.0, 1.0));
      expect(incoming, inExclusiveRange(0.0, 1.0));
      expect(current + incoming, closeTo(1, .001));
      expect(
        find.text('skill + luck'),
        findsOneWidget,
      ); // the next one is on its way in
      final cx = tester.getCenter(find.text('skill only')).dx;
      final nx = tester.getCenter(find.text('skill + luck')).dx;
      expect(cx, lessThan(tester.getCenter(_viewport).dx));
      expect(nx, greaterThan(cx));

      await g.moveBy(const Offset(-80, 0));
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [3]); // dragged past the threshold: stepped to the next
      expect(find.text('skill + luck'), findsOneWidget);
    },
  );

  testWidgets('a short drag settles back and changes nothing', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log));
    final g = await tester.startGesture(tester.getCenter(_viewport));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('skill only'), findsOneWidget);
    expect(_opacity(tester, 'step-current'), 1);
  });

  testWidgets('a quick swipe steps either way', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log));
    await tester.fling(
      _viewport,
      const Offset(-60, 0),
      1500,
    ); // swipe left: next
    await tester.pumpAndSettle();
    expect(log, [3]);
    await tester.fling(
      _viewport,
      const Offset(60, 0),
      1500,
    ); // swipe right: previous
    await tester.pumpAndSettle();
    expect(log, [3, 2]);
  });

  testWidgets('dragging past an end pulls against a band and does not step', (
    tester,
  ) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log, start: 4)); // the last one
    final g = await tester.startGesture(tester.getCenter(_viewport));
    await g.moveBy(const Offset(-120, 0));
    await tester.pump();
    // nothing to bring in, and the pull is resisted
    expect(find.byKey(const ValueKey('step-incoming')), findsNothing);
    final moved =
        (tester.getCenter(find.text('full help')).dx -
                tester.getCenter(_viewport).dx)
            .abs();
    expect(moved, lessThan(60));
    await g.up();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('full help'), findsOneWidget);
  });

  testWidgets('sideways scrolling steps; plain vertical scrolling does not', (
    tester,
  ) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(_viewport)));

    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    await tester.pumpAndSettle();
    expect(log, isEmpty, reason: 'vertical wheel is left for the page');

    await tester.sendEventToBinding(mouse.scroll(const Offset(80, 0)));
    await tester.pumpAndSettle();
    expect(log, [3]);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendEventToBinding(mouse.scroll(const Offset(-80, 0)));
    await tester.pumpAndSettle();
    expect(log, [3, 2]);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 80)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(log, [3, 2, 3], reason: 'shift + wheel scrolls sideways');
  });

  testWidgets('after a click the arrow keys step', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_Host(log: log));
    await tester.tap(_viewport);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(log, [3, 2]);
  });
}
