import 'history.dart';

/// How a player plays, read from their last 100 classic games (a daily is a
/// classic game) and shown on the home page. It moves as they play.
///
/// A style is two habits: what the player does in the early game, and what they
/// do at the end. Each guess in those phases is counted as one of five things,
/// and a habit is the thing a player's guesses most often are:
///
/// * early game, 64 or more words still possible: a [Behaviour.gambler] (risk of
///   [gamblerRisk] or more), else a [Behaviour.maximiser] (in the top
///   [topRank]% of the guesses scored by expected gain), else an
///   [Behaviour.eliminator] ([freshLetters] or more letters never tried);
/// * end game, 16 or fewer words possible or 3 or more greens known: a
///   [Behaviour.closer] (the guess fits every clue, so it can win), else a
///   [Behaviour.prober] (it does not fit, ranks in the top [topRank]% and 3 or
///   more words are left).
///
/// The first that applies is the one counted, so a risky guess is never also a
/// maximiser. A habit needs [habitShare] of a phase's guesses, and a player is
/// rated once there are [minRatedGames] games and [minPhaseGuesses] guesses in
/// each phase. The numbers come from simulated players of each style played
/// through the real word list (docs/paper, the playstyle section); they are not
/// measured on people, so they are the first thing to revisit once there is real
/// play to look at.

/// The phases a guess is counted in.
enum Phase { early, middle, end }

/// What a guess can be counted as, with the phase it belongs to.
enum Behaviour {
  gambler('gambler', 'dice-5', Phase.early),
  maximiser('maximiser', 'diamond', Phase.early),
  eliminator('eliminator', 'apps', Phase.early),
  closer('closer', 'bolt', Phase.end),
  prober('prober', 'microscope', Phase.end);

  const Behaviour(this.label, this.icon, this.phase);

  /// Its name, the name of a Tabler filled icon in assets/icons, and its phase.
  final String label;
  final String icon;
  final Phase phase;

  /// What it is, in a line.
  String get what => switch (this) {
    gambler => 'you gambled on the tail: usually less than expected, sometimes much more',
    maximiser => 'you played one of the best splits',
    eliminator => 'you used fresh letters to clear the board',
    closer => 'you went for the word',
    prober => 'you spent a guess to split the last words',
  };

  /// The rule that counts a guess as it.
  String get rule => switch (this) {
    gambler => 'a risk of $gamblerRisk or more',
    maximiser =>
      'in the top $topRank% of all the guesses scored, by expected gain',
    eliminator => '$freshLetters or more letters never tried in the game',
    closer => 'the guess fits every clue, so it can win',
    prober =>
      'the guess does not fit, ranks in the top $topRank% and 3 or more words are left',
  };
}

/// The early game starts at this many words possible; the end game is this few
/// or fewer, or [endGreens] known greens.
const earlyFrom = 64;
const endUpTo = 16;
const endGreens = 3;

/// A guess with a risk of this much or more is a gamble.
const gamblerRisk = 75;

/// A guess in the top this share (percent) by expected gain is a maximiser, or
/// a prober.
const topRank = 10;

/// How many letters new to the game make an eliminator.
const freshLetters = 4;

/// The share of a phase's guesses that makes a habit.
const habitShare = 0.4;

/// How much closer to the top the habit a player has now may be before it is
/// kept, so one game either side of a line does not swap their style back and
/// forth.
const habitMargin = 0.05;

/// The games, and the guesses in each phase, it takes before a player is rated.
const minRatedGames = 10;
const minPhaseGuesses = 10;

/// The games a playstyle is read from.
const styleWindow = 100;

/// The phase of a guess made with [before] words possible and [greens] known; null
/// with one word left, when there is nothing to choose.
Phase? phaseOf(int before, int greens) {
  if (before <= 1) return null;
  if (before >= earlyFrom) return Phase.early;
  if (before <= endUpTo || greens >= endGreens) return Phase.end;
  return Phase.middle;
}

