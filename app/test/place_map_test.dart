import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/place_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('half widths by kind', () {
    expect(mapHalfWidth('river'), 8);
    expect(mapHalfWidth('city'), 8);
    expect(mapHalfWidth('region'), 20);
    expect(mapHalfWidth('country'), 35);
    expect(mapHalfWidth('desert'), 35);
    expect(mapHalfWidth('strait'), 15);
  });

  test('the centre maps to the middle of the box, edges to its sides', () {
    const size = Size(200, 100);
    expect(projectPoint(10, 20, 10, 20, 8, size), const Offset(100, 50));
    expect(projectPoint(18, 24, 10, 20, 8, size), const Offset(200, 0));
    expect(projectPoint(2, 16, 10, 20, 8, size), const Offset(0, 100));
  });

  test('a point across the antimeridian is one world away', () {
    const size = Size(200, 100);
    final a = projectPoint(-179, 0, 179, 0, 8, size);
    final b = projectPoint(-179 + 360, 0, 179, 0, 8, size);
    expect(a.dx, lessThan(0));
    expect(b.dx, inInclusiveRange(0, 200));
  });

  test('decodes delta-encoded arcs, reversed arcs and joined rings', () {
    final land = decodeLand({
      'transform': {
        'scale': [2, 3],
        'translate': [10, 20],
      },
      'arcs': [
        // (0,0) (1,0) (1,1)
        [
          [0, 0],
          [1, 0],
          [0, 1],
        ],
        // (1,1) (0,1) (0,0): the way back
        [
          [1, 1],
          [-1, 0],
          [0, -1],
        ],
      ],
      'objects': {
        'land': {
          'type': 'GeometryCollection',
          'geometries': [
            {
              'type': 'Polygon',
              'arcs': [
                [0, 1],
              ],
            },
            {
              'type': 'MultiPolygon',
              'arcs': [
                [
                  [~0],
                ],
              ],
            },
          ],
        },
      },
    });
    expect(land.length, 2);
    expect(land[0], const [
      Offset(10, 20),
      Offset(12, 20),
      Offset(12, 23),
      Offset(10, 23),
      Offset(10, 20),
    ]);
    expect(land[1], const [Offset(12, 23), Offset(12, 20), Offset(10, 20)]);
  });

  test('the real asset decodes to many rings in range', () async {
    final raw = await rootBundle.loadString('assets/geography/land-110m.json');
    final land = decodeLand(jsonDecode(raw) as Map<String, dynamic>);
    expect(land.length, greaterThan(100));
    for (final r in land) {
      for (final p in r) {
        expect(p.dx, inInclusiveRange(-180.5, 180.5));
        expect(p.dy, inInclusiveRange(-90.5, 90.5));
      }
    }
  });

  testWidgets('the map has a label, a caption and a 2:1 box', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: PlaceMap(
              lat: 35.68,
              lon: 139.69,
              kind: 'city',
              name: 'tokyo',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => loadLand());
    await tester.pump();
    expect(find.text('35.7, 139.7'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^map: tokyo')), findsOneWidget);
    expect(tester.getSize(find.byType(AspectRatio)), const Size(300, 150));
  });
}
