import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'auto_backup.dart';

/// The app's own log: what it did and what went wrong, kept on the phone so a
/// player can send it. A failed save, for example, is otherwise silent.
///
/// The lines of this run are held in memory and written to the app's own
/// storage a moment after each one (a folder of its own, not the backups'). At
/// the next start they move to the history, which keeps the newest
/// [historyCap] characters. A run can be exported alone or with the history.
///
/// Nothing in it is a game's content: it records the app's own steps (start,
/// what was found in storage, saves, backups, updates, errors), never words or
/// guesses.
class AppLog {
  AppLog({this._files});

  BackupFiles? _files;
  BackupFiles get _store => _files ?? AutoBackup.files;

  final List<String> _lines = [];
  var _dropped = 0;
  var _history = '';
  var _started = false;
  Timer? _timer;
  DateTime _begin = DateTime.now();

  static const currentFile = 'current.log';
  static const historyFile = 'history.log';

  /// The most lines one run keeps (the oldest go first), and the most
  /// characters of earlier runs.
  static const maxLines = 4000;
  static const historyCap = 300000;

  /// When the lines of this run began.
  DateTime get begin => _begin;

  /// The number of lines of this run held.
  int get length => _lines.length;

  /// Opens a run: what the last one wrote moves into the history, and this one
  /// starts. Lines added before this (the very first moments of a start) are
  /// kept. Safe to call again; it does nothing the second time.
  Future<void> start({required String version, BackupFiles? files}) async {
    if (_started) return;
    _started = true;
    if (files != null) _files = files;
    _begin = DateTime.now();
    try {
      final old = await _store.readLog(currentFile);
      final hist = await _store.readLog(historyFile);
      var text =
          (hist == null ? '' : utf8.decode(hist, allowMalformed: true)) +
          (old == null ? '' : utf8.decode(old, allowMalformed: true));
      if (text.length > historyCap) {
        text = text.substring(text.length - historyCap);
        final nl = text.indexOf('\n');
        if (nl >= 0) text = text.substring(nl + 1); // a whole line first
      }
      _history = text;
      await _store.writeLog(historyFile, Uint8List.fromList(utf8.encode(text)));
    } catch (e) {
      add('W', 'log', 'could not read the earlier log: $e');
    }
    add('I', 'app', 'start, version $version');
    await flush();
  }

  /// Adds a line. [level] is `I` (what happened), `W` (a thing that could be
  /// wrong) or `E` (something failed).
  void add(String level, String tag, String message) {
    final line = '${DateTime.now().toIso8601String()} $level $tag: $message';
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeAt(0);
      _dropped++;
    }
    if (_started) _schedule();
  }

  void i(String tag, String message) => add('I', tag, message);
  void w(String tag, String message) => add('W', tag, message);
  void e(String tag, String message) => add('E', tag, message);

  void _schedule() {
    _timer ??= Timer(const Duration(seconds: 2), () {
      _timer = null;
      flush();
    });
  }

  /// Writes this run's lines to the app's storage now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    try {
      await _store.writeLog(
        currentFile,
        Uint8List.fromList(utf8.encode(session)),
      );
    } catch (_) {
      // the log cannot be kept: there is nowhere else to say so
    }
  }

  /// The lines of this run.
  String get session {
    final b = StringBuffer();
    if (_dropped > 0) {
      b.writeln('... $_dropped earlier lines of this run left out');
    }
    for (final l in _lines) {
      b.writeln(l);
    }
    return b.toString();
  }

  /// Earlier runs, then this one.
  String get all =>
      _history.isEmpty ? session : '$_history\n--- this run ---\n$session';

  /// The last [count] lines of this run, newest last.
  List<String> tail([int count = 80]) => _lines.length <= count
      ? List.of(_lines)
      : _lines.sublist(_lines.length - count);

  /// Saves the log to the Downloads folder as a text file; the name it was
  /// saved as, or null where that cannot be done. [everything] adds earlier
  /// runs.
  Future<String?> export({bool everything = false, DateTime? now}) async {
    final t = (now ?? DateTime.now()).toIso8601String().substring(0, 16);
    final name =
        'lexodle-log-${everything ? 'all' : 'run'}-${t.replaceAll(':', '')}.txt';
    final text = everything ? all : session;
    try {
      return await _store.saveToDownloads(
        name,
        Uint8List.fromList(utf8.encode(text)),
        mime: 'text/plain',
      );
    } catch (e) {
      add('E', 'log', 'could not export the log: $e');
      return null;
    }
  }
}

/// The app's log.
final appLog = AppLog();
