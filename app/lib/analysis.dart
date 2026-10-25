import 'daily.dart';
import 'history.dart';
import 'playstyle.dart';

/// What a set of games adds up to. The means of skill, luck and daring are over
/// the guesses of the games scored with the current maths ([metricsVersion]); a
/// game saved under older maths still counts as played and won, but is left out
/// of the means until it has been scored again, so that two weeks are never
/// compared by two different rulers ([stale] says how many).
class PlayStats {
  const PlayStats({
    this.games = 0,
    this.won = 0,
    this.classic = 0,
    this.scored = 0,
    this.skill = 0,
    this.luck = 0,
    this.daring,
    this.meanTries,
    this.stale = 0,
  });

  final int games;
  final int won;

  /// How many were classic (the only ones with a daring).
  final int classic;

  /// How many guesses the means are over.
  final int scored;
  final double skill;
  final double luck;

  /// Null when no guess in them had a daring.
  final double? daring;

  /// Guesses used per won game; null when none was won.
  final double? meanTries;

  /// Games left out of the means for being scored with older maths.
  final int stale;

  /// Percent of the games that were won; 0 for none.
  double get winRate => games == 0 ? 0 : won / games * 100;

  bool get isEmpty => games == 0;
}

/// Adds up [games] of [h]. A guess with one word left is left out of a classic
/// game's means (nothing to choose, nothing to score); in a quartet or relay race
/// every step counts, since its skill and luck are means over its boards.
PlayStats summarise(History h, Iterable<GameRow> games) {
  var n = 0, won = 0, classic = 0, stale = 0;
  var scored = 0, daringN = 0, wonN = 0;
  var skill = 0.0, luck = 0.0, daring = 0.0, tries = 0.0;
  for (final g in games) {
    n++;
    if (g.isClassic) classic++;
    final rows = h.guessesOf(g.id);
    if (g.won) {
      won++;
      wonN++;
      tries += rows.length;
    }
    if (g.version != metricsVersion) {
      stale++;
      continue;
    }
    for (final r in rows) {
      if (g.isClassic && r.before <= 1) continue;
      skill += r.skill;
      luck += r.luck;
      scored++;
      final d = r.daring;
      if (d != null) {
        daring += d;
        daringN++;
      }
    }
  }
  return PlayStats(
    games: n,
    won: won,
    classic: classic,
    scored: scored,
    skill: scored == 0 ? 0 : skill / scored,
    luck: scored == 0 ? 0 : luck / scored,
    daring: daringN == 0 ? null : daring / daringN,
    meanTries: wonN == 0 ? null : tries / wonN,
    stale: stale,
  );
}

/// One stretch of time in the history: a week or a month, what was played in it,
/// and the playstyle that stretch alone would have (null when it holds too little
/// classic play to rate).
class Period {
  const Period({
    required this.label,
    required this.start,
    required this.end,
    required this.stats,
    this.style,
  });

  /// The window ending [end] (inclusive) and starting [start], as
  /// `2026-10-24`; for a month, its first and last day.
  final String label;
  final String start;
  final String end;
  final PlayStats stats;
  final Playstyle? style;
}

/// The number of whole days from the epoch to [date] (`2026-10-24`).
int _dayNumber(String date) {
  final d = DateTime.parse(date);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      86400000;
}

String _localDate(int ms) =>
    dailyDate(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));

Period _period(
  History h,
  String label,
  String start,
  String end,
  List<GameRow> games,
) => Period(
  label: label,
  start: start,
  end: end,
  stats: summarise(h, games),
  style: classify(
    traitsOfGames(h, [
      for (final g in games)
        if (g.isClassic && g.version == metricsVersion) g,
    ]),
  ),
);

/// The last [count] weeks, oldest first: rolling windows of seven days, the
/// last of them ending [today], as the daily's week does (so the last is always
/// the past seven days, and each earlier one the seven before it). Weeks with no
/// games are there, empty. Games dated after [today] (a clock that was wrong)
/// are counted in the last.
List<Period> weeklyPeriods(
  History h,
  String today, {
  int count = 50,
  String? lang,
}) {
  final todayN = _dayNumber(today);
  final buckets = List.generate(count, (_) => <GameRow>[]);
  for (final g in h.games) {
    if (lang != null && g.lang != lang) continue;
    final ago = todayN - _dayNumber(_localDate(g.at));
    final i = (ago < 0 ? 0 : ago) ~/ 7;
    if (i < count) buckets[i].add(g);
  }
  return [
    for (var i = count - 1; i >= 0; i--)
      _period(
        h,
        dailyShift(today, -i * 7),
        dailyShift(today, -(i * 7 + 6)),
        dailyShift(today, -i * 7),
        buckets[i],
      ),
  ];
}

