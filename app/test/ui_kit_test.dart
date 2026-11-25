import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart' show buildTheme;
import 'package:lexodle/tonal.dart';
import 'package:lexodle/ui_kit.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= .03928 ? v / 12.92 : pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + .05) / (min(x, y) + .05);
}

Widget _app(Widget child, {Ground ground = Ground.night}) => MaterialApp(
  theme: buildTheme(
    ground == Ground.cream ? Brightness.light : Brightness.dark,
    black: ground == Ground.black,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

void main() {
  group('the tonal ramps and the scheme', () {
    test('every text pairing reads at 4.5:1 on every ground', () {
      for (final g in Ground.values) {
        final c = schemeOf(g);
        final t = AppTones.of(g);
        final pairs = <String, (Color, Color)>{
          'text on the page': (c.onSurface, c.surface),
          'dim text on the page': (c.onSurfaceVariant, c.surface),
          'text on a group': (c.onSurface, t.s1),
          'dim text on a group': (c.onSurfaceVariant, t.s1),
          'text on a tile': (c.onSurface, t.s2),
          'on the accent': (c.onPrimary, c.primary),
          'the accent on the page': (c.primary, c.surface),
          'the accent on a group': (c.primary, t.s1),
          'on a selection': (c.onSecondaryContainer, c.secondaryContainer),
          'on a right tile': (c.onSecondary, c.secondary),
          'on an error fill': (c.onErrorContainer, c.errorContainer),
        };
        for (final e in pairs.entries) {
          expect(
            _contrast(e.value.$1, e.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${g.name}: ${e.key}',
          );
        }
      }
    });

    test('the tones rise from the page to the track', () {
      for (final g in Ground.values) {
        final c = schemeOf(g);
        final t = AppTones.of(g);
        final dark = g != Ground.cream;
        final order = [c.surface, t.s1, t.s2, t.s3].map(_lum).toList();
        for (var i = 1; i < order.length; i++) {
          expect(
            dark ? order[i] > order[i - 1] : order[i] < order[i - 1],
            isTrue,
            reason: '${g.name} step $i',
          );
        }
      }
    });
  });

  group('ChoiceSlider', () {
    final items = [
      for (final n in ['one', 'two', 'three'])
        ChoiceItem<String>(value: n, label: n),
    ];

    testWidgets('shows the chosen item, its dots, and moves by the arrows', (
      tester,
    ) async {
      var got = 'one';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('s-dots')),
          matching: find.byType(Container),
        ),
        findsNWidgets(3),
      );
      await tester.tap(find.byKey(const ValueKey('s-next')));
      await tester.pump();
      expect(got, 'two');
      expect(find.text('two'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('s-prev')));
      await tester.pump();
      expect(got, 'one');
    });

    testWidgets('does not wrap: the arrow of an end is off', (tester) async {
      await tester.pumpWidget(
        _app(
          ChoiceSlider<String>(
            id: 's',
            items: items,
            selected: 'one',
            onChanged: (_) {},
          ),
        ),
      );
      IconButton b(String k) =>
          tester.widget<IconButton>(find.byKey(ValueKey(k)));
      expect(b('s-prev').onPressed, isNull);
      expect(b('s-next').onPressed, isNotNull);
      await tester.pumpWidget(
        _app(
          ChoiceSlider<String>(
            id: 's',
            items: items,
            selected: 'three',
            onChanged: (_) {},
          ),
        ),
      );
      expect(b('s-next').onPressed, isNull);
      expect(b('s-prev').onPressed, isNotNull);
    });

    testWidgets('a swipe moves it, left for the next', (tester) async {
      var got = 'two';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      await tester.fling(
        find.byKey(const ValueKey('s')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(got, 'three');
      await tester.fling(
        find.byKey(const ValueKey('s')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(got, 'two');
    });

    testWidgets('the name follows the finger, and the next one comes in', (
      tester,
    ) async {
      var got = 'two';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      final x0 = tester.getCenter(find.text('two')).dx;
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('s'))),
      );
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
      // 60 px of drag: the name has moved with it, nothing is chosen yet
      expect(tester.getCenter(find.text('two')).dx, closeTo(x0 - 60, 1));
      expect(find.text('three'), findsOneWidget);
      expect(got, 'two');
      // let go short of a third of the way: it slides back
      await g.up();
      await tester.pumpAndSettle();
      expect(got, 'two');
      expect(tester.getCenter(find.text('two')).dx, closeTo(x0, 1));
      expect(find.text('three'), findsNothing);
    });

    testWidgets('a drag past a third of the way, slowly, still chooses', (
      tester,
    ) async {
      var got = 'two';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('s'))),
      );
      for (var i = 0; i < 16; i++) {
        await g.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(got, 'one');
    });

    testWidgets('at an end the drag is resisted and nothing is chosen', (
      tester,
    ) async {
      var got = 'one';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      final x0 = tester.getCenter(find.text('one')).dx;
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('s'))),
      );
      await g.moveBy(const Offset(60, 0));
      await g.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(tester.getCenter(find.text('one')).dx, closeTo(x0 + 40, 1));
      await g.up();
      await tester.pumpAndSettle();
      expect(got, 'one');
      expect(tester.getCenter(find.text('one')).dx, closeTo(x0, 1));
    });

    testWidgets('tapping the name opens a popup of the choices; one switches', (
      tester,
    ) async {
      var got = 'one';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => ChoiceSlider<String>(
              id: 's',
              title: 'number',
              items: items,
              selected: got,
              onChanged: (v) => set(() => got = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('s-name')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pick-sheet')), findsOneWidget);
      expect(find.text('number'), findsOneWidget);
      for (final n in ['one', 'two', 'three']) {
        expect(find.byKey(ValueKey('pick-$n')), findsOneWidget);
      }
      // the choice in force shows a check
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-three')));
      await tester.pumpAndSettle();
      expect(got, 'three');
      expect(find.byKey(const ValueKey('pick-sheet')), findsNothing);
      // the close icon leaves it as it is
      await tester.tap(find.byKey(const ValueKey('s-name')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-close')));
      await tester.pumpAndSettle();
      expect(got, 'three');
    });

    testWidgets('one item has no dots and a long name does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            child: ChoiceSlider<int>(
              id: 'x',
              items: const [
                ChoiceItem<int>(
                  value: 1,
                  label: 'a very long name that cannot fit',
                ),
              ],
              selected: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('x-dots')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('GroupedList', () {
    testWidgets('rows are 2 apart, outer corners round, inner ones square', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          GroupedList(
            rows: [
              for (final n in ['a', 'b', 'c'])
                GroupRow(key: ValueKey('r$n'), title: Text(n), onTap: () {}),
            ],
          ),
        ),
      );
      BorderRadius r(String k) =>
          tester.widget<Material>(find.byKey(ValueKey(k))).borderRadius!
              as BorderRadius;
      expect(r('ra').topLeft.x, 12);
      expect(r('ra').bottomLeft.x, 4);
      expect(r('rb').topLeft.x, 4);
      expect(r('rb').bottomLeft.x, 4);
      expect(r('rc').topLeft.x, 4);
      expect(r('rc').bottomLeft.x, 12);
      final gap =
          tester.getTopLeft(find.byKey(const ValueKey('rb'))).dy -
          tester.getBottomLeft(find.byKey(const ValueKey('ra'))).dy;
      expect(gap, 2);
    });

    testWidgets('a lone row is round all over and a tap fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          GroupedList(
            rows: [
              GroupRow(
                key: const ValueKey('only'),
                title: const Text('only'),
                subtitle: const Text('line'),
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      final m = tester.widget<Material>(find.byKey(const ValueKey('only')));
      expect((m.borderRadius! as BorderRadius).bottomRight.x, 12);
      await tester.tap(find.text('only'));
      expect(taps, 1);
    });
  });

  group('PageHeader', () {
    testWidgets('is 16 from the edges and as high as the row', (tester) async {
      await tester.pumpWidget(
        _app(const PageHeader(text: 'today', info: HeaderInfo('wed 25 nov'))),
      );
      expect(
        tester.getSize(find.byType(PageHeader)).height,
        16 + headerRowHeight,
      );
      expect(tester.getTopLeft(find.text('today')).dx, 16);
      expect(find.byKey(const ValueKey('settings-button')), findsOneWidget);
    });

    testWidgets('the title and the cog share one centre line on every page', (
      tester,
    ) async {
      double cy(Finder f) => tester.getCenter(f).dy;
      await tester.pumpWidget(_app(const PageHeader(text: 'today')));
      final a = cy(find.text('today'));
      final cog = cy(find.byKey(const ValueKey('settings-button')));
      expect((a - cog).abs(), lessThan(1));
      await tester.pumpWidget(
        _app(const PageHeader(text: 'learn', info: HeaderInfo('english · 5'))),
      );
      expect(cy(find.text('learn')), closeTo(a, .5));
      expect(
        cy(find.byKey(const ValueKey('settings-button'))),
        closeTo(cog, .5),
      );
    });

    testWidgets('a back arrow pops, and settings can be left out', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: PageHeader(
                      text: 'inner',
                      back: true,
                      settings: false,
                    ),
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-button')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('header-back')));
      await tester.pumpAndSettle();
      expect(find.text('inner'), findsNothing);
    });
  });

  group('FlatTabBar', () {
    testWidgets('the tab on show is bold, the others are not', (tester) async {
      var at = 1;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => Align(
              alignment: Alignment.bottomCenter,
              child: FlatTabBar(
                ids: const ['today', 'words', 'you'],
                icons: const {
                  'today': (Icons.today_outlined, Icons.today),
                  'words': (Icons.menu_book_outlined, Icons.menu_book),
                  'you': (Icons.person_outline, Icons.person),
                },
                selected: at,
                onSelect: (i) => set(() => at = i),
              ),
            ),
          ),
        ),
      );
      FontWeight? w(String t) =>
          tester.widget<Text>(find.text(t)).style!.fontWeight;
      expect(w('words'), FontWeight.w700);
      expect(w('today'), isNull);
      await tester.tap(find.text('you'));
      await tester.pump();
      expect(w('you'), FontWeight.w700);
      expect(w('words'), isNull);
    });
  });
}
