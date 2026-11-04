import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Where the precomputed openings are published: the `precomputed` branch,
/// written by the precompute workflow (see docs/wiki/Developing.md). The web
/// app reads them from here as it needs them; the phone downloads the ones the
/// player chooses, from the settings.
const precomputedBase =
    'https://raw.githubusercontent.com/aaronified/lexodle/precomputed/';

/// The file name an opening is kept under: its key with every character a file
/// name may not have turned into `_` (what the workflow writes).
String openingFileName(String key) =>
    key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// One analysis in the manifest.
class PrecomputedFile {
  const PrecomputedFile({
    required this.key,
    required this.list,
    required this.length,
    required this.bytes,
    required this.treeBytes,
  });

  final String key;

  /// A language code, `equations` or `places`.
  final String list;
  final int length;
  final int bytes;
  final int treeBytes;

  int get size => bytes + treeBytes;
  String get name => openingFileName(key);
}

/// The manifest of the published files: what there is, and how big it is.
class PrecomputedManifest {
  const PrecomputedManifest(this.generated, this.files);

  final String generated;
  final List<PrecomputedFile> files;

  /// The lists there are, with the bytes each takes.
  Map<String, int> get lists {
    final out = <String, int>{};
    for (final f in files) {
      out[f.list] = (out[f.list] ?? 0) + f.size;
    }
    return out;
  }

  int get bytes => files.fold(0, (t, f) => t + f.size);

  List<PrecomputedFile> of(String list) => [
    for (final f in files)
      if (f.list == list) f,
  ];

  static PrecomputedManifest? parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['format'] != 1) return null;
      return PrecomputedManifest(j['generated'] as String? ?? '', [
        for (final f in j['files'] as List)
          PrecomputedFile(
            key: f['key'] as String,
            list: f['list'] as String,
            length: f['length'] as int,
            bytes: f['bytes'] as int,
            treeBytes: f['treeBytes'] as int,
          ),
      ]);
    } catch (_) {
      return null;
    }
  }
}

/// How the files are fetched. Tests give their own client.
http.Client Function() precomputedClient = http.Client.new;

Future<http.Response?> _get(String path) async {
  final client = precomputedClient();
  try {
    final r = await client
        .get(Uri.parse('$precomputedBase$path'))
        .timeout(const Duration(seconds: 30));
    return r.statusCode == 200 ? r : null;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// The manifest, or null when it cannot be had (offline, or nothing published).
Future<PrecomputedManifest?> fetchPrecomputedManifest() async {
  final r = await _get('manifest.json');
  return r == null ? null : PrecomputedManifest.parse(utf8.decode(r.bodyBytes));
}

final _openings = <String, Future<Uint8List?>>{};

/// The kept analysis [key], or null. Asked once for each key in a run.
Future<Uint8List?> fetchPrecomputedOpening(String key) =>
    _openings[key] ??= () async {
      final r = await _get('openings/${openingFileName(key)}.bin');
      return r?.bodyBytes;
    }();

/// The file of the best second guesses [key] has, or null.
Future<Map<String, dynamic>?> fetchPrecomputedTree(String key) async {
  final r = await _get('trees/${openingFileName(key)}.json');
  if (r == null) return null;
  try {
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is Map<String, dynamic> ? j : null;
  } catch (_) {
    return null;
  }
}

/// Forgets what was fetched (for tests).
void forgetPrecomputed() => _openings.clear();
