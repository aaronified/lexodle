import 'lex.dart';

/// What a bought hint reveals: [letter], and for a green one its place [pos].
class HintPick {
  const HintPick(this.kind, this.letter, [this.pos = 0]);
  final HintKind kind;
  final String letter;
  final int pos;
}

/// The letters of [answer] the player already has as green in [guesses], with
/// the places of them.
Set<int> _greenPlaces(String answer, Iterable<String> guesses) => {
  for (final g in guesses)
    for (var i = 0; i < answer.length && i < g.length; i++)
      if (g[i] == answer[i]) i,
};

/// A stable choice from [options] (sorted first, so the order of the input
/// never matters): the same answer and guesses always give the same pick.
T? _choose<T extends Comparable<Object>>(
  List<T> options,
  String answer,
  int n,
) {
  if (options.isEmpty) return null;
  final sorted = List.of(options)..sort();
  final seed = answer.codeUnits.fold<int>(n, (a, b) => (a * 31 + b) & 0xFFFFF);
  return sorted[seed % sorted.length];
}

/// A grey hint: a letter of [letters] that is not in [answer]. Letters already
/// guessed or already hinted ([taken]) are not offered; null when none is left.
HintPick? pickGrey(
  String answer,
  List<String> guesses,
  Set<String> letters, {
  Iterable<HintPick> taken = const [],
}) {
  final seen = {for (final g in guesses) ...g.split('')};
  final hinted = {for (final h in taken) h.letter};
  final options = [
    for (final l in letters)
      if (!answer.contains(l) && !seen.contains(l) && !hinted.contains(l)) l,
  ];
  final l = _choose(options, answer, guesses.length);
  return l == null ? null : HintPick(HintKind.grey, l);
}

/// A yellow hint: a letter that is in [answer] and not yet found (no green of
/// it in [guesses]). A letter not yet guessed at all comes first. Null when
/// every letter of the answer is found or hinted.
HintPick? pickYellow(
  String answer,
  List<String> guesses, {
  Iterable<HintPick> taken = const [],
}) {
  final greens = _greenPlaces(answer, guesses);
  final found = {for (final i in greens) answer[i]};
  final hinted = {
    for (final h in taken)
      if (h.kind != HintKind.grey) h.letter,
  };
  final open = {
    for (var i = 0; i < answer.length; i++)
      if (!greens.contains(i) &&
          !found.contains(answer[i]) &&
          !hinted.contains(answer[i]))
        answer[i],
  }.toList();
  final seen = {for (final g in guesses) ...g.split('')};
  final fresh = [
    for (final l in open)
      if (!seen.contains(l)) l,
  ];
  final l = _choose(fresh.isEmpty ? open : fresh, answer, guesses.length);
  return l == null ? null : HintPick(HintKind.yellow, l);
}

/// A green hint: a place of [answer] that is not yet green in [guesses] (nor
/// given by an earlier hint), with its letter. Null when none is left.
HintPick? pickGreen(
  String answer,
  List<String> guesses, {
  Iterable<HintPick> taken = const [],
}) {
  final greens = _greenPlaces(answer, guesses);
  final hinted = {
    for (final h in taken)
      if (h.kind == HintKind.green) h.pos,
  };
  final options = [
    for (var i = 0; i < answer.length; i++)
      if (!greens.contains(i) && !hinted.contains(i)) i,
  ];
  final i = _choose(options, answer, guesses.length);
  return i == null ? null : HintPick(HintKind.green, answer[i], i);
}

/// The hint of [kind], or null when there is nothing to reveal.
HintPick? pickHint(
  HintKind kind,
  String answer,
  List<String> guesses,
  Set<String> letters, {
  Iterable<HintPick> taken = const [],
}) => switch (kind) {
  HintKind.grey => pickGrey(answer, guesses, letters, taken: taken),
  HintKind.yellow => pickYellow(answer, guesses, taken: taken),
  HintKind.green => pickGreen(answer, guesses, taken: taken),
};
