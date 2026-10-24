import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'daily.dart';
import 'modes.dart';
import 'store.dart';
import 'words.dart';

/// The version of the backup file; a file from a later one is refused rather
/// than half understood.
const backupVersion = 1;

/// The largest backup read, so a wrong file is turned away before it is parsed.
const maxBackupBytes = 1000000;

/// Everything the app keeps, as a file: the settings, the statistics and every
/// achievement. It is the persistent storage of the web build, where the
/// browser's own storage can be cleared at any time.
class Backup {
  Backup({
    required this.exported,
    required this.settings,
    required this.stats,
    required this.achievements,
    this.dailyLog,
    this.dailyBest,
  });

  final DateTime exported;

  /// How each daily went and the longest daily streak; null in a backup from
  /// before the daily, which leaves what is saved alone.
  final Map<String, int>? dailyLog;
  final int? dailyBest;

  /// The settings present in the file (a missing one keeps its current value).
  final Map<String, Object> settings;
  final Stats stats;
  final Map<String, AchState> achievements;

  /// How many different achievements it has earned.
  int get earned => achievements.values.where((s) => s.times > 0).length;
}

/// The backup of what [state] holds now, as the text of the file.
String backupToText(AppState state, {DateTime? now}) {
  final stamp = (now ?? DateTime.now()).toUtc().toIso8601String();
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'lexodle',
    'version': backupVersion,
    'exported': stamp,
    'settings': state.settingsJson(),
    'stats': state.stats.toJson(),
    'achievements': {
      for (final e in state.ach.entries) e.key: e.value.toJson(),
    },
    'daily': {'log': state.dailyLog, 'best': state.dailyBest},
  });
}

/// The file name for a backup made on [day]: lexodle-backup-2026-10-18.json.
String backupFileName(DateTime day) =>
    'lexodle-backup-${day.toIso8601String().substring(0, 10)}.json';

/// Reads and checks the text of a backup file. Throws a [FormatException]
/// whose message is fit to show the player when it is not a backup of this
/// app, is from a later version, or is damaged: a file is taken whole or not
/// at all, never half.
Backup parseBackup(String text) {
  if (text.length > maxBackupBytes) {
    throw const FormatException('that file is too big to be a backup');
  }
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    throw const FormatException('that file is not a lexodle backup');
  }
  if (raw is! Map || raw['app'] != 'lexodle') {
    throw const FormatException('that file is not a lexodle backup');
  }
  final version = raw['version'];
  if (version is! int || version < 1) {
    throw const FormatException('that backup is damaged');
  }
  if (version > backupVersion) {
    throw const FormatException(
      'that backup was made by a newer version of lexodle',
    );
  }
  const damaged = FormatException('that backup is damaged');
  try {
    final exported = DateTime.tryParse('${raw['exported']}') ?? DateTime.now();
    final settings = _settings(raw['settings']);
    final stats = _stats(raw['stats']);
    final ach = _achievements(raw['achievements']);
    final daily = _daily(raw['daily']);
    return Backup(
      exported: exported,
      settings: settings,
      stats: stats,
      achievements: ach,
      dailyLog: daily?.$1,
      dailyBest: daily?.$2,
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw damaged;
  }
}

Never _bad(String what) =>
    throw FormatException('that backup is damaged ($what)');

Map<String, Object> _settings(Object? raw) {
  if (raw == null) return {};
  if (raw is! Map) _bad('settings');
  final out = <String, Object>{};
  int? integer(String key, int lo, int hi) {
    final v = raw[key];
    if (v == null) return null;
    if (v is! int || v < lo || v > hi) _bad(key);
    return v;
  }

  final lang = raw['lang'];
  if (lang != null) {
    if (lang is! String ||
        !RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?$').hasMatch(lang)) {
      _bad('lang');
    }
    out['lang'] = lang;
  }
  final length = integer('length', 4, 8);
  if (length != null) out['length'] = length;
  final tries = integer('tries', 1, 12);
  if (tries != null) out['tries'] = tries;
  final pool = raw['pool'];
  if (pool != null) {
    if (pool is! int || !poolSizes.contains(pool)) _bad('pool');
    out['pool'] = pool;
  }
  final helper = integer('helper', 0, Helper.values.length - 1);
  if (helper != null) out['helper'] = helper;
  final mode = integer('mode', 0, GameMode.values.length - 1);
  if (mode != null) out['mode'] = mode;
  final share = integer('share', 0, maxShare);
  if (share != null) out['share'] = share;
  final theme = integer('theme', 0, 2);
  if (theme != null) out['theme'] = theme;
  final seen = raw['seenHowTo'];
  if (seen != null) {
    if (seen is! bool) _bad('seenHowTo');
    out['seenHowTo'] = seen;
  }
  return out;
}

const _bigCount = 100000000;

Stats _stats(Object? raw) {
  if (raw == null) return Stats();
  if (raw is! Map) _bad('statistics');
  for (final k in const ['played', 'wins', 'streak', 'bestStreak']) {
    final v = raw[k];
    if (v != null && (v is! int || v < 0 || v > _bigCount)) _bad(k);
  }
  final stats = Stats.fromJson(raw.cast<String, dynamic>());
  if (stats.wins > stats.played) _bad('more wins than games');
  return stats;
}

Map<String, AchState> _achievements(Object? raw) {
  if (raw == null) return {};
  if (raw is! Map) _bad('achievements');
  final known = {for (final a in achievements) a.id};
  final out = <String, AchState>{};
  for (final e in raw.entries) {
    // an achievement this version does not have is left out, not an error
    if (!known.contains(e.key)) continue;
    final v = e.value;
    if (v is! Map) _bad('${e.key}');
    final s = AchState.fromJson(v.cast<String, dynamic>());
    if (s.times < 0 || s.times > _bigCount || s.progress < 0) _bad('${e.key}');
    out[e.key as String] = s;
  }
  return out;
}

/// The daily log and best streak, or null when the file has none.
(Map<String, int>, int)? _daily(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) _bad('daily');
  final log = <String, int>{};
  final rawLog = raw['log'];
  if (rawLog != null) {
    if (rawLog is! Map) _bad('daily log');
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    for (final e in rawLog.entries) {
      final k = e.key, v = e.value;
      if (k is! String || !date.hasMatch(k)) _bad('daily date');
      if (v is! int || v < dailyMissed || v > dailyDouble) _bad('daily day');
      log[k] = v;
    }
  }
  final best = raw['best'] ?? 0;
  if (best is! int || best < 0 || best > _bigCount) _bad('best streak');
  return (log, best);
}

/// A file the player chose to restore.
class BackupFile {
  const BackupFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Saving and choosing the backup file. The app uses the system's own pickers;
/// tests put a fake one in [current].
abstract class BackupIO {
  static BackupIO current = FilePickerBackupIO();

  /// Saves [bytes] as [fileName]; true when it was, false when cancelled.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Lets the player choose a file; null when cancelled.
  Future<BackupFile?> pick();
}

class FilePickerBackupIO implements BackupIO {
  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'save your backup',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    // in a browser the file goes straight to downloads and there is nothing
    // to report back
    return saved != null || kIsWeb;
  }

  @override
  Future<BackupFile?> pick() async {
    final f = await FilePicker.pickFile(
      dialogTitle: 'choose a lexodle backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (f == null) return null;
    final size = await f.length();
    if (size != null && size > maxBackupBytes) {
      throw const FormatException('that file is too big to be a backup');
    }
    return BackupFile(f.name, await f.readAsBytes());
  }
}
