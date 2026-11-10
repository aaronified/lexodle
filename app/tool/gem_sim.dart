// Gem earn-rate simulation. Plays 1000 synthetic games (and learn rounds)
// through the app's real achievement engine and counts what gems would pay.
//
//   flutter test tool/gem_sim.dart
//
// It lives in tool/, not test/, so CI does not run it. The game outcomes are
// modelled (see Profile); the achievement rules are the app's own.
//
//   one perfect game, then
//   eleven gems for the same
//   hints grow cheap as dust

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';

const gemOf = [1, 2, 3, 5]; // bronze, silver, gold, platinum
const languages = 20;

/// How many lex a repeat earns less than the first time (0: the same).
const repeatLess = 0;

final rnd = Random(7);
double gauss(double m, double s) {
  final u = 1 - rnd.nextDouble(), v = rnd.nextDouble();
  return m + s * sqrt(-2 * log(u)) * cos(2 * pi * v);
}

double clamp(double x, double lo, double hi) => x < lo ? lo : (x > hi ? hi : x);

/// How a player plays: the numbers the games are drawn from.
class Profile {
  const Profile(
    this.name, {
    required this.skill,
    required this.skillSd,
    required this.winP,
    required this.usedDelta,
    required this.usedSd,
    required this.luckSd,
    required this.risk,
    required this.bits,
    required this.flawlessHearts,
  });
  final String name;
  final double skill, skillSd, winP, usedDelta, usedSd, luckSd, risk, bits;
  final double flawlessHearts;
}

/// A dedicated player, unaided: decent but human.
const human = Profile(
  'dedicated, unaided',
  skill: 84,
  skillSd: 9,
  winP: .95,
  usedDelta: 0,
  usedSd: 1.0,
  luckSd: 28,
  risk: 30,
  bits: 6.0,
  flawlessHearts: .55,
);

/// A farmer who plays the solver's best guess every turn.
const solver = Profile(
  'solver-assisted',
  skill: 99.3,
  skillSd: 1.2,
  winP: .995,
  usedDelta: -.3,
  usedSd: .7,
  luckSd: 35,
  risk: 8,
  bits: 6.5,
  flawlessHearts: .98,
);

const _tries = {
  GameMode.classic: 6,
  GameMode.quartet: 9,
  GameMode.relay: 10,
  GameMode.lockdown: 6,
  GameMode.blind: 8,
  GameMode.equations: 6,
  GameMode.mastermind: 30,
};
const _usedMean = {
  GameMode.classic: 3.9,
  GameMode.quartet: 7.2,
  GameMode.relay: 8.3,
  GameMode.lockdown: 4.1,
  GameMode.blind: 6.0,
  GameMode.equations: 4.3,
  GameMode.mastermind: 7.5,
};

GameResult game(
  Profile p,
  GameMode mode, {
  bool daily = false,
  String date = '',
  int streak = 0,
  int stylesHeld = 1,
}) {
  final tries = _tries[mode]!;
  var used = gauss(_usedMean[mode]! + p.usedDelta, p.usedSd).round();
  used = used.clamp(1, tries);
  final won = rnd.nextDouble() < p.winP;
  if (!won) used = tries;
  final skills = [
    for (var i = 0; i < used; i++)
      clamp(gauss(p.skill, p.skillSd), 0, 100).toDouble(),
  ];
  final flawless = rnd.nextDouble() < p.flawlessHearts;
  final left = flawless ? 3 : (rnd.nextDouble() < .65 ? 2 : 1);
  final classic = mode == GameMode.classic;
  return GameResult(
    lang: 'en',
    length: 5,
    tries: tries,
    used: used,
    won: won,
    skills: skills,
    mode: mode,
    daily: daily,
    dailyStreak: streak,
    date: date,
    stylesHeld: stylesHeld,
    luck: clamp(gauss(0, p.luckSd), -100, 100),
    risk: classic ? clamp(gauss(p.risk, 14), 0, 100) : null,
    maxBits: classic ? max(0, gauss(p.bits, 1.3)) : 0,
    freeRides: mode == GameMode.relay && rnd.nextDouble() < .2 ? 1 : 0,
    lateSingles:
        (mode == GameMode.relay || mode == GameMode.quartet) &&
        rnd.nextDouble() < (p == solver ? .15 : .03),
    hearts: mode == GameMode.lockdown ? 3 : 0,
    heartsLeft: mode == GameMode.lockdown ? (won ? left : 0) : 0,
    largest: false,
  );
}

