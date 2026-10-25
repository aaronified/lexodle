import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/licences_page.dart';

Future<List<PackageLicence>> _fake() async => [
  for (final n in [
    'archive',
    'async',
    'bloc',
    'characters',
    'clock',
    'collection',
    'crypto',
    'dio',
    'flutter',
    'flutter_svg',
    'http',
    'html',
    'JetBrains Mono (font)',
    'meta',
    'ota_update',
    'path',
    'shared_preferences',
    'Tabler Icons',
    'url_launcher',
    'vector_math',
    'xml',
    '_private',
    '7zip',
  ])
    PackageLicence(n, ['the licence text of $n']),
];

void main() {
  Future<void> open(
    WidgetTester tester, {
    String about = 'about the app',
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: LicencesPage(about: about, load: _fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the licences page', () {
    testWidgets('shows the about text, a search box, and the count', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('about the app'), findsOneWidget);
      expect(find.byKey(const ValueKey('licences-search')), findsOneWidget);
      expect(find.text('23 of 23'), findsOneWidget);
    });

    testWidgets('lists the packages A to Z with a heading for each letter', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('licence-header-A')), findsOneWidget);
      final a = tester.getTopLeft(
        find.byKey(const ValueKey('licence-tile-archive')),
      );
      final b = tester.getTopLeft(
        find.byKey(const ValueKey('licence-tile-async')),
      );
      expect(b.dy, greaterThan(a.dy), reason: 'archive before async');
      // case does not matter in the order: JetBrains is filed under J
      // (checked through the strip below); numbers and underscores under #
    });

    testWidgets('typing in the search filters by name, ignoring case', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('licences-search')),
        'FLUTTER',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('licence-tile-flutter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('licence-tile-flutter_svg')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('licence-tile-archive')), findsNothing);
      expect(find.text('2 of 23'), findsOneWidget);
      // the strip follows the results: only F is left
      expect(find.byKey(const ValueKey('licences-index-F')), findsOneWidget);
      expect(find.byKey(const ValueKey('licences-index-A')), findsNothing);
    });

    testWidgets('a search with no match says so, and the cross clears it', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('licences-search')),
        'zzzz',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('licences-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('licences-index')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('licences-search-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('licences-empty')), findsNothing);
      expect(find.text('23 of 23'), findsOneWidget);
    });

    testWidgets('the strip has a letter for each heading, # for the rest', (
      tester,
    ) async {
      await open(tester);
      for (final l in [
        'A',
        'B',
        'C',
        'D',
        'F',
        'H',
        'J',
        'M',
        'O',
        'P',
        'S',
        'T',
        'U',
        'V',
        'X',
        '#',
      ]) {
        expect(
          find.byKey(ValueKey('licences-index-$l')),
          findsOneWidget,
          reason: l,
        );
      }
      expect(find.byKey(const ValueKey('licences-index-E')), findsNothing);
    });

    testWidgets('touching a letter jumps the list there and shows a bubble', (
      tester,
    ) async {
      await open(tester);
      final list = find.byKey(const ValueKey('licences-list'));
      expect(find.byKey(const ValueKey('licence-tile-xml')), findsNothing);
      // press on the X of the strip (hold: the bubble shows while touched)
      final x = tester.getCenter(
        find.byKey(const ValueKey('licences-index-X')),
      );
      final g = await tester.startGesture(x);
      await tester.pump();
      expect(find.byKey(const ValueKey('licences-bubble')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('licences-bubble')),
          matching: find.text('X'),
        ),
        findsOneWidget,
      );
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('licences-bubble')), findsNothing);
      expect(find.byKey(const ValueKey('licence-tile-xml')), findsOneWidget);
      expect(list, findsOneWidget);
    });

    testWidgets('sliding along the strip moves through the letters', (
      tester,
    ) async {
      await open(tester);
      final top = tester.getCenter(
        find.byKey(const ValueKey('licences-index-A')),
      );
      final bottom = tester.getCenter(
        find.byKey(const ValueKey('licences-index-X')),
      );
      final g = await tester.startGesture(top);
      await tester.pump();
      await g.moveTo(Offset(top.dx, (top.dy + bottom.dy) / 2));
      await tester.pump();
      final mid = find.descendant(
        of: find.byKey(const ValueKey('licences-bubble')),
        matching: find.byType(Text),
      );
      final midLetter = tester.widget<Text>(mid).data!;
      expect(midLetter, isNot('A'));
      expect(midLetter, isNot('X'));
      await g.moveTo(bottom);
      await tester.pump();
      expect(tester.widget<Text>(mid).data, anyOf('X', '#', 'V', 'U'));
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('licences-bubble')), findsNothing);
    });

    testWidgets('a package opens its licence text', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('licence-tile-bloc')));
      await tester.pumpAndSettle();
      expect(find.text('the licence text of bloc'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('licences-search')), findsOneWidget);
    });

    testWidgets('while the licences are read it says so', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      final never = Future<List<PackageLicence>>.delayed(
        const Duration(days: 1),
        () => const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: LicencesPage(load: () => never)),
      );
      await tester.pump();
      expect(find.text('reading the licences…'), findsOneWidget);
      await tester.pump(const Duration(days: 2));
    });
  });

  group('a package\'s initial', () {
    test('is its first letter in capitals, or # for anything else', () {
      expect(const PackageLicence('archive', []).initial, 'A');
      expect(const PackageLicence('JetBrains Mono', []).initial, 'J');
      expect(const PackageLicence('_x', []).initial, '#');
      expect(const PackageLicence('7zip', []).initial, '#');
      expect(const PackageLicence('', []).initial, '#');
    });
  });
}
