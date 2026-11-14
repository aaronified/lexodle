import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/diy_controls.dart';

const _items = <(String, String)>[
  ('a', 'alpha'),
  ('b', 'beta'),
  ('c', 'gamma'),
  ('d', 'delta'),
];

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(colorScheme: const ColorScheme.dark()),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

class _Swipe extends StatefulWidget {
  const _Swipe({required this.start, this.refuse = false, required this.log});
  final String start;
  final bool refuse;
  final List<String> log;
  @override
  State<_Swipe> createState() => _SwipeState();
}

class _SwipeState extends State<_Swipe> {
  late String sel = widget.start;
  @override
  Widget build(BuildContext context) => SwipeChoice<String>(
    title: 'rules',
    items: _items,
    selected: sel,
    onChanged: (v) {
      widget.log.add(v);
      if (!widget.refuse) setState(() => sel = v);
    },
  );
}

double _dx(WidgetTester t, String label) => t.getCenter(find.text(label)).dx;

void main() {
  testWidgets('chevrons step and dim at the ends', (t) async {
    final log = <String>[];
    await t.pumpWidget(_app(_Swipe(start: 'a', log: log)));
    // at the first choice the previous chevron does nothing
    await t.tap(find.byKey(const ValueKey('swipe-rules-prev')));
    await t.pumpAndSettle();
    expect(log, isEmpty);
    await t.tap(find.byKey(const ValueKey('swipe-rules-next')));
    await t.pumpAndSettle();
    expect(log, ['b']);
    await t.tap(find.byKey(const ValueKey('swipe-rules-next')));
    await t.tap(find.byKey(const ValueKey('swipe-rules-next')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('swipe-rules-next')));
    await t.pumpAndSettle();
    expect(log, ['b', 'c', 'd']);
    final next = t.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('swipe-rules-next')),
        matching: find.byType(Text),
      ),
    );
    expect(next.style!.color!.a, lessThan(.5));
  });

  testWidgets('a drag changes the selection and stops at the ends', (t) async {
    final log = <String>[];
    await t.pumpWidget(_app(_Swipe(start: 'a', log: log)));
    final box = find.byKey(const ValueKey('swipe-rules'));
    // one slot is 300 - 88 = 212; dragging left by two slots goes two on
    await t.drag(box, const Offset(-424, 0));
    await t.pumpAndSettle();
    expect(log.last, 'c');
    // dragging far further stops at the last, no loop
    await t.drag(box, const Offset(-1500, 0));
    await t.pumpAndSettle();
    expect(log.last, 'd');
    await t.drag(box, const Offset(1500, 0));
    await t.pumpAndSettle();
    expect(log.last, 'a');
  });

  testWidgets('a refusal slides back', (t) async {
    final log = <String>[];
    await t.pumpWidget(_app(_Swipe(start: 'a', refuse: true, log: log)));
    final centre = t.getCenter(find.byKey(const ValueKey('swipe-rules'))).dx;
    await t.drag(
      find.byKey(const ValueKey('swipe-rules')),
      const Offset(-212, 0),
    );
    await t.pumpAndSettle();
    expect(log, ['b']);
    expect((_dx(t, 'alpha') - centre).abs(), lessThan(1));
  });

  testWidgets('line slider shows label and hint and reports the item', (
    t,
  ) async {
    final got = <int>[];
    await t.pumpWidget(
      _app(
        LineSlider<int>(
          title: 'tries',
          items: const [(4, '4', 'hard'), (5, '5', ''), (6, '6', 'normal')],
          selected: 5,
          onChanged: got.add,
        ),
      ),
    );
    expect(find.text('tries'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('hard'), findsNothing);
    await t.drag(
      find.byKey(const ValueKey('slider-tries')),
      const Offset(400, 0),
    );
    await t.pumpAndSettle();
    expect(got.last, 6);
  });

  testWidgets('line slider shows the hint', (t) async {
    await t.pumpWidget(
      _app(
        LineSlider<int>(
          title: 'tries',
          items: const [(4, '4', 'hard'), (5, '5', '')],
          selected: 4,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('hard'), findsOneWidget);
  });

  testWidgets('a disabled line slider ignores drags and reports taps', (
    t,
  ) async {
    final got = <int>[];
    var taps = 0;
    await t.pumpWidget(
      _app(
        LineSlider<int>(
          title: 'hearts',
          items: const [(1, '1', ''), (2, '2', ''), (3, '3', '')],
          selected: 1,
          enabled: false,
          onChanged: got.add,
          onDisabledTap: () => taps++,
        ),
      ),
    );
    await t.drag(
      find.byKey(const ValueKey('slider-hearts')),
      const Offset(400, 0),
    );
    await t.pumpAndSettle();
    expect(got, isEmpty);
    await t.tap(find.text('hearts'));
    expect(taps, 1);
  });

  testWidgets('dropdown box taps', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _app(
        DropdownBox(
          title: 'language',
          child: const Text('en'),
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('language'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dropdown-language')));
    expect(taps, 1);
  });
}
