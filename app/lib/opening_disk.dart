import 'dart:io';
import 'dart:typed_data';

import 'logic.dart';

/// The most the kept openings take up, in bytes: the oldest are deleted first.
const openingDiskCap = 10 * 1024 * 1024;

/// The most openings kept: the ten used last (a language and length, or the
/// equations of a length, each keep one). An older one is worked out again if
/// it is wanted.
const openingDiskKeep = 10;

/// Opening analyses kept as files in the app's cache folder, which the system
/// may also empty: a missing or damaged file is only a miss, and everything
/// here is worked out again when it is. Any failure is ignored.
class DiskOpenings implements OpeningDisk {
  DiskOpenings({
    Directory? dir,
    this.cap = openingDiskCap,
    this.keep = openingDiskKeep,
  }) : dir = dir ?? Directory('${Directory.systemTemp.path}/lexodle-openings');

  final Directory dir;
  final int cap;
  final int keep;

  File _file(String key) => File(
    '${dir.path}/${key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.bin',
  );

  @override
  Uint8List? read(String key) {
    try {
      final f = _file(key);
      if (!f.existsSync()) return null;
      final bytes = f.readAsBytesSync();
      f.setLastModifiedSync(DateTime.now()); // used lately: deleted last
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, Uint8List bytes) {
    try {
      dir.createSync(recursive: true);
      _file(key).writeAsBytesSync(bytes, flush: true);
      _trim();
    } catch (_) {}
  }

  void _trim() {
    final files = [
      for (final e in dir.listSync())
        if (e is File) (e, e.statSync()),
    ]..sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var total = files.fold<int>(0, (t, f) => t + f.$2.size);
    var count = files.length;
    // oldest first, until there are few enough and they are small enough
    for (final (f, s) in files) {
      if (total <= cap && count <= keep) break;
      f.deleteSync();
      total -= s.size;
      count--;
    }
  }
}
