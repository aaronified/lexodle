import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';
import 'ui.dart';

/// Half the width, in degrees of longitude, of the map around a place of this
/// [kind]: a river or a city needs a close view, a country or a sea a wide one.
double mapHalfWidth(String kind) => switch (kind) {
  'river' ||
  'lake' ||
  'lakes' ||
  'bay' ||
  'mountain' ||
  'mountains' ||
  'peak' ||
  'hill' ||
  'city' ||
  'capital' ||
  'town' ||
  'island' ||
  'islands' ||
  'cape' ||
  'valley' ||
  'point' ||
  'pass' ||
  'volcano' ||
  'waterfall' ||
  'cliff' ||
  'beach' ||
  'atoll' ||
  'reef' ||
  'oasis' => 8,
  'region' || 'state' || 'province' => 20,
  'country' || 'sea' || 'ocean' || 'continent' || 'desert' => 35,
  _ => 15,
};

/// The land of a TopoJSON topology (Natural Earth, as the world-atlas package
/// ships it) as rings of (longitude, latitude) points. Arcs are delta-encoded
/// and scaled by the topology's `transform`; a negative arc index `~i` is arc
/// `i` read backwards.
List<List<Offset>> decodeLand(Map<String, dynamic> topo) {
  final t = topo['transform'] as Map<String, dynamic>?;
  final scale = [
    for (final v in t?['scale'] ?? [1, 1]) (v as num).toDouble(),
  ];
  final move = [
    for (final v in t?['translate'] ?? [0, 0]) (v as num).toDouble(),
  ];
  final arcs = <List<Offset>>[];
  for (final a in topo['arcs'] as List) {
    var x = 0.0, y = 0.0;
    final pts = <Offset>[];
    for (final p in a as List) {
      x += (p[0] as num).toDouble();
      y += (p[1] as num).toDouble();
      pts.add(Offset(x * scale[0] + move[0], y * scale[1] + move[1]));
    }
    arcs.add(pts);
  }
  List<Offset> ring(List indexes) {
    final out = <Offset>[];
    for (final i in indexes) {
      final n = i as int;
      final pts = n >= 0 ? arcs[n] : arcs[~n].reversed.toList();
      out.addAll(out.isEmpty ? pts : pts.skip(1));
    }
    return out;
  }

  final rings = <List<Offset>>[];
  final geoms = (topo['objects']['land']['geometries'] as List);
  for (final g in geoms) {
    final type = g['type'];
    if (type == 'Polygon') {
      for (final r in g['arcs'] as List) {
        rings.add(ring(r as List));
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in g['arcs'] as List) {
        for (final r in poly as List) {
          rings.add(ring(r as List));
        }
      }
    }
  }
  return rings;
}

/// Where (lon, lat) falls in a box of [size] centred on ([lon0], [lat0]) with
/// [half] degrees of longitude either side and half of that of latitude.
Offset projectPoint(
  double lon,
  double lat,
  double lon0,
  double lat0,
  double half,
  Size size,
) => Offset(
  size.width / 2 + (lon - lon0) / half * size.width / 2,
  size.height / 2 - (lat - lat0) / (half / 2) * size.height / 2,
);

Future<List<List<Offset>>>? _land;

/// The land, decoded once. Empty when the asset cannot be read.
Future<List<List<Offset>>> loadLand() => _land ??= () async {
  try {
    final raw = await rootBundle.loadString('assets/geography/land-110m.json');
    return decodeLand(jsonDecode(raw) as Map<String, dynamic>);
  } catch (e) {
    appLog.w('map', 'the land could not be read: ${e.runtimeType}');
    return const <List<Offset>>[];
  }
}();

/// An offline locator map: the land around a point, no tiles, no network.
class PlaceMap extends StatelessWidget {
  const PlaceMap({
    super.key,
    required this.lat,
    required this.lon,
    required this.kind,
    this.name = '',
  });
  final double lat;
  final double lon;
  final String kind;

  /// Only for the screen reader.
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'map: $name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: 2,
              child: FutureBuilder<List<List<Offset>>>(
                future: loadLand(),
                builder: (context, snap) => CustomPaint(
                  painter: _MapPainter(
                    land: snap.data ?? const [],
                    lat: lat,
                    lon: lon,
                    half: mapHalfWidth(kind),
                    scheme: c,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${lat.toStringAsFixed(1)}, ${lon.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 10,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.land,
    required this.lat,
    required this.lon,
    required this.half,
    required this.scheme,
  });
  final List<List<Offset>> land;
  final double lat;
  final double lon;
  final double half;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainerHighest,
    );
    final landPaint = Paint()..color = scheme.onSurface.withValues(alpha: .25);
    final loW = lon - half, hiW = lon + half;
    final loH = lat - half / 2, hiH = lat + half / 2;
    // the land again a world to the east and to the west, for a view across
    // the antimeridian
    for (final shift in const [-360.0, 0.0, 360.0]) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final r in land) {
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
        for (final p in r) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        if (maxX + shift < loW ||
            minX + shift > hiW ||
            maxY < loH ||
            minY > hiH) {
          continue;
        }
        for (var i = 0; i < r.length; i++) {
          final q = projectPoint(
            r[i].dx + shift,
            r[i].dy,
            lon,
            lat,
            half,
            size,
          );
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        path.close();
      }
      canvas.drawPath(path, landPaint);
    }
    final grid = Paint()
      ..color = hairlineColor(scheme).withValues(alpha: .5)
      ..strokeWidth = hairlineWidth
      ..style = PaintingStyle.stroke;
    for (var g = (loW / 10).ceil() * 10; g <= hiW; g += 10) {
      final x = projectPoint(g.toDouble(), lat, lon, lat, half, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var g = (loH / 10).ceil() * 10; g <= hiH; g += 10) {
      final y = projectPoint(lon, g.toDouble(), lon, lat, half, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final mark = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(mark, 3.5, Paint()..color = scheme.primary);
    canvas.drawCircle(
      mark,
      7,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.land != land ||
      old.lat != lat ||
      old.lon != lon ||
      old.half != half ||
      old.scheme != scheme;
}
