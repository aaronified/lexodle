import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'precomputed.dart';
import 'app_log.dart';

/// The precomputed openings kept on this device: the lists the player chose to
/// download in the settings. They are read by the analysis as the openings it
/// would have kept itself, and are never trimmed with them.
class PrecomputedLocal {
  const PrecomputedLocal._();

  static bool get supported => true;

  /// The folder: the app's own files on Android (the cache folder is the
  /// system's to empty), the temporary folder elsewhere.
  static Directory dir = Platform.isAndroid
      ? Directory(
          '${Directory.systemTemp.parent.path}/files/lexodle-precomputed',
        )
      : Directory('${Directory.systemTemp.path}/lexodle-precomputed');

  static File _file(String sub, String name) => File('${dir.path}/$sub/$name');

  static Uint8List? readOpening(String name) {
    try {
      final f = _file('openings', '$name.bin');
      return f.existsSync() ? f.readAsBytesSync() : null;
    } catch (_) {
      return null;
    }
  }

  static String? readTree(String name) {
    try {
      final f = _file('trees', '$name.json');
      return f.existsSync() ? f.readAsStringSync() : null;
    } catch (_) {
      return null;
    }
  }

  /// The lists downloaded, with the generation of the files they came from.
  static Map<String, String> downloaded() {
    try {
      final f = File('${dir.path}/lists.json');
      if (!f.existsSync()) return {};
      final j = jsonDecode(f.readAsStringSync()) as Map;
      return {for (final e in j.entries) e.key as String: e.value as String};
    } catch (_) {
      return {};
    }
  }

  static void _remember(Map<String, String> lists) {
    dir.createSync(recursive: true);
    File('${dir.path}/lists.json').writeAsStringSync(jsonEncode(lists));
  }

  /// What the downloaded files take up, in bytes.
  static int size() {
    try {
      if (!dir.existsSync()) return 0;
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .fold(0, (t, f) => t + f.lengthSync());
    } catch (_) {
      return 0;
    }
  }

  /// Downloads [lists] of [manifest]; [onProgress] gets the share done, 0 to
  /// 1. Returns whether every file came; a list that did not is not kept as
  /// downloaded (what did come stays, and is only ever right).
  static Future<bool> download(
    PrecomputedManifest manifest,
    Iterable<String> lists, {
    void Function(double done)? onProgress,
  }) async {
    final wanted = [for (final l in lists) ...manifest.of(l)];
    final total = wanted.fold<int>(0, (t, f) => t + f.size);
    var done = 0;
    final have = downloaded();
    var allCame = true;
    try {
      for (final l in lists) {
        var ok = true;
        for (final f in manifest.of(l)) {
          final bin = await fetchPrecomputedOpening(f.key);
          final tree = await fetchPrecomputedTree(f.key);
          if (bin == null) {
            ok = false;
          } else {
            _file('openings', '${f.name}.bin')
              ..createSync(recursive: true)
              ..writeAsBytesSync(bin);
            if (tree != null) {
              _file('trees', '${f.name}.json')
                ..createSync(recursive: true)
                ..writeAsStringSync(jsonEncode(tree));
            }
          }
          done += f.size;
          onProgress?.call(total == 0 ? 1 : done / total);
        }
        if (ok) {
          have[l] = manifest.generated;
        } else {
          allCame = false;
        }
      }
      _remember(have);
    } catch (_) {
      return false;
    }
    return allCame;
  }

  /// Deletes everything downloaded.
  static void remove() {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      appLog.w(
        'precomputed',
        'the downloaded lists could not be removed: ${e.runtimeType}',
      );
    }
  }
}