/// What a run paid, under five rules (see the questions in issue #89):
/// v0 every level of every repeat (what "repeats count" literally means),
/// v1 only the top level of each achievement a game earned,
/// v2 only the first time each level is ever earned,
/// v3 first time, plus one repeat (the best) per achievement per day,
/// v5 top level per achievement per game, each achievement once a day,
/// v6 as v5, but once a day in each language (the app keeps one set each),
/// v4 first time, plus repeats of the counting achievements only (the
///    best-of ones, which pay on every good game, pay nothing again).
class Tally {
  static const rules = ['v0', 'v1', 'v2', 'v3', 'v4', 'v5', 'v6'];
  final units = {for (final r in rules) r: <int>[]}; // gems of each game
  final bySource = <String, int>{};
  final seen = <String>{};
  final paidToday = <String>{};
  final paidDay = <String>{};
  int first = 0, repeat = 0, events = 0;

  int total(String r) => units[r]!.fold(0, (x, y) => x + y);
  int get v0 => total('v0');
  int get v1 => total('v1');
  int get v2 => total('v2');
  List<int> get perUnit => units['v0']!;

  void add(List<Achievement> earned, [String date = '', String lang = 'en']) {
    int g0 = 0, g2 = 0, g3 = 0, g4 = 0, g5 = 0, g6 = 0;
    final bestRepeat = <String, int>{};
    final firstKeys = <String>{};
    for (final a in earned) {
      if (a.track == Track.badges) continue;
      final full = gemOf[a.medal.index];
      final isFirst = seen.add('${a.id}:${a.level}');
      // a repeat earns one less than the first time (bronze nothing)
      final g = isFirst ? full : max(0, full - repeatLess);
      if (isFirst) firstKeys.add('${a.id}:${a.level}');
      g0 += g;
      bySource[a.id] = (bySource[a.id] ?? 0) + g;
      if (isFirst) {
        g2 += g;
        g3 += g;
        g4 += g;
        first += g;
      } else {
        repeat += g;
        if ((bestRepeat[a.id] ?? 0) < g) bestRepeat[a.id] = g;
        if (a.cycles) g4 += g;
      }
    }
    for (final e in bestRepeat.entries) {
      if (paidToday.add('${e.key}@$date')) g3 += e.value;
    }
    var g1 = 0;
    for (final a in topLevels(earned)) {
      if (a.track == Track.badges) continue;
      final full = gemOf[a.medal.index];
      if (paidDay.add('${a.id}@$date')) g5 += full;
      if (paidDay.add('${a.id}@$date@$lang')) g6 += full;
      g1 += firstKeys.contains('${a.id}:${a.level}') ? full : max(0, full - repeatLess);
    }
    for (final (r, g) in [('v0', g0), ('v1', g1), ('v2', g2), ('v3', g3), ('v4', g4), ('v5', g5), ('v6', g6)]) {
      units[r]!.add(g);
    }
    events++;
  }
}