/// The last [count] calendar months, oldest first, the last of them the month
/// of [today] (so far). Months with no games are there, empty.
List<Period> monthlyPeriods(
  History h,
  String today, {
  int count = 50,
  String? lang,
}) {
  final t = DateTime.parse(today);
  final todayKey = t.year * 12 + t.month - 1;
  final buckets = List.generate(count, (_) => <GameRow>[]);
  for (final g in h.games) {
    if (lang != null && g.lang != lang) continue;
    final d = DateTime.parse(_localDate(g.at));
    final ago = todayKey - (d.year * 12 + d.month - 1);
    final i = ago < 0 ? 0 : ago;
    if (i < count) buckets[i].add(g);
  }
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final key = todayKey - i;
        final y = key ~/ 12, m = key % 12 + 1;
        final last = DateTime.utc(y, m + 1, 0).day;
        final label = '$y-${two(m)}';
        return _period(
          h,
          label,
          '$label-01',
          '$label-${two(last)}',
          buckets[i],
        );
      }(),
  ];
}

/// The expected number of guesses a game takes, read from skill, luck and
/// daring by the linear fit of tools/predict_tries3.dart (the mean of its fits
/// under the three answer laws, every word equally likely, by frequency, and
/// the daily, English at five letters, 2,500 games each, docs/paper Section
/// 9.6):
///
///   guesses = 9.38 - 0.0563 skill - 0.0164 luck - 0.0445 daring
///
/// with skill and daring from 0 to 100 and luck from -100 to 100. It is an
/// estimate from simulated players, not measured on people. The terms are shown
/// as what each one does to a base: skill is never worse than none, so it only
/// takes guesses off; luck takes off when positive and adds when negative; daring
/// is measured from a typical level, [daringTypical], so going for the word less
/// than usual adds guesses and more takes them off.
const guessIntercept = 9.38;
const guessPerSkill = -0.0563;
const guessPerLuck = -0.0164;
const guessPerDaring = -0.0445;
const daringTypical = 10.0;

/// What skill, luck and daring did to the expected guesses of a period.
class GuessBreakdown {
  const GuessBreakdown(this.base, this.skill, this.luck, this.daring);

  /// What a player with no skill, average luck and typical daring is expected
  /// to need.
  final double base;

  /// Each term, in guesses: negative takes guesses off.
  final double skill, luck, daring;

  /// The expected guesses, kept within the 1 to 7 a game can take (7 for a
  /// game not solved).
  double get total => (base + skill + luck + daring).clamp(1.0, 7.0);
}

/// The breakdown for [s], or null when it lacks a score or a daring.
GuessBreakdown? guessBreakdown(PlayStats s) {
  final d = s.daring;
  if (s.isEmpty || s.scored == 0 || d == null) return null;
  return breakdownOf(s.skill, s.luck, d);
}

/// The breakdown for means of [skill], [luck] and [daring]. With no daring
/// (null) that term is 0, as for a typical daring.
GuessBreakdown breakdownOf(double skill, double luck, double? daring) =>
    GuessBreakdown(
      guessIntercept + guessPerDaring * daringTypical,
      guessPerSkill * skill,
      guessPerLuck * luck,
      daring == null ? 0 : guessPerDaring * (daring - daringTypical),
    );

/// The measures the chart of periods follows, each a line. The first three are
/// drawn on a scale from 0 to 100; the expected guesses are drawn against their
/// own scale, from 1 to 7, at the right edge.
enum PeriodSeries {
  skill('skill'),
  luck('luck'),
  daring('daring'),
  guesses('guesses');

  const PeriodSeries(this.label);
  final String label;

  /// The value of [s] as the measure itself (skill and daring 0 to 100, luck
  /// -100 to 100), or null when there is none: no games, nothing scored, or no
  /// daring to average.
  double? of(PlayStats s) {
    if (s.isEmpty || s.scored == 0) return null;
    if (this == PeriodSeries.guesses) return guessBreakdown(s)?.total;
    return switch (this) {
      PeriodSeries.skill => s.skill,
      PeriodSeries.luck => s.luck,
      PeriodSeries.daring => s.daring,
      PeriodSeries.guesses => null,
    };
  }

  /// Where it is drawn, 0 to 100 on the one axis. Skill and daring are as they
  /// are; luck, which runs from -100 to 100 about 0, is shifted to sit about 50,
  /// so the middle of the chart is a luck of 0%.
  double? plot(PlayStats s) {
    final v = of(s);
    if (v == null) return null;
    // the guesses run from 1 (the bottom) to 7 (the top) on the right scale
    if (this == PeriodSeries.guesses) return (v - 1) / 6 * 100;
    return this == PeriodSeries.luck ? (v + 100) / 2 : v;
  }
}
