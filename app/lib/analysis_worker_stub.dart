import 'logic.dart';

/// No threads here: the analysis runs where it is called.
Future<Landscape> analyse(
  List<String> eligible,
  List<String> candidates,
  int k,
  Map<String, int>? weights,
  String? answer,
) => analyseGuesses(
  eligible,
  candidates,
  k: k,
  weights: weights,
  answer: answer,
);
