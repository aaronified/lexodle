import 'dart:math';

import 'analysis_worker.dart';
import 'drill.dart';
import 'drill_calc.dart';
import 'learn_styles.dart';
import 'logic.dart' hide freshLetters;
import 'modes.dart';
import 'opening.dart';
import 'playstyle.dart';
import 'words.dart';

/// One example of an opening habit: a real guess in a real early position, with
/// the numbers the playstyle read from it.
class OpeningExample {
  const OpeningExample({
    required this.behaviour,
    required this.profile,
    required this.walk,
    required this.qualifies,
  });

  /// The habit it stands for.
  final Behaviour behaviour;
  final StyleProfile profile;

  /// How the guess splits the words that fit (groups, the words left on
  /// average, the biggest group).
  final GroupWalk walk;

  /// Whether the guess really counts as [behaviour]: false when the position has
  /// no guess that does (the example is then the nearest one).
  final bool qualifies;

  String get word => profile.guess;
}

/// The position the opening examples are taken from: the first guess played and
/// the colours it showed, and the words that still fit.
class OpeningPosition {
  const OpeningPosition({
    required this.first,
    required this.marks,
    required this.eligible,
    required this.landscape,
  });
  final String first;
  final List<Mark> marks;
  final List<String> eligible;
  final Landscape landscape;
}

/// How luck falls on one guess: the groups the answer can be in, the chance of
/// each and the luck it would give. Luck cannot be learned: this only shows what
/// it is, and that over all answers it averages nothing.
class LuckSpread {
  const LuckSpread({
    required this.guess,
    required this.rows,
    required this.mean,
  });
  final String guess;
  final List<LuckRow> rows;

  /// The chance-weighted mean luck over every group: 0 for every guess.
  final double mean;
}

class LuckRow {
  const LuckRow(this.group, this.luck);
  final GroupLine group;

  /// The luck of the answer being in this group, -100 to 100.
  final double luck;
}

/// The luck of every group of [guess] among [eligible]: the groups from the
/// biggest (unluckiest) to the smallest (luckiest), and the mean, which is 0.
LuckSpread luckSpread(
  List<String> eligible,
  String guess,
  Map<String, int>? weights,
) {
  final walk = walkGroups(eligible, guess, weights);
  final masses = [for (final g in walk.groups) g.mass];
  final rows = [
    for (final g in walk.groups) LuckRow(g, chanceLuck(masses, g.mass)),
  ];
  final mean = rows.fold(0.0, (s, r) => s + r.group.chance * r.luck);
  return LuckSpread(guess: guess, rows: rows, mean: mean);
}

/// Finds the early position to teach in: the best opener played, and the colours
/// it most often shows (the likeliest outcome with [earlyFrom] or more words
/// left); the whole list as it opens when no outcome has that many.
Future<OpeningPosition> openingPosition({
  required WordBank bank,
  required int length,
  required Draw draw,
}) async {
  final all = bank.guessable(length);
  final law = bank.law(length, draw);
  final land = await openingLandscape(bank: bank, length: length, draw: draw);
  final first = land.top.first.word;
  for (final g in openingOutcomes(all, first, law)) {
    if (g.words.length >= earlyFrom) {
      final next = await analyseOffThread(g.words, all, k: 3, weights: law);
      return OpeningPosition(
        first: first,
        marks: g.marks,
        eligible: g.words,
        landscape: next,
      );
    }
  }
  return OpeningPosition(
    first: first,
    marks: const [],
    eligible: all,
    landscape: land,
  );
}

