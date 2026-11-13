import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_log.dart';

/// `m:ss` for a time in milliseconds (`0:07`, `12:34`), `h:mm:ss` from an hour.
String formatElapsed(int ms) {
  final total = (ms < 0 ? 0 : ms) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// The time a game has been played: from the first key until it is over, not
/// counting the time the app is out of the foreground. It starts from the time
/// a resumed game had already counted.
class GameTimer extends ChangeNotifier with WidgetsBindingObserver {
  /// [now] is the clock (a monotonic time); tests give their own.
  GameTimer({int elapsedMs = 0, Duration Function()? now})
    : _base = elapsedMs < 0 ? 0 : elapsedMs,
      _now = now ?? _systemNow {
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (e) {
      appLog.w('timer', 'lifecycle observer: ${e.runtimeType}');
    }
  }

  static final _watch = Stopwatch()..start();
  static Duration _systemNow() => _watch.elapsed;

  final Duration Function() _now;
  final int _base;
  int _banked = 0;
  Duration? _since;
  Timer? _ticker;
  bool _started = false;
  bool _stopped = false;
  bool _wasRunning = false;
  bool _observing = false;
  bool _disposed = false;

  /// The time counted so far, in milliseconds.
  int get elapsedMs =>
      _base +
      _banked +
      (_since == null ? 0 : (_now() - _since!).inMilliseconds);

  /// Whether it is counting now.
  bool get running => _since != null;

  /// Starts counting (the first key); nothing when it counts or is over.
  void start() {
    if (running || _stopped || _disposed) return;
    _started = true;
    _go();
  }

  /// Ends it for good: the time is frozen.
  void stop() {
    if (_stopped) return;
    _halt();
    _stopped = true;
    _started = true;
    _wasRunning = false;
    if (!_disposed) notifyListeners();
  }

  /// Stops counting until [resume] (the app left the foreground).
  void pause() {
    if (!running) return;
    _halt();
    if (!_disposed) notifyListeners();
  }

  /// Counts again after a [pause], if it had been started and is not over.
  void resume() {
    if (running || !_started || _stopped || _disposed) return;
    _go();
  }

  void _go() {
    _since = _now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
  }

  void _halt() {
    if (_since != null) {
      _banked += (_now() - _since!).inMilliseconds;
      _since = null;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // (inactive then paused: the first has already stopped the count)
        if (running) _wasRunning = true;
        pause();
      case AppLifecycleState.resumed:
        if (_wasRunning) {
          _wasRunning = false;
          resume();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _halt();
    if (_observing) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (e) {
        appLog.w('timer', 'lifecycle observer: ${e.runtimeType}');
      }
    }
    super.dispose();
  }
}
