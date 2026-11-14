import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_log.dart';
import 'geography.dart';
import 'place_map.dart';
import 'ui.dart';

/// What English Wikipedia says about a place.
class PlaceSummary {
  const PlaceSummary({
    this.description = '',
    this.extract = '',
    this.image,
    this.lat,
    this.lon,
    this.url,
  });
  final String description;
  final String extract;
  final String? image;
  final double? lat;
  final double? lon;
  final String? url;
}

const _maxExtract = 280;

/// [text] cut to at most two sentences and 280 characters, at a sentence end
/// (at a word when the first sentence alone is longer).
String shortenExtract(String text) {
  final t = text.trim();
  if (t.length <= _maxExtract && RegExp(r'[.!?]\s').allMatches(t).length < 2) {
    return t;
  }
  final parts = t.split(RegExp(r'(?<=[.!?])\s+'));
  var out = '';
  for (final s in parts.take(2)) {
    final next = out.isEmpty ? s : '$out $s';
    if (next.length > _maxExtract) break;
    out = next;
  }
  if (out.isNotEmpty) return out;
  final cut = t.substring(0, _maxExtract - 1);
  final sp = cut.lastIndexOf(' ');
  return '${(sp > 0 ? cut.substring(0, sp) : cut).trimRight()}…';
}

/// The summary a Wikipedia REST summary [json] holds; null for a
/// disambiguation page, which says nothing about one place.
PlaceSummary? parsePlaceSummary(Map<String, dynamic> json) {
  if (json['type'] == 'disambiguation') return null;
  String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
  final coords = json['coordinates'];
  final image =
      str((json['thumbnail'] as Map?)?['source']) ??
      str((json['originalimage'] as Map?)?['source']);
  return PlaceSummary(
    description: str(json['description']) ?? '',
    extract: shortenExtract(str(json['extract']) ?? ''),
    image: image,
    lat: coords is Map ? (coords['lat'] as num?)?.toDouble() : null,
    lon: coords is Map ? (coords['lon'] as num?)?.toDouble() : null,
    url: str(((json['content_urls'] as Map?)?['desktop'] as Map?)?['page']),
  );
}

typedef PlaceFetcher = Future<PlaceSummary?> Function(Place place);

/// Asks English Wikipedia for a place's summary, once per place.
class PlaceWiki {
  PlaceWiki({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// The one the app asks. Tests put one with a fake client here.
  static PlaceWiki shared = PlaceWiki();

  final _cache = <String, Future<PlaceSummary?>>{};

  /// The summary of [place], or null when there is none or Wikipedia cannot be
  /// reached (a failure is not remembered). Never throws.
  Future<PlaceSummary?> lookup(Place place) {
    final hit = _cache[place.key];
    if (hit != null) return hit;
    final run = _fetch(place);
    run.then<void>((s) {
      if (s == null) _cache.remove(place.key);
    });
    return _cache[place.key] = run;
  }

  Future<PlaceSummary?> _fetch(Place place) async {
    try {
      PlaceSummary? s;
      if (place.wiki.isNotEmpty) s = await _summary(place.wiki);
      if (s == null) {
        final q = '${place.name} ${place.country}'.trim();
        final title = await _search(q);
        if (title != null) {
          s = await _summary(Uri.encodeComponent(title));
        }
      }
      return s;
    } catch (e) {
      appLog.w('place', 'the summary could not be fetched: ${e.runtimeType}');
      return null;
    }
  }

  /// Null on a 404 or a disambiguation; throws on any other failure.
  Future<PlaceSummary?> _summary(String title) async {
    final r = await _client
        .get(
          Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title'),
        )
        .timeout(const Duration(seconds: 6));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw http.ClientException('status');
    return parsePlaceSummary(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<String?> _search(String q) async {
    final r = await _client
        .get(
          Uri.https('en.wikipedia.org', '/w/rest.php/v1/search/title', {
            'q': q,
            'limit': '1',
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final pages = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final key = (pages.first as Map)['key'];
    return key is String && key.isNotEmpty ? key : null;
  }
}

/// What the answer of a geography game is: Wikipedia's line about it, a photo,
/// a short extract and a locator map, each when there is one. Every failure
/// degrades to the kind and country with the link.
class PlaceInfoView extends StatefulWidget {
  const PlaceInfoView({super.key, required this.place, this.fetcher});
  final Place place;
  final PlaceFetcher? fetcher;

  @override
  State<PlaceInfoView> createState() => _PlaceInfoViewState();
}

class _PlaceInfoViewState extends State<PlaceInfoView> {
  late final Future<PlaceSummary?> _future = _load();

  Future<PlaceSummary?> _load() async {
    try {
      return await (widget.fetcher ?? PlaceWiki.shared.lookup)(widget.place);
    } catch (e) {
      appLog.w('place', 'the place info failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = widget.place;
    return FutureBuilder<PlaceSummary?>(
      future: _future,
      builder: (context, snap) {
        final s = snap.connectionState == ConnectionState.done
            ? snap.data
            : null;
        final fallback = [
          p.kind,
          if (p.country.isNotEmpty) p.country,
        ].join(' · ');
        final line = s != null && s.description.isNotEmpty
            ? s.description
            : fallback;
        final lat = s?.lat, lon = s?.lon;
        final url = s?.url == null ? p.link : Uri.parse(s!.url!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line,
              key: const ValueKey('place-line'),
              style: TextStyle(fontSize: 13, color: c.primary),
            ),
            if (s?.image != null) ...[
              const SizedBox(height: 10),
              Semantics(
                label: 'photo of ${p.name}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.fromBorderSide(hairline(c)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      s!.image!,
                      key: const ValueKey('place-photo'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
            if (s != null && s.extract.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                s.extract,
                key: const ValueKey('place-extract'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (lat != null && lon != null) ...[
              const SizedBox(height: 10),
              PlaceMap(lat: lat, lon: lon, kind: p.kind, name: p.name),
            ],
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('place-link'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              onPressed: () async {
                try {
                  await launchUrl(url);
                } catch (e) {
                  appLog.w('place', 'the link did not open: ${e.runtimeType}');
                }
              },
              child: Text('wikipedia ↗', style: TextStyle(color: c.primary)),
            ),
          ],
        );
      },
    );
  }
}
