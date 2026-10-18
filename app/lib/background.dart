import 'dart:async';

/// Whether the game screens analyse each guess in the background as it is
/// made. The tests turn it off (see test/flutter_test_config.dart): the
/// analysis yields to the event loop with timers, and one still running when a
/// test ends would be left pending; the tests of the behaviour turn it on.
bool analyseWhilePlaying = true;

/// Runs jobs one after another, in the background, while the game is played:
/// the analysis of each guess is worked out as soon as it is made, one at a
/// time so a slow one never competes with the next, and the review finds the
/// answers ready. [close] (when a new game starts) stops jobs not yet begun.
class JobQueue {
  Future<void> _tail = Future.value();
  bool _closed = false;

  void close() => _closed = true;

  /// Queues [job]; the result is its future. A job that had not begun when
  /// the queue was closed never runs and its future never completes.
  Future<T> add<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      if (_closed) return;
      try {
        done.complete(await job());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    // a job nobody awaits must not raise an unhandled error
    done.future.ignore();
    return done.future;
  }
}
