import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'backup.dart';
import 'store.dart';
import 'update_check.dart';
import 'app_log.dart';

/// Where the automatic backups are written. Narrow enough that tests fake it.
abstract interface class BackupFiles {
  /// Saves a copy in the Downloads folder; the name it was saved as, or null
  /// where that cannot be done (before Android 10, or off Android).
  Future<String?> saveToDownloads(
    String name,
    Uint8List bytes, {
    String mime = 'application/json',
  });

  /// The app's log, in a folder of its own (not pruned with the backups).
  Future<bool> writeLog(String name, Uint8List bytes);
  Future<Uint8List?> readLog(String name);

  /// Saves a copy in the app's own storage (kept through an update, not through
  /// a clear of the app's data or an uninstall).
  Future<bool> writeInternal(String name, Uint8List bytes);

  /// The names of the copies in the app's own storage, newest first.
  Future<List<String>> listInternal();
  Future<Uint8List?> readInternal(String name);
  Future<void> deleteInternal(String name);
}

/// The phone's own storage, through a small channel in MainActivity.kt (no
/// plugin, and no permission: the Downloads copy goes through MediaStore).
class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  static const _channel = MethodChannel('io.github.aaronified.lexodle/files');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> saveToDownloads(
    String name,
    Uint8List bytes, {
    String mime = 'application/json',
  }) async {
    if (!supported) return null;
    return _channel.invokeMethod<String>('saveToDownloads', {
      'name': name,
      'bytes': bytes,
      'mime': mime,
    });
  }

  @override
  Future<bool> writeLog(String name, Uint8List bytes) async {
    if (!supported) return false;
    return await _channel.invokeMethod<bool>('writeLog', {
          'name': name,
          'bytes': bytes,
        }) ??
        false;
  }

  @override
  Future<Uint8List?> readLog(String name) async {
    if (!supported) return null;
    return _channel.invokeMethod<Uint8List>('readLog', {'name': name});
  }

  @override
  Future<bool> writeInternal(String name, Uint8List bytes) async {
    if (!supported) return false;
    return await _channel.invokeMethod<bool>('writeInternal', {
          'name': name,
          'bytes': bytes,
        }) ??
        false;
  }

  @override
  Future<List<String>> listInternal() async {
    if (!supported) return const [];
    final names = await _channel.invokeListMethod<String>('listInternal');
    return names ?? const [];
  }

  @override
  Future<Uint8List?> readInternal(String name) async {
    if (!supported) return null;
    return _channel.invokeMethod<Uint8List>('readInternal', {'name': name});
  }

  @override
  Future<void> deleteInternal(String name) async {
    if (!supported) return;
    await _channel.invokeMethod<void>('deleteInternal', {'name': name});
  }
}

/// What a run of the automatic backup managed.
class AutoBackupResult {
  const AutoBackupResult({
    required this.name,
    required this.internal,
    required this.downloads,
  });

  /// The file name used.
  final String name;

  /// Whether a copy was saved in the app's own storage, and in Downloads.
  final bool internal;
  final bool downloads;

  /// Whether any copy was saved at all.
  bool get any => internal || downloads;

  /// Where it went, in words.
  String get where =>
      [if (internal) 'app memory', if (downloads) 'downloads'].join(' and ');
}

/// The automatic backup: a copy of everything the app keeps, saved before an
/// update so a failed or odd install cannot cost the player their history.
class AutoBackup {
  const AutoBackup._();

  /// The storage in use; tests put a fake here.
  static BackupFiles files = const PlatformBackupFiles();

  /// How many automatic copies are kept in the app's own storage.
  static const keep = 5;

  /// The file name for a copy made at [now] for [label] (such as `update`).
  static String nameFor(String label, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    return 'lexodle-backup-$label-v$appVersion-$day-${two(now.hour)}${two(now.minute)}.json';
  }

  /// Saves a copy of [state] in the app's own storage and, when [downloads] is
  /// set, in the Downloads folder. A copy that fails does not stop the other.
  static Future<AutoBackupResult> run(
    AppState state, {
    required bool downloads,
    String label = 'update',
    DateTime? now,
  }) async {
    final name = nameFor(label, now ?? DateTime.now());
    final bytes = Uint8List.fromList(utf8.encode(backupToText(state)));
    var internal = false, saved = false;
    try {
      internal = await files.writeInternal(name, bytes);
      if (internal) await _prune();
    } catch (e) {
      appLog.e('backup', 'could not write $name to app memory: $e');
    }
    if (downloads) {
      try {
        saved = await files.saveToDownloads(name, bytes) != null;
      } catch (e) {
        appLog.e('backup', 'could not write $name to Downloads: $e');
      }
    }
    appLog.i(
      'backup',
      '$label backup ${bytes.length} bytes: app memory $internal, '
          'downloads ${downloads ? saved : 'not asked'}',
    );
    return AutoBackupResult(name: name, internal: internal, downloads: saved);
  }

  /// Keeps the newest [keep] copies in the app's own storage.
  static Future<void> _prune() async {
    try {
      final names = await files.listInternal();
      for (final old in names.skip(keep)) {
        await files.deleteInternal(old);
      }
    } catch (_) {}
  }

  /// The newest copy in the app's own storage: its name and its text, or null.
  static Future<({String name, String text})?> latest() async {
    try {
      final names = await files.listInternal();
      if (names.isEmpty) return null;
      final bytes = await files.readInternal(names.first);
      if (bytes == null) return null;
      return (name: names.first, text: utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  /// The first start of a new version: keeps a copy of what the new version
  /// found, in the app's own storage, when there is anything to keep. (An update
  /// that clears the data is caught by the copy made before it; this one guards
  /// against the new version damaging what it read.) Remembers the version.
  static Future<void> afterUpgrade(AppState state) async {
    if (state.lastRunVersion == appVersion) return;
    final hadData = state.history.games.isNotEmpty || state.stats.played > 0;
    state.noteRunVersion(appVersion);
    if (hadData) {
      await run(state, downloads: false, label: 'after-update');
    }
  }
}
