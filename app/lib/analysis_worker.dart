import 'dart:typed_data';

import 'logic.dart';
import 'analysis_worker_stub.dart'
    if (dart.library.io) 'analysis_worker_io.dart'
    as platform;

/// Whether the analysis runs on a thread of its own, where the platform has
/// one. The tests turn it off (see test/flutter_test_config.dart): a test's
/// clock is not the real one, and a reply from another thread would never
/// arrive in it.
bool analyseOffMainThread = true;

/// [analyseGuesses], worked out on a worker thread of its own so the screen
/// and the keys never wait for it. The worker lives for as long as the app
/// does, and keeps the opening of a game (see [analyseGuesses]) for the next
/// one. Where there are no threads (the web) it runs on the main one, as
/// [analyseGuesses] does, yielding now and then.
Future<Landscape> analyseOffThread(
  List<String> eligible,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
  String? answer,
  bool blind = false,
  bool useDisk = true,
}) => analyseOffMainThread
    ? platform.analyse(
        eligible,
        candidates.toList(),
        k,
        weights,
        answer,
        blind,
        useDisk,
      )
    : analyseGuesses(
        eligible,
        candidates,
        k: k,
        weights: weights,
        answer: answer,
        blind: blind,
      );

/// Starts scoring the opening of a game, the first guess against every word,
/// while the player is still choosing it, so its analysis is there when the
/// guess is made. A hint: nothing waits for it and a failure is ignored.
void warmOpening(
  List<String> eligible,
  Iterable<String> candidates, {
  Map<String, int>? weights,
  bool blind = false,
}) {
  if (!analyseOffMainThread) return;
  analyseOffThread(
    eligible,
    candidates,
    weights: weights,
    blind: blind,
  ).then<void>((_) {}, onError: (_) {});
}

/// The expected gain of each of [words] against [board], worked out on other
/// threads, or null where the analysis stays on this one (the tests, the web).
Future<Float64List?> gainsOffThread(
  List<String> board,
  List<String> words,
  Map<String, int>? weights,
) async {
  if (!analyseOffMainThread) return null;
  final rows = await platform.scoreOnPool(board, words, weights);
  return Float64List.fromList([
    for (var i = 0; i < words.length; i++) rows[i * chunkRow + chunkGain],
  ]);
}
