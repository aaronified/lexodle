import 'dart:math';

import 'logic.dart';

/// One group a guess splits the words that fit into: the words that would show
/// the same colours if they were the answer.
class GroupLine {
  const GroupLine({
    required this.marks,
    required this.words,
    required this.mass,
    required this.chance,
    required this.bits,
    required this.share,
    required this.holdsAnswer,
  });

  /// The colours the guess would show for every word of the group.
  final List<Mark> marks;

  /// The words in the group, most likely first (the order they were given in).
  final List<String> words;

  /// The group's weight: its word count when every word is as likely as the
  /// next, else the sum of the weights of its words.
  final double mass;

  /// The chance the answer is in the group: its mass over the total.
  final double chance;

  /// What learning that the answer is in the group gains: -log2 of the chance.
  final double bits;

  /// What the group adds to the expected words left: chance times the pool it
  /// leaves (chance x n x chance). The sum over the groups is E.
  final double share;

  /// Whether the answer the clues came from is in this group.
  final bool holdsAnswer;
}

/// The groups one guess makes of the words that fit, with the sums the skill
/// is made from, laid out step by step.
class GroupWalk {
  const GroupWalk({
    required this.guess,
    required this.words,
    required this.total,
    required this.groups,
    required this.expectedLeft,
    required this.expectedBits,
  });

  final String guess;

  /// How many words fit before the guess.
  final int words;

  /// The summed weight of the words (the word count when they are equally
  /// likely).
  final double total;

  /// Every group, the most likely first.
  final List<GroupLine> groups;

  /// E: the words expected to be left, the sum of the groups' [GroupLine.share].
  final double expectedLeft;

  /// H: the bits the guess is expected to gain, the sum of chance x bits.
  final double expectedBits;

  /// The group the answer is in, when one was given.
  GroupLine? get landed {
    for (final g in groups) {
      if (g.holdsAnswer) return g;
    }
    return null;
  }

  /// The skill of the guess against [bestBits], the best guess's H.
  double skill(double bestBits) => skillOf(expectedBits, bestBits);
}

/// Walks [guess] through [eligible]: every word is scored as if it were the
/// answer, the words that show the same colours are one group, and the chance,
/// the bits and the part of the expected words left of each group are worked
/// out. [weights] is how likely each word is (null: all alike). With [answer],
/// the group it falls in is marked. Same numbers as [splitStats], but spelled
/// out, so a screen can show them and a test can compare the two.
GroupWalk walkGroups(
  List<String> eligible,
  String guess,
  Map<String, int>? weights, {
  String? answer,
}) {
  final n = eligible.length;
  double weightOf(String w) =>
      weights == null ? 1.0 : max(weights[w] ?? 1, 1).toDouble();
  final byCode = <int, List<String>>{};
  var total = 0.0;
  for (final w in eligible) {
    (byCode[patternCode(w, guess)] ??= []).add(w);
    total += weightOf(w);
  }
  final answerCode = answer == null ? null : patternCode(answer, guess);
  var e = 0.0, h = 0.0;
  final lines = <GroupLine>[];
  for (final entry in byCode.entries) {
    final mass = entry.value.fold<double>(0, (s, w) => s + weightOf(w));
    final q = mass / total;
    final bits = -log(q) / ln2;
    final share = q * n * q;
    e += share;
    h += q * bits;
    lines.add(
      GroupLine(
        marks: _marks(entry.key, guess.length),
        words: entry.value,
        mass: mass,
        chance: q,
        bits: bits,
        share: share,
        holdsAnswer: entry.key == answerCode,
      ),
    );
  }
  lines.sort((a, b) => b.mass.compareTo(a.mass));
  return GroupWalk(
    guess: guess,
    words: n,
    total: total,
    groups: lines,
    expectedLeft: e,
    expectedBits: h,
  );
}

/// The colours a [patternCode] stands for: one base-3 digit a position, the
/// first position the highest.
List<Mark> _marks(int code, int length) {
  final out = List<Mark>.filled(length, Mark.absent);
  for (var i = length - 1; i >= 0; i--) {
    out[i] = Mark.values[code % 3];
    code ~/= 3;
  }
  return out;
}
