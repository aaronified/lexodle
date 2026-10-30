import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'logic.dart';

/// How many threads score an opening at once: half the cores, from two to four,
/// so the screen and the system keep the rest. One on a phone with two cores.
int scoringThreads() {
  final cores = Platform.numberOfProcessors;
  return cores <= 2 ? 1 : (cores ~/ 2).clamp(2, 4);
}

/// [scoreChunk] over [words] split between [scoringThreads] isolates, the
/// results joined in the order of the words. Falls back to this thread if an
/// isolate cannot be started.
Future<Float64List> scoreOnThreads(
  List<String> eligible,
  Map<String, int>? weights,
  bool blind,
  List<String> words,
  String? answer, {
  int? threads,
}) async {
  final t = threads ?? scoringThreads();
  if (t <= 1 || words.length < t * 50) {
    return scoreChunk(eligible, weights, blind, words, answer);
  }
  final size = (words.length + t - 1) ~/ t;
  try {
    final parts = await Future.wait([
      for (var from = 0; from < words.length; from += size)
        Isolate.run(
          () => scoreChunk(
            eligible,
            weights,
            blind,
            words.sublist(from, from + size > words.length ? words.length : from + size),
            answer,
          ),
        ),
    ]);
    final out = Float64List(parts.fold<int>(0, (n, p) => n + p.length));
    var at = 0;
    for (final p in parts) {
      out.setRange(at, at + p.length, p);
      at += p.length;
    }
    return out;
  } catch (_) {
    return scoreChunk(eligible, weights, blind, words, answer);
  }
}