/// One example of each opening habit in [pos]: the best guess (the maximiser),
/// the best guess that is only an eliminator, and the best gamble. When the
/// position has none that qualifies, the nearest one stands in with
/// [OpeningExample.qualifies] false.
List<OpeningExample> openingExamples({
  required OpeningPosition pos,
  required List<String> guessable,
  required Map<String, int>? weights,
}) {
  final earlier = pos.marks.isEmpty ? const <String>[] : [pos.first];
  final earlierMarks = pos.marks.isEmpty ? const <List<Mark>>[] : [pos.marks];
  StyleProfile profile(String w) => profileGuess(
    before: pos.eligible,
    guess: w,
    after: pos.eligible,
    landscape: pos.landscape,
    weights: weights,
    earlier: earlier,
    earlierMarks: earlierMarks,
  );
  final profiles = [
    for (final w in recommendationCandidates(pos.eligible, guessable))
      profile(w),
  ];
  OpeningExample example(Behaviour b, StyleProfile p, bool ok) =>
      OpeningExample(
        behaviour: b,
        profile: p,
        walk: walkGroups(pos.eligible, p.guess, weights),
        qualifies: ok,
      );
  StyleProfile? best(
    bool Function(StyleProfile) test,
    double Function(StyleProfile) by,
  ) {
    StyleProfile? pick;
    for (final p in profiles.where(test)) {
      if (pick == null || by(p) > by(pick)) pick = p;
    }
    return pick;
  }

  final maximiser =
      best((p) => p.behaviour == Behaviour.maximiser, (p) => p.skill) ??
      profile(pos.landscape.top.first.word);
  final eliminator = best(
    (p) => p.behaviour == Behaviour.eliminator,
    (p) => p.skill,
  );
  final gambler = best((p) => p.behaviour == Behaviour.gambler, (p) => p.skill);
  return [
    example(Behaviour.gambler, gambler ?? _riskiest(profiles), gambler != null),
    example(
      Behaviour.maximiser,
      maximiser,
      maximiser.behaviour == Behaviour.maximiser,
    ),
    example(
      Behaviour.eliminator,
      eliminator ?? _mostFresh(profiles),
      eliminator != null,
    ),
  ];
}

StyleProfile _riskiest(List<StyleProfile> ps) =>
    ps.reduce((a, b) => (a.risk ?? 0) >= (b.risk ?? 0) ? a : b);

StyleProfile _mostFresh(List<StyleProfile> ps) =>
    ps.reduce((a, b) => a.fresh >= b.fresh ? a : b);

/// What a closing example shows: a position where the best guess is a closer (a
/// word that fits) or a prober (one that does not).
class ClosingExample {
  const ClosingExample(this.behaviour, this.question);
  final Behaviour behaviour;
  final DrillQuestion question;

  /// The best guess of the options.
  DrillOption get best => question.options.firstWhere(question.isRight);

  /// The best option of the other kind (a word that fits against one that does
  /// not), or null when there is none among the options.
  DrillOption? get other {
    DrillOption? pick;
    final fitsBest = question.eligible.contains(best.word);
    for (final o in question.options) {
      if (question.eligible.contains(o.word) == fitsBest) continue;
      if (pick == null || (o.win ?? 0) > (pick.win ?? 0)) pick = o;
    }
    return pick;
  }
}

/// Looks through endgame positions for one where the best guess is a closer and
/// one where it is a prober: tries seeds until it has both, or [attempts] have
/// been used. Each found is passed to [onFound] as it comes, so the page fills
/// in.
Future<List<ClosingExample>> closingExamples({
  required WordBank bank,
  required int length,
  required Draw draw,
  int attempts = 60,
  void Function(ClosingExample)? onFound,
}) async {
  final found = <Behaviour, ClosingExample>{};
  for (var seed = 0; seed < attempts && found.length < 2; seed++) {
    final q = await buildClosingQuestion(
      bank: bank,
      length: length,
      draw: draw,
      rng: Random(seed * 31 + 7),
      attempts: 8,
    );
    if (q == null) continue;
    final best = q.options.firstWhere(q.isRight);
    final b = q.eligible.contains(best.word)
        ? Behaviour.closer
        : Behaviour.prober;
    if (found.containsKey(b)) continue;
    final e = ClosingExample(b, q);
    found[b] = e;
    onFound?.call(e);
  }
  return [
    for (final b in [Behaviour.closer, Behaviour.prober]) ?found[b],
  ];
}
