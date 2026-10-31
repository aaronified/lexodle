import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'logic.dart';
import 'opening_disk.dart';
import 'opening_parallel.dart';

/// One worker isolate for the whole app, started on first use. Its memory is
/// its own, so the opening it keeps for the next game never weighs on the
/// screen's, and its work is on another thread than the game's.
class _Worker {
  _Worker._(this._to);

  final SendPort _to;
  final _waiting = <int, Completer<Landscape>>{};
  var _next = 0;

  static Future<_Worker>? _shared;

  static Future<_Worker> get() => _shared ??= _start().catchError((Object e) {
    _shared = null; // try again next time
    throw e;
  });

  static Future<_Worker> _start() async {
    final from = ReceivePort();
    final errors = ReceivePort();
    await Isolate.spawn(
      _main,
      from.sendPort,
      debugName: 'lexodle-analysis',
      onError: errors.sendPort,
    );
    final events = StreamIterator<Object?>(from);
    if (!await events.moveNext()) throw StateError('analysis worker stopped');
    final worker = _Worker._(events.current as SendPort);
    // what the worker sends next is a reply: [id, Landscape] or [id, error]
    unawaited(() async {
      while (await events.moveNext()) {
        final m = events.current as List;
        final c = worker._waiting.remove(m[0] as int);
        if (m[1] is Landscape) {
          c?.complete(m[1] as Landscape);
        } else {
          c?.completeError(StateError(m[1].toString()));
        }
      }
    }());
    errors.listen((e) {
      // the worker died: fail what waits for it, and start a new one next time
      _shared = null;
      for (final c in worker._waiting.values) {
        c.completeError(StateError('analysis worker failed: $e'));
      }
      worker._waiting.clear();
    });
    return worker;
  }

  Future<Landscape> run(
    List<String> eligible,
    List<String> candidates,
    int k,
    Map<String, int>? weights,
    String? answer,
    bool blind,
    bool useDisk,
  ) {
    final id = _next++;
    final c = Completer<Landscape>();
    _waiting[id] = c;
    _to.send([id, eligible, candidates, k, weights, answer, blind, useDisk]);
    return c.future;
  }
}

void _main(SendPort host) {
  final disk = DiskOpenings();
  final inbox = ReceivePort();
  host.send(inbox.sendPort);
  inbox.listen((Object? m) async {
    final a = m as List;
    final id = a[0] as int;
    try {
      final land = await analyseGuesses(
        (a[1] as List).cast<String>(),
        (a[2] as List).cast<String>(),
        k: a[3] as int,
        weights: (a[4] as Map?)?.cast<String, int>(),
        answer: a[5] as String?,
        blind: a[6] as bool,
        disk: a[7] as bool ? disk : null,
        scorer: scoreOnThreads,
      );
      host.send([id, land]);
    } catch (e) {
      host.send([id, e.toString()]);
    }
  });
}

/// [analyseGuesses] on the worker; on this thread if there is no worker.
Future<Landscape> analyse(
  List<String> eligible,
  List<String> candidates,
  int k,
  Map<String, int>? weights,
  String? answer,
  bool blind,
  bool useDisk,
) async {
  final _Worker worker;
  try {
    worker = await _Worker.get();
  } catch (_) {
    return analyseGuesses(
      eligible,
      candidates,
      k: k,
      weights: weights,
      answer: answer,
      blind: blind,
      disk: useDisk ? DiskOpenings() : null,
      scorer: scoreOnThreads,
    );
  }
  return worker.run(eligible, candidates, k, weights, answer, blind, useDisk);
}

/// The numbers of [scoreChunk] for [words] against [board], on threads of their
/// own so the screen never waits for them.
Future<Float64List> scoreOnPool(
  List<String> board,
  List<String> words,
  Map<String, int>? weights,
) => scoreOnThreads(board, weights, false, words, null);
