import 'app_log.dart';
import 'lex.dart';

/// What a bought hint reveals: [letter], and for a green one its place [pos].
/// In a quartet or a relay race it is for one [board] (0 in a single game).
class HintPick {
  const HintPick(this.kind, this.letter, [this.pos = 0, this.board = 0]);
  final HintKind kind;
  final String letter;
  final int pos;
  final int board;

  /// The same hint, for [board].
  HintPick onBoard(int board) => HintPick(kind, letter, pos, board);

  /// How a hint is kept in a saved game (an optional `hints` list there).
  Map<String, dynamic> toJson() => {
    'k': kind.name,
    'l': letter,
    if (pos != 0) 'p': pos,
    if (board != 0) 'b': board,
  };

  /// The hint in [j], or null when it is not a valid one for a game of
  /// [boards] boards, words of [length] and the [letters] of its language.
  static HintPick? fromJson(
    Object? j, {
    required int boards,
    required int length,
    required Set<String> letters,
  }) {
    if (j is! Map) return null;
    final kind = HintKind.named(j['k']);
    final l = j['l'], p = j['p'] ?? 0, b = j['b'] ?? 0;
    if (kind == null || l is! String || !letters.contains(l)) return null;
    if (p is! int || p < 0 || p >= length) return null;
    if (b is! int || b < 0 || b >= boards) return null;
    return HintPick(kind, l, p, b);
  }
}

/// The hints of a saved game's [json] (the `hints` value, absent in an old
/// save), those that are valid; never throws.
List<HintPick> hintsFromJson(
  Object? json, {
  required int boards,
  required int length,
  required Set<String> letters,
}) {
  try {
    if (json is! List) return [];
    return [
      for (final j in json)
        ?HintPick.fromJson(j, boards: boards, length: length, letters: letters),
    ];
  } catch (e) {
    appLog.w('hint', 'could not read the saved hints: ${e.runtimeType}');
    return [];
  }
}

/// The saved form of [picks].
List<Map<String, dynamic>> hintsToJson(Iterable<HintPick> picks) => [
  for (final h in picks) h.toJson(),
];

/// The hints of a game put back as they were when it was left: already paid
/// for, so nothing is charged and nothing is logged in the player's lex (the
/// purchases are taken from a scratch [Lex], free, and marked with [guesses]).
GameHints restoreHints(Iterable<HintPick> picks, {required int guesses}) {
  final game = GameHints();
  try {
    for (final h in picks) {
      Lex().spend(game, h.kind, guesses: guesses, free: true);
    }
  } catch (e) {
    appLog.w('hint', 'could not restore the hints: ${e.runtimeType}');
  }
  return game;
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
