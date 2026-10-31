import 'dart:typed_data';

import 'logic.dart';

/// No threads here: the analysis runs where it is called.
Future<Landscape> analyse(
  List<String> eligible,
  List<String> candidates,
  int k,
  Map<String, int>? weights,
  String? answer,
  bool blind,
  bool useDisk,
) => analyseGuesses(
  eligible,
  candidates,
  k: k,
  weights: weights,
  answer: answer,
  blind: blind,
);

/// No threads here: scored where it is called.
Future<Float64List> scoreOnPool(
  List<String> board,
  List<String> words,
  Map<String, int>? weights,
) async => scoreChunk(board, weights, false, words, null);
