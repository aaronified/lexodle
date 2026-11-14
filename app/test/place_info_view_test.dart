import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/place_info_view.dart';
import 'package:lexodle/place_map.dart';

const _place = Place('fuji', 'Mount Fuji', 'mountain', 'Japan', 'Mount_Fuji');
const _summary = {
  'type': 'standard',
  'description': 'Mountain in Honshu, Japan',
  'extract': 'Mount Fuji is the highest mountain in Japan. It is 3776 m.',
  'thumbnail': {'source': 'https://upload.wikimedia.org/x.jpg'},
  'coordinates': {'lat': 35.36, 'lon': 138.73},
  'content_urls': {
    'desktop': {'page': 'https://en.wikipedia.org/wiki/Mount_Fuji'},
  },
};

http.Response _json(Object o, [int code = 200]) => http.Response(
  jsonEncode(o),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parsing', () {
    test('a normal summary', () {
      final s = parsePlaceSummary(_summary)!;
      expect(s.description, 'Mountain in Honshu, Japan');
      expect(s.image, 'https://upload.wikimedia.org/x.jpg');
      expect(s.lat, 35.36);
      expect(s.lon, 138.73);
      expect(s.url, 'https://en.wikipedia.org/wiki/Mount_Fuji');
    });

    test('no thumbnail falls back to the original image, then none', () {
      final o = parsePlaceSummary({
        'originalimage': {'source': 'https://upload.wikimedia.org/o.jpg'},
      })!;
      expect(o.image, 'https://upload.wikimedia.org/o.jpg');
      expect(parsePlaceSummary({'extract': 'a.'})!.image, isNull);
    });

    test('no coordinates', () {
      final s = parsePlaceSummary({'extract': 'A place.'})!;
      expect(s.lat, isNull);
      expect(s.lon, isNull);
    });

    test('a disambiguation is no summary', () {
      expect(parsePlaceSummary({'type': 'disambiguation'}), isNull);
    });

    test('the extract is cut at a sentence end', () {
      expect(shortenExtract('One. Two. Three. Four.'), 'One. Two.');
      final long = '${'word ' * 60}end. Second.';
      final cut = shortenExtract(long);
      expect(cut.length, lessThanOrEqualTo(280));
      expect(shortenExtract('${'a' * 200}. ${'b' * 200}.'), '${'a' * 200}.');
      expect(cut.endsWith('…'), isTrue);
    });
  });

  group('the lookup', () {
    test('asks the page, once per place', () async {
      var calls = 0;
      final wiki = PlaceWiki(
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, endsWith('/summary/Mount_Fuji'));
          return _json(_summary);
        }),
      );
      expect((await wiki.lookup(_place))!.extract, startsWith('Mount Fuji'));
      await wiki.lookup(_place);
      expect(calls, 1);
    });

    test('a disambiguation falls back to the search', () async {
      final paths = <String>[];
      final wiki = PlaceWiki(
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.contains('search/title')) {
            expect(r.url.queryParameters['q'], 'Mount Fuji Japan');
            return _json({
              'pages': [
                {'key': 'Mount_Fuji_(peak)'},
              ],
            });
          }
          return r.url.path.endsWith('Mount_Fuji')
              ? _json({'type': 'disambiguation'})
              : _json(_summary);
        }),
      );
      expect((await wiki.lookup(_place))!.description, isNotEmpty);
      expect(paths.length, 3);
    });

    test('a 404 and an empty wiki search by name', () async {
      const p = Place('fuji', 'Mount Fuji', 'mountain', 'Japan', '');
      final paths = <String>[];
      final wiki = PlaceWiki(
        client: MockClient((r) async {
          paths.add(r.url.path);
          return _json({
            'pages': [],
          }, r.url.path.contains('search') ? 200 : 404);
        }),
      );
      expect(await wiki.lookup(p), isNull);
      expect(paths.length, 1);
      final w2 = PlaceWiki(client: MockClient((r) async => _json({}, 404)));
      expect(await w2.lookup(_place), isNull);
    });

    test('a failed request is null and tried again later', () async {
      var calls = 0;
      final wiki = PlaceWiki(
        client: MockClient((r) async {
          calls++;
          throw http.ClientException('x');
        }),
      );
      expect(await wiki.lookup(_place), isNull);
      await Future<void>.delayed(Duration.zero);
      await wiki.lookup(_place);
      expect(calls, 2);
    });
  });

  group('the view', () {
    Future<void> show(
      WidgetTester tester,
      PlaceFetcher fetcher, {
      Size? size,
    }) async {
      await tester.binding.setSurfaceSize(size ?? const Size(420, 1200));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceInfoView(place: _place, fetcher: fetcher),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows description, photo, extract, map and link', (
      tester,
    ) async {
      await show(tester, (_) async => parsePlaceSummary(_summary));
      expect(find.text('Mountain in Honshu, Japan'), findsOneWidget);
      expect(find.byKey(const ValueKey('place-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('place-extract')), findsOneWidget);
      expect(find.byType(PlaceMap), findsOneWidget);
      expect(find.text('wikipedia ↗'), findsOneWidget);
    });

    testWidgets('no photo, extract or map when the summary has none', (
      tester,
    ) async {
      await show(tester, (_) async => const PlaceSummary(description: 'd'));
      expect(find.byKey(const ValueKey('place-photo')), findsNothing);
      expect(find.byKey(const ValueKey('place-extract')), findsNothing);
      expect(find.byType(PlaceMap), findsNothing);
      expect(find.text('wikipedia ↗'), findsOneWidget);
    });

    testWidgets('a null summary shows kind, country and the link', (
      tester,
    ) async {
      await show(tester, (_) async => null);
      expect(find.text('mountain · Japan'), findsOneWidget);
      expect(find.text('wikipedia ↗'), findsOneWidget);
      expect(find.byType(PlaceMap), findsNothing);
    });

    testWidgets('a fetcher that throws degrades the same way', (tester) async {
      await show(tester, (_) async => throw StateError('x'));
      expect(find.text('mountain · Japan'), findsOneWidget);
      expect(find.text('wikipedia ↗'), findsOneWidget);
    });
  });
}