/// What a guess is counted as, or null when it is neither (a middle game guess,
/// or one that does not qualify). Only classic guesses have what it needs.
Behaviour? behaviourOf(GuessRow r) => behaviourFor(
  before: r.before,
  greens: r.greens,
  risk: r.risk,
  rank: r.rank,
  fresh: r.fresh,
  fits: r.fits,
);

/// The same rule on the numbers themselves, so that a guess that was not played
/// (a learn mode example) is counted just as a played one is. [risk] and [rank]
/// are null when not known.
Behaviour? behaviourFor({
  required int before,
  required int greens,
  required double? risk,
  required double? rank,
  required int fresh,
  required bool fits,
}) {
  switch (phaseOf(before, greens)) {
    case null:
    case Phase.middle:
      return null;
    case Phase.early:
      if (risk != null && risk >= gamblerRisk) return Behaviour.gambler;
      if (rank != null && rank <= topRank) return Behaviour.maximiser;
      if (fresh >= freshLetters) return Behaviour.eliminator;
      return null;
    case Phase.end:
      if (fits) return Behaviour.closer;
      if (rank != null && rank <= topRank && before >= 3) {
        return Behaviour.prober;
      }
      return null;
  }
}

/// A playstyle: an early habit and an end habit.
class Playstyle {
  const Playstyle(
    this.id,
    this.name,
    this.icon,
    this.early,
    this.end,
    this.blurb,
  );

  /// Saved, so it must not change.
  final String id;
  final String name;

  /// Name of a Tabler filled icon in assets/icons.
  final String icon;

  /// Its habit in the early game and at the end.
  final Behaviour early;
  final Behaviour end;
  final String blurb;
}

const analyst = Playstyle(
  'analyst',
  'analyst',
  'microscope',
  Behaviour.maximiser,
  Behaviour.prober,
  'plays the best splits all game, and spends a guess to split the last words '
      'when it must',
);
const maverick = Playstyle(
  'maverick',
  'maverick',
  'chess-knight',
  Behaviour.maximiser,
  Behaviour.closer,
  'plays the best splits early, then goes for the word as soon as one fits',
);
const detective = Playstyle(
  'detective',
  'detective',
  'zoom-question',
  Behaviour.eliminator,
  Behaviour.prober,
  'clears letters first, then splits the last candidates before committing',
);
const sweeper = Playstyle(
  'sweeper',
  'sweeper',
  'trash-x',
  Behaviour.eliminator,
  Behaviour.closer,
  'clears letters first, then goes straight for the word',
);
const wildcard = Playstyle(
  'wildcard',
  'wildcard',
  'cards',
  Behaviour.gambler,
  Behaviour.prober,
  'gambles on the first turns, then settles into proper splits',
);
const gambler = Playstyle(
  'gambler',
  'gambler',
  'dice-5',
  Behaviour.gambler,
  Behaviour.closer,
  'gambles on the first turns and goes all in for the word',
);

/// Every playstyle, in the order of its grid: the early habit down, the end
/// habit across.
const playstyles = [analyst, maverick, detective, sweeper, wildcard, gambler];

Playstyle? playstyleById(String? id) {
  for (final p in playstyles) {
    if (p.id == id) return p;
  }
  return null;
}

/// The playstyle with these two habits.
Playstyle styleOf(Behaviour early, Behaviour end) => playstyles.firstWhere(
  (p) => p.early == early && p.end == end,
  orElse: () => throw ArgumentError('no style for $early and $end'),
);

/// A player's two numbers over their last games, and how many they come from.
class Traits {
  const Traits({
    required this.skill,
    required this.risk,
    required this.luck,
    required this.games,
    required this.guesses,
  });

  /// Means over the guesses that had a choice (more than one word possible).
  final double skill;
  final double risk;
  final double luck;

  /// How many games, and how many guesses with a choice, they come from.
  final int games;
  final int guesses;
}

