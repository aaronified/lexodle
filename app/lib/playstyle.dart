import 'history.dart';

/// How a player plays, read from their last 100 classic games (a daily is a
/// classic game) and shown on the home page. It moves as they play.
///
/// Two traits are averaged over every guess of those games in which there was
/// something to choose between (more than one word still possible):
///
/// * **skill**, 0 to 100: how evenly the guess split the words (see logic.dart);
/// * **daring**, 0 to 100: of the guesses that scored higher skill, how many were
///   less risky than the one played; the best guess has nothing better to compare
///   with, so it has none.
///
/// Skill gives three tiers and daring splits each in two, which is six styles.
/// The numbers below were set by playing simulated players through the real
/// maths (tools/calibrate_styles.dart, results in docs/paper/experiments/results/
/// daring_calibration.txt): a player who always plays the best guess scores 100
/// and 0, one who picks at random among the three best 99 and 12, one who plays
/// the commonest word that fits about 65 and 62, one who ignores the clues about
/// 47 and 48. They are not measured on people, so they are the first thing to
/// revisit once there is real play to look at.
class Playstyle {
  const Playstyle(
    this.id,
    this.name,
    this.icon,
    this.sharpness,
    this.bold,
    this.blurb,
  );

  /// Saved, so it must not change.
  final String id;
  final String name;

  /// Name of a Tabler filled icon in assets/icons.
  final String icon;

  /// The skill tier, 0 loose, 1 solid, 2 sharp, and whether it is the daring
  /// half of it.
  final int sharpness;
  final bool bold;
  final String blurb;
}

const analyst = Playstyle(
  'analyst',
  'analyst',
  'microscope',
  2,
  false,
  'sharp and careful: guesses that split the words well, and few gambles',
);
const maverick = Playstyle(
  'maverick',
  'maverick',
  'chess-knight',
  2,
  true,
  'sharp, and happy to take a bolder line than it needs to',
);
const steady = Playstyle(
  'steady',
  'steady',
  'scale',
  1,
  false,
  'solid, dependable guesses and no gambles',
);
const gambler = Playstyle(
  'gambler',
  'gambler',
  'dice-5',
  1,
  true,
  'plays the odds: decent guesses with a taste for risk',
);
const wanderer = Playstyle(
  'wanderer',
  'wanderer',
  'feather',
  0,
  false,
  'plays by feel, lightly and safely',
);
const wildcard = Playstyle(
  'wildcard',
  'wildcard',
  'cards',
  0,
  true,
  'unpredictable: risky guesses and little method',
);

/// Every playstyle, from the sharpest careful one to the loosest bold one.
const playstyles = [analyst, maverick, steady, gambler, wanderer, wildcard];

Playstyle? playstyleById(String? id) {
  for (final p in playstyles) {
    if (p.id == id) return p;
  }
  return null;
}

/// The games a playstyle is read from.
const styleWindow = 100;

/// How many classic games, and how many guesses with a daring, it takes before a
/// player is rated at all.
const minRatedGames = 10;
const minRatedGuesses = 20;

/// Where the tiers and the daring split lie. A guess that is skilled is
/// [sharpFrom] or more; one below [looseBelow] is loose. The daring split is a
/// little different in each tier, because daring and skill go together (a weak
/// guess usually has many safer, better ones above it), so "bold" is bolder
/// than a typical player of that skill.
const sharpFrom = 85.0;
const looseBelow = 58.0;
const _splitSharp = 40.0;
const _splitSolid = 65.0;
const _splitLoose = 52.0;

/// How far past a line a player must go to leave the style they have, so one
/// game either side of a line does not swap their style back and forth.
const skillMargin = 3.0;
const daringMargin = 5.0;

double _splitFor(int tier) => switch (tier) {
  2 => _splitSharp,
  1 => _splitSolid,
  _ => _splitLoose,
};

/// A player's two traits over their last games.
class Traits {
  const Traits({
    required this.skill,
    required this.daring,
    required this.games,
    required this.guesses,
  });

  /// Means over the guesses that had a choice (see above).
  final double skill;
  final double daring;

  /// How many games and how many such guesses they come from.
  final int games;
  final int guesses;

  /// Whether there is enough to rate a player on.
  bool get rated => games >= minRatedGames && guesses >= minRatedGuesses;
}

/// The traits over the last [n] classic games of [h]; null when there is no
/// guess with a daring in them at all.
Traits? traitsOf(History h, {int n = styleWindow}) {
  final games = h.recentClassic(n);
  var skill = 0.0, daring = 0.0;
  var skillN = 0, daringN = 0;
  for (final g in games) {
    for (final r in h.guessesOf(g.id)) {
      // with one word left there is nothing to choose and nothing to score
      if (r.before <= 1) continue;
      skill += r.skill;
      skillN++;
      final d = r.daring;
      if (d != null) {
        daring += d;
        daringN++;
      }
    }
  }
  if (daringN == 0) return null;
  return Traits(
    skill: skill / skillN,
    daring: daring / daringN,
    games: games.length,
    guesses: daringN,
  );
}

/// The skill tier of [skill] (0 loose, 1 solid, 2 sharp), staying in the tier of
/// [current] unless [skill] is past its edge by more than [skillMargin].
int tierOf(double skill, {int? current}) {
  int raw(double s) => s >= sharpFrom
      ? 2
      : s < looseBelow
      ? 0
      : 1;
  if (current != null) {
    final lo = switch (current) {
      2 => sharpFrom,
      1 => looseBelow,
      _ => double.negativeInfinity,
    };
    final hi = switch (current) {
      2 => double.infinity,
      1 => sharpFrom,
      _ => looseBelow,
    };
    if (skill >= lo - skillMargin && skill < hi + skillMargin) return current;
  }
  return raw(skill);
}

/// The playstyle of [t]; null while they are not rated. [current] is the one
/// they have now: it is kept while they stay near it (see [skillMargin]).
Playstyle? classify(Traits? t, {Playstyle? current}) {
  if (t == null || !t.rated) return null;
  final tier = tierOf(t.skill, current: current?.sharpness);
  final split = _splitFor(tier);
  var bold = t.daring >= split;
  if (current != null &&
      current.sharpness == tier &&
      (t.daring - split).abs() < daringMargin) {
    bold = current.bold;
  }
  return playstyles.firstWhere((p) => p.sharpness == tier && p.bold == bold);
}
