import 'dart:typed_data';

import 'logic.dart';
import 'precomputed.dart';

/// An analysis that was fetched, offered to [analyseGuesses] as if it had
/// been kept on a disk.
class _Fetched implements OpeningDisk {
  _Fetched(this.key, this.bytes);
  final String key;
  final Uint8List bytes;

  @override
  Uint8List? read(String k) => k == key ? bytes : null;

  @override
  void write(String k, Uint8List b) {}
}

/// No threads here: the analysis runs where it is called. The opening of a
/// list is a minute of work here, so the published one is fetched first (the
/// precompute workflow keeps it); when there is none, it is worked out.
Future<Landscape> analyse(
  List<String> eligible,
  List<String> candidates,
  int k,
  Map<String, int>? weights,
  String? answer,
  bool blind,
  bool useDisk,
) async {
  OpeningDisk? disk;
  if (useDisk &&
      eligible.length > 2 &&
      candidates.length * eligible.length >= openingCells) {
    final key = openingKeyOf(eligible, candidates, weights, blind);
    final bytes = await fetchPrecomputedOpening(key);
    if (bytes != null) disk = _Fetched(key, bytes);
  }
  return analyseGuesses(
    eligible,
    candidates,
    k: k,
    weights: weights,
    answer: answer,
    blind: blind,
    disk: disk,
  );
}

/// No threads here: scored where it is called.
Future<Float64List> scoreOnPool(
  List<String> board,
  List<String> words,
  Map<String, int>? weights,
) async => scoreChunk(board, weights, false, words, null);