/// The means over the last [n] classic games of [h]; null when there is no guess
/// with a choice in them at all.
Traits? traitsOf(History h, {int n = styleWindow, String? lang}) =>
    traitsOfGames(h, h.recentClassic(n, lang));

/// The means over [games] of [h] (classic ones: the others have no risk).
Traits? traitsOfGames(History h, List<GameRow> games) {
  var skill = 0.0, risk = 0.0, luck = 0.0;
  var skillN = 0, riskN = 0;
  for (final g in games) {
    for (final r in h.guessesOf(g.id)) {
      // with one word left there is nothing to choose and nothing to score
      if (r.before <= 1) continue;
      skill += r.skill;
      luck += r.luck;
      skillN++;
      final k = r.risk;
      if (k != null) {
        risk += k;
        riskN++;
      }
    }
  }
  if (riskN == 0) return null;
  return Traits(
    skill: skill / skillN,
    risk: risk / riskN,
    luck: luck / skillN,
    games: games.length,
    guesses: riskN,
  );
}

/// What a player's guesses were counted as, phase by phase.
class Habits {
  const Habits(this.games, this.counts, this.opportunities);

  /// How many games it is read from.
  final int games;

  /// How many guesses were counted as each behaviour, and how many guesses there
  /// were in each phase (early and end).
  final Map<Behaviour, int> counts;
  final Map<Phase, int> opportunities;

  /// The share of [phase]'s guesses counted as [b].
  double share(Behaviour b) {
    final n = opportunities[b.phase] ?? 0;
    return n == 0 ? 0 : (counts[b] ?? 0) / n;
  }

  /// Whether there are enough guesses in both phases to rate.
  bool get rated =>
      games >= minRatedGames &&
      (opportunities[Phase.early] ?? 0) >= minPhaseGuesses &&
      (opportunities[Phase.end] ?? 0) >= minPhaseGuesses;

  /// The habit of [phase]: the behaviour with the largest share, if that is
  /// [habitShare] or more. Ties go to the first listed in [Behaviour].
  Behaviour? habit(Phase phase) {
    Behaviour? best;
    var top = 0.0;
    for (final b in Behaviour.values) {
      if (b.phase != phase) continue;
      if (share(b) > top + 1e-9) {
        top = share(b);
        best = b;
      }
    }
    return top >= habitShare ? best : null;
  }
}

/// The habits over the last [n] classic games of [h] in [lang].
Habits habitsOf(History h, {int n = styleWindow, String? lang}) =>
    habitsOfGames(h, h.recentClassic(n, lang));

/// The habits over [games] of [h] (classic ones, scored with the current maths).
Habits habitsOfGames(History h, List<GameRow> games) {
  final counts = {for (final b in Behaviour.values) b: 0};
  final opportunities = {Phase.early: 0, Phase.end: 0};
  for (final g in games) {
    if (g.version != metricsVersion) continue;
    for (final r in h.guessesOf(g.id)) {
      final phase = phaseOf(r.before, r.greens);
      if (phase == Phase.early || phase == Phase.end) {
        opportunities[phase!] = opportunities[phase]! + 1;
      }
      final b = behaviourOf(r);
      if (b != null) counts[b] = counts[b]! + 1;
    }
  }
  return Habits(games.length, counts, opportunities);
}

/// The playstyle of [h]'s habits; null while they are not rated, or when a phase
/// has no habit. [current] is the one they have now: its habit in a phase is
/// kept while it stays within [habitMargin] of the top (and still counts).
Playstyle? classify(Habits? h, {Playstyle? current}) {
  if (h == null || !h.rated) return null;
  Behaviour? pick(Phase phase, Behaviour? now) {
    final top = h.habit(phase);
    if (top == null) return null;
    if (now != null &&
        now != top &&
        h.share(now) >= habitShare &&
        h.share(top) - h.share(now) < habitMargin) {
      return now;
    }
    return top;
  }

  final early = pick(Phase.early, current?.early);
  final end = pick(Phase.end, current?.end);
  if (early == null || end == null) return null;
  return styleOf(early, end);
}
