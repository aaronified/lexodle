import 'dart:typed_data';

import 'package:lexodle/auto_backup.dart';

/// A fake of the phone's storage for the automatic backups: files in memory,
/// each place that can be made to fail or to be missing.
class FakeBackupFiles implements BackupFiles {
  final internal = <String, Uint8List>{};
  final downloads = <String, Uint8List>{};
  final deleted = <String>[];
  final logs = <String, Uint8List>{};
  final downloadMimes = <String, String>{};
  bool logFails = false;
  bool internalFails = false;
  bool downloadsFails = false;

  /// Before Android 10 there is no way to write to Downloads without a
  /// permission, so the real one answers null.
  bool downloadsSupported = true;

  /// Names in the order they were written, newest last.
  final _order = <String>[];

  @override
  Future<String?> saveToDownloads(
    String name,
    Uint8List bytes, {
    String mime = 'application/json',
  }) async {
    if (downloadsFails) throw StateError('no space');
    if (!downloadsSupported) return null;
    downloads[name] = bytes;
    downloadMimes[name] = mime;
    return name;
  }

  @override
  Future<bool> writeLog(String name, Uint8List bytes) async {
    if (logFails) throw StateError('no space');
    logs[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> readLog(String name) async => logs[name];

  @override
  Future<bool> writeInternal(String name, Uint8List bytes) async {
    if (internalFails) throw StateError('no space');
    internal[name] = bytes;
    _order
      ..remove(name)
      ..add(name);
    return true;
  }

  @override
  Future<List<String>> listInternal() async => [
    for (final n in _order.reversed)
      if (internal.containsKey(n)) n,
  ];

  @override
  Future<Uint8List?> readInternal(String name) async => internal[name];

  @override
  Future<void> deleteInternal(String name) async {
    deleted.add(name);
    internal.remove(name);
  }
}