String two(int n) => n.toString().padLeft(2, '0');
String dateOf(int day) {
  final d = DateTime(2026, 1, 1).add(Duration(days: day));
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

const _counts = {'langs': 1, 'mastered': 0, 'completed': 0};

Tally runDailies(Profile p, int games) {
  final states = <String, AchState>{};
  final t = Tally();
  final streak = <GameMode, int>{};
  final modes = [
    GameMode.classic,
    GameMode.quartet,
    GameMode.relay,
    GameMode.lockdown,
    GameMode.blind,
    GameMode.equations,
  ];
  for (var i = 0; i < games; i++) {
    final day = i ~/ modes.length, m = modes[i % modes.length];
    final date = dateOf(day);
    var r = game(p, m, daily: true, date: date, stylesHeld: min(6, 1 + i ~/ 150));
    streak[m] = r.won ? (streak[m] ?? 0) + 1 : 0;
    r = GameResult(
      lang: r.lang, length: r.length, tries: r.tries, used: r.used, won: r.won,
      skills: r.skills, mode: r.mode, daily: true, dailyStreak: streak[m]!,
      date: date, stylesHeld: r.stylesHeld, luck: r.luck, risk: r.risk,
      maxBits: r.maxBits, freeRides: r.freeRides, lateSingles: r.lateSingles,
      hearts: r.hearts, heartsLeft: r.heartsLeft,
    );
    t.add(advanceAchievements(states, r, date, counts: _counts, languages: languages), date);
  }
  return t;
}

/// Unlimited, non-daily games of one mode, one after another.
Tally runFarm(Profile p, GameMode m, int games) {
  final states = <String, AchState>{};
  final t = Tally();
  for (var i = 0; i < games; i++) {
    final r = game(p, m, stylesHeld: 6);
    t.add(advanceAchievements(states, r, dateOf(i ~/ 50), counts: _counts, languages: languages), dateOf(i ~/ 50));
  }
  return t;
}


/// A farmer who plays [perDay] solver games a day over [days] days, rotating
/// the six daily modes and [langs] languages (each language has its own set
/// of achievements, as in the app).
Tally runFarmDays(int perDay, int days, int langs) {
  final states = [for (var l = 0; l < langs; l++) <String, AchState>{}];
  final t = Tally();
  const modes = [
    GameMode.classic, GameMode.quartet, GameMode.relay,
    GameMode.lockdown, GameMode.blind, GameMode.equations,
  ];
  for (var d = 0; d < days; d++) {
    for (var i = 0; i < perDay; i++) {
      final l = i % langs, m = modes[(i ~/ langs) % modes.length];
      final date = dateOf(d);
      final r = game(solver, m, stylesHeld: 6);
      t.add(
        advanceAchievements(states[l], r, date, counts: _counts, languages: languages),
        date,
        'l$l',
      );
    }
  }
  return t;
}

/// Learn events of one kind, cycled over the eight modes. [flawless] is the
/// chance a round of ten is all best; [best] the chance a sequence is as good
/// as the best found.
Tally runLearn(LearnKind kind, int events, {double flawless = .5, double best = .15}) {
  final states = <String, AchState>{};
  final t = Tally();
  for (var i = 0; i < events; i++) {
    final m = GameMode.values[i % GameMode.values.length];
    final q = switch (kind) {
      LearnKind.free => 4,
      LearnKind.sequence => 1,
      _ => 10,
    };
    final perfect = rnd.nextDouble() < (kind == LearnKind.sequence ? best : flawless);
    final right = perfect ? q : max(0, q - 1 - rnd.nextInt(2));
    final skill = perfect
        ? (kind == LearnKind.sequence ? 99.5 : 100.0)
        : clamp(gauss(88, 7), 60, 98.9).toDouble();
    final e = LearnEvent(
      kind: kind,
      language: 'en',
      length: 5,
      date: dateOf(i ~/ 40),
      questions: q,
      right: right,
      avgSkill: kind == LearnKind.choose ||
              kind == LearnKind.closing ||
              kind == LearnKind.clue
          ? 100.0 * right / q
          : skill,
      mode: m,
    );
    final earned = advanceLearnAchievements(states, e);
    t.add(earned, e.date);
  }
  return t;
}

void main() {
  test('gem earn rate', () {
    final out = StringBuffer();
    void p(String s) => out.writeln(s);
    p('# gem earn-rate simulation');
    p('');
    p('    one perfect game, then');
    p('    eleven gems for the same');
    p('    hints grow cheap as dust');
    p('');

    final nonGlobal = achievements.where((a) => !a.global).length;
    final glob = achievements.where((a) => a.global).length;
    p('achievements: ${achievements.length} ($levelCount levels); '
        'per-language: $nonGlobal, once-only (global/learn): $glob');
    final perLang = achievements.where((a) => !a.global).fold(0, (n, a) => n + a.levels.fold(0, (m, l) => m + gemOf[l.medal.index]));
    final once = achievements.where((a) => a.global).fold(0, (n, a) => n + a.levels.fold(0, (m, l) => m + gemOf[l.medal.index]));
    p('one-off pool: $perLang gems per language x $languages = ${perLang * languages}, '
        '+ $once once-only = ${perLang * languages + once}');
    p('');

    // 1. the dedicated daily player: 6 dailies a day, 1000 games
    final d = runDailies(human, 1000);
    final days = (1000 / 6).ceil();
    p('## 1. dedicated daily player: 1000 games = $days days of 6 dailies');
    p('| rule | gems | per day | per week |');
    p('|---|---|---|---|');
    for (final (n, v) in [
      ('v0 every repeat, every level', d.v0),
      ('v1 top level per achievement per game', d.v1),
      ('v2 first time only', d.v2),
    ]) {
      p('| $n | $v | ${(v / days).toStringAsFixed(1)} | ${(v * 7 / days).toStringAsFixed(0)} |');
    }
    p('v0 split: first-time ${d.first}, repeats ${d.repeat}');
    // timeline
    int cum = 0, day5 = -1, day10 = -1, day15 = -1;
    for (var i = 0; i < d.perUnit.length; i++) {
      cum += d.perUnit[i];
      final day = i ~/ 6 + 1;
      if (day5 < 0 && cum >= 5) day5 = day;
      if (day10 < 0 && cum >= 10) day10 = day;
      if (day15 < 0 && cum >= 15) day15 = day;
    }
    p('first day with 5 / 10 / 15 gems banked (v0): day $day5 / $day10 / $day15');
    p('');
    p('sensitivity: mean skill of the daily player (gems per day)');
    p('| mean skill | v0 | v1 | v2 |');
    p('|---|---|---|---|');
    for (final s in [60.0, 70.0, 78.0, 84.0, 90.0]) {
      final t = runDailies(
        Profile('s$s', skill: s, skillSd: 9, winP: .95, usedDelta: 0,
            usedSd: 1.0, luckSd: 28, risk: 30, bits: 6.0, flawlessHearts: .55),
        1000,
      );
      p('| ${s.toInt()} | ${(t.v0 / days).toStringAsFixed(1)} | '
          '${(t.v1 / days).toStringAsFixed(1)} | ${(t.v2 / days).toStringAsFixed(1)} |');
    }
    p('');
    for (final (a, b) in [(0, 30), (30, 60), (60, 100), (120, 167)]) {
      final g = d.perUnit.sublist(a * 6, min(b * 6, d.perUnit.length)).fold(0, (x, y) => x + y);
      p('gems per day, days $a-$b (v0): ${(g / (b - a)).toStringAsFixed(1)}');
    }
    final top = d.bySource.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    p('top v0 sources: ${top.take(8).map((e) => '${e.key} ${e.value}').join(', ')}');
    p('');

    // 2. farms: unlimited games, seconds per game assumed
    p('## 2. farming: 1000 non-daily games (or rounds), v0 / v1 / v2');
    p('| strategy | s each | gems v0 | per game v0 | v1/game | v2/game | v3/game | v4/game | min per 5-gem hint (v0) | min per 15 (v0) |');
    p('|---|---|---|---|---|---|---|---|---|---|');
    void row(String name, int secs, Tally t) {
      final n = t.events;
      final perGame = t.v0 / n;
      final min5 = perGame == 0 ? double.infinity : 5 / perGame * secs / 60;
      p('| $name | $secs | ${t.v0} | ${perGame.toStringAsFixed(1)} | '
          '${(t.v1 / n).toStringAsFixed(1)} | ${(t.v2 / n).toStringAsFixed(2)} | '
          '${(t.total('v3') / n).toStringAsFixed(1)} | ${(t.total('v4') / n).toStringAsFixed(1)} | '
          '${min5.toStringAsFixed(1)} | ${(min5 * 3).toStringAsFixed(1)} |');
    }

    row('classic, unaided', 120, runFarm(human, GameMode.classic, 1000));
    row('classic, solver best guess', 45, runFarm(solver, GameMode.classic, 1000));
    row('lockdown, solver', 50, runFarm(solver, GameMode.lockdown, 1000));
    row('equations, solver', 60, runFarm(solver, GameMode.equations, 1000));
    row('quartet, solver', 120, runFarm(solver, GameMode.quartet, 1000));
    row('learn: choose the best (50% flawless)', 80, runLearn(LearnKind.choose, 1000));
    row('learn: closing (50% flawless)', 80, runLearn(LearnKind.closing, 1000));
    row('learn: read the clue (60% flawless)', 60, runLearn(LearnKind.clue, 1000, flawless: .6));
    row('learn: three words (15% best)', 45, runLearn(LearnKind.sequence, 1000));
    row('learn: practice (40% flawless)', 60, runLearn(LearnKind.free, 1000, flawless: .4));
    p('');
    // 3. the long run: games, days and hours to bank gems, per rule
    const minutes = {
      GameMode.classic: 2.5, GameMode.quartet: 5.0, GameMode.relay: 6.0,
      GameMode.lockdown: 3.0, GameMode.blind: 4.0, GameMode.equations: 3.0,
    };
    final perDay = minutes.values.fold(0.0, (x, y) => x + y);
    p('## 3. long run: 12000 dailies (2000 days), $perDay min a day for the six');
    p('cell: games / days / hours of play to bank that many gems (- never)');
    const marks = [5, 15, 50, 100, 250, 500, 1000];
    for (final s in [70.0, 78.0, 84.0]) {
      final t = runDailies(
        Profile('s$s', skill: s, skillSd: 9, winP: .95, usedDelta: 0,
            usedSd: 1.0, luckSd: 28, risk: 30, bits: 6.0, flawlessHearts: .55),
        12000,
      );
      p('');
      p('### mean skill ${s.toInt()}');
      p('| rule | total at 12000 | ${marks.map((m) => '$m').join(' | ')} | 90% of total |');
      p('|---|---|${marks.map((_) => '---').join('|')}|---|');
      for (final r in Tally.rules) {
        final u = t.units[r]!;
        final tot = u.fold(0, (x, y) => x + y);
        String at(int goal) {
          var c = 0;
          for (var i = 0; i < u.length; i++) {
            c += u[i];
            if (c >= goal) {
              final days = (i + 1) / 6;
              return '${i + 1} / ${days.ceil()}d / ${(days * perDay / 60).toStringAsFixed(1)}h';
            }
          }
          return '-';
        }
        p('| $r | $tot | ${marks.map(at).join(' | ')} | ${at((tot * .9).ceil())} |');
      }
      // gems a day by year
      final yr = [for (final r in Tally.rules) r];
      p('gems per day, by year: ${yr.map((r) {
        final u = t.units[r]!;
        String y(int a, int b) => (u.sublist(a * 6, b * 6).fold(0, (x, y) => x + y) / (b - a)).toStringAsFixed(1);
        return '$r ${y(0, 365)}/${y(365, 730)}/${y(1460, 1825)}';
      }).join(', ')}');
    }
    // 4. once a day per achievement, top level only, full pay
    p('## 4. once a day per achievement, top level per game, repeats full');
    p('v5 once a day across languages, v6 once a day in each language');
    p('| player | v5 lex/day | v6 lex/day |');
    p('|---|---|---|');
    for (final s in [70.0, 78.0, 84.0]) {
      final t = runDailies(
        Profile('s$s', skill: s, skillSd: 9, winP: .95, usedDelta: 0,
            usedSd: 1.0, luckSd: 28, risk: 30, bits: 6.0, flawlessHearts: .55),
        1000,
      );
      p('| daily player, skill ${s.toInt()} | ${(t.total('v5') / days).toStringAsFixed(1)} | '
          '${(t.total('v6') / days).toStringAsFixed(1)} |');
    }
    for (final (n, langs) in [('1 language', 1), ('3 languages', 3), ('5 languages', 5), ('20 languages', 20)]) {
      final t = runFarmDays(120, 30, langs);
      p('| farmer, 120 solver games a day, $n | ${(t.total('v5') / 30).toStringAsFixed(1)} | '
          '${(t.total('v6') / 30).toStringAsFixed(1)} |');
    }
    p('');
    // ignore: avoid_print
    print(out);
  });
}
