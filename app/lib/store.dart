import 'dart:collection';
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';

import 'app_log.dart';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'daily.dart';
import 'difficulty.dart';
import 'history.dart';
import 'medal.dart';
import 'modes.dart';
import 'playstyle.dart';
import 'words.dart';

/// How much the game tells you while you play. Whatever the level, a finished
/// game reveals everything (as in the original).
enum Helper {
  off('off', 'nothing until the game ends', false, false, false),
  skill('skill only', 'skill after each guess', true, false, false),
  skillLuck(
    'skill + luck',
    'skill and luck after each guess',
    true,
    true,
    false,
  ),
  full('full help', 'skill, luck and words left', true, true, true);

  const Helper(
    this.label,
    this.sub,
    this.showSkill,
    this.showLuck,
    this.showWordsLeft,
  );
  final String label;
  final String sub;
  final bool showSkill;
  final bool showLuck;
  final bool showWordsLeft;
}

/// One finished game, as achievements see it.
class GameResult {
  const GameResult({
    required this.lang,
    required this.length,
    required this.tries,
    required this.used,
    required this.won,
    this.pool = 0,
    this.skills = const [],
    this.mode = GameMode.classic,
    this.freeRides = 0,
    this.daily = false,
    this.dailyStreak = 0,
    this.style,
    this.styleChanged = false,
    this.stylesHeld = 0,
    this.luck,
    this.risk,
    this.maxBits = 0,
  });
  final String lang;
  final int length;
  final int tries;
  final int used;
  final bool won;

  /// The answer-pool size the game was played at (0 when not known).
  final int pool;

  /// The skill score of every guess, in order (for a quartet or a relay race,
  /// the combined skill of each guess; see multi_analysis.dart).
  final List<double> skills;

  /// How the game was played. Only a classic game counts towards language
  /// mastery and towards the achievements that assume a single word.
  final GameMode mode;

  /// Relay race: boards that were solved the moment they opened, by the
  /// guesses made before.
  final int freeRides;

  /// Whether it was the daily word, and the daily streak it left (0 when the
  /// daily was missed).
  final bool daily;
  final int dailyStreak;

  /// The playstyle the player is rated as once this game is counted (a
  /// [Playstyle.id], null while they are not rated), whether this game moved
  /// them to another one, and how many different ones they have been rated.
  final String? style;
  final bool styleChanged;
  final int stylesHeld;

  /// The mean luck and risk of the guesses that had a choice (null when none
  /// had), and the most bits one guess gained. A classic game only.
  final double? luck;
  final double? risk;
  final double maxBits;

  /// A double fire: a win in three guesses or fewer, or with every guess at 80
  /// skill or more.
  bool get isDouble =>
      won && (used <= 3 || (skills.isNotEmpty && skills.every((s) => s >= 80)));

  /// How the day went, for the daily log (see [dailyMissed]).
  int get dailyTier => !won
      ? dailyMissed
      : isDouble
      ? dailyDouble
      : dailySolved;

  double get avgSkill =>
      skills.isEmpty ? 0 : skills.reduce((a, b) => a + b) / skills.length;

  /// A win in which every guess scored above [threshold] skill.
  bool wonAllAbove(double threshold) =>
      won && skills.isNotEmpty && skills.every((s) => s > threshold);
}

class Stats {
  int played = 0;
  int wins = 0;
  int streak = 0;
  int bestStreak = 0;
  Set<String> langsWon = {};
  Set<int> lengthsWon = {};

  /// Per language, the settings it has been won at; see [masteryCell].
  Map<String, Set<String>> mastery = {};

  Map<String, dynamic> toJson() => {
    'played': played,
    'wins': wins,
    'streak': streak,
    'bestStreak': bestStreak,
    'langsWon': langsWon.toList(),
    'lengthsWon': lengthsWon.toList(),
    'mastery': {for (final e in mastery.entries) e.key: e.value.toList()},
  };

  static Stats fromJson(Map<String, dynamic> j) => Stats()
    ..played = j['played'] ?? 0
    ..wins = j['wins'] ?? 0
    ..streak = j['streak'] ?? 0
    ..bestStreak = j['bestStreak'] ?? 0
    ..langsWon = {for (final l in j['langsWon'] ?? []) l as String}
    ..lengthsWon = {for (final l in j['lengthsWon'] ?? []) l as int}
    ..mastery = {
      // a cell is `length:tries`; before the word pool went there was a third
      // part, which is dropped
      for (final e in ((j['mastery'] ?? {}) as Map).entries)
        e.key as String: {
          for (final x in e.value as List)
            (x as String).split(':').take(2).join(':'),
        },
    };

  void record(GameResult r) {
    played++;
    if (r.won) {
      wins++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      langsWon.add(r.lang);
      lengthsWon.add(r.length);
      final cell = r.mode == GameMode.classic
          ? masteryCell(r.length, r.tries)
          : null;
      if (cell != null) (mastery[r.lang] ??= {}).add(cell);
    } else {
      streak = 0;
    }
  }
}

/// The settings a win counts towards mastery for: one word length at one tries
/// level of the difficulty matrix. Null for a game played at settings outside
/// the matrix.
String? masteryCell(int length, int tries) =>
    triesLevels.any((l) => l.$2 == tries) ? '$length:$tries' : null;

/// How many settings a language has to be won at for mastery: every length it
/// offers at every tries level.
int masteryTarget(Language l) => l.lengths.length * triesLevels.length;

/// How many of [cells] (`length:tries`) are settings [l] still offers. A win at
/// a setting a language no longer offers stays recorded but does not count
/// towards its mastery.
int masteryWon(Language l, Set<String>? cells) {
  if (cells == null) return 0;
  final seen = <String>{};
  for (final cell in cells) {
    final p = cell.split(':');
    if (p.length < 2) continue;
    final length = int.tryParse(p[0]), tries = int.tryParse(p[1]);
    if (length == null || tries == null) continue;
    if (l.lengths.contains(length) && triesLevels.any((t) => t.$2 == tries)) {
      seen.add('$length:$tries');
    }
  }
  return seen.length;
}

/// How an achievement is earned.
enum Track {
  /// Earned by a single game meeting a condition.
  event,

  /// Counts games meeting a condition, up to the target.
  counter,

  /// Counts wins in a row; a loss starts again.
  streak,

  /// Counts distinct languages won in, up to the target.
  languages,

  /// Counts distinct word lengths won at, up to the target.
  lengths,

  /// Collects badges that stay earned (one per language mastered); no target.
  badges,

  /// A number kept over the games (see [metrics]) reaching the target. Every
  /// achievement a player sees is of this kind.
  metric,
}

/// One step of an achievement: the [medal] it earns and the number its metric
/// has to reach.
class Level {
  const Level(this.medal, this.target, this.name);
  final Medal medal;
  final int target;

  /// What the achievement is called once this level is reached.
  final String name;
}

/// An achievement. Most have levels, from bronze to platinum, that ask for more
/// of the same thing (more skill, more games, longer streaks): one achievement,
/// one row, its medal the highest level reached. The streaks are [separate]:
/// each level is an icon of its own, grouped together.
class Achievement {
  /// The two that collect badges, which are not shown.
  const Achievement(
    this.id,
    this.icon,
    this.family,
    String description, {
    this.track = Track.event,
    this.modes = _classicOnly,
  }) : _description = description,
       levels = const [],
       describe = null,
       metric = '',
       strict = false,
       smaller = false,
       tag = null,
       separate = false,
       icons = const [],
       hit = null,
       level = 0;

  /// An achievement of [levels], earned level by level as its [metric] reaches
  /// each target. [describe] says what a level asks for. [strict]: it has to
  /// pass the target; [smaller]: the smaller number is the better one (the
  /// fastest win). [mode] is the mode it is about, for its tag; [separate] and
  /// [icons] draw each level as an icon of its own.
  Achievement.leveled(
    this.id,
    this.icon,
    this.family,
    String Function(int target) this.describe,
    this.metric,
    this.levels, {
    this.strict = false,
    this.smaller = false,
    GameMode? mode,
    this.separate = false,
    this.icons = const [],
    this.hit,
  }) : track = Track.metric,
       modes = _anyMode,
       _description = '',
       tag = mode,
       level = 0;

  /// What it is called at the level it stands for (the first, by default): the
  /// name changes as the levels are reached.
  String get title => levels.isEmpty ? family : levels[level].name;

  Achievement._at(Achievement a, this.level)
    : id = a.id,
      icon = a.separate && a.icons.length > level ? a.icons[level] : a.icon,
      family = a.family,
      _description = a._description,
      track = a.track,
      modes = a.modes,
      levels = a.levels,
      describe = a.describe,
      metric = a.metric,
      strict = a.strict,
      smaller = a.smaller,
      tag = a.tag,
      separate = a.separate,
      icons = a.icons,
      hit = a.hit;

  final String id;

  /// Name of a Tabler filled icon in assets/icons.
  final String icon;

  /// The name of the whole achievement; a level has a name of its own.
  final String family;
  final String _description;
  final Track track;
  final List<Level> levels;
  final String Function(int target)? describe;

  /// The modes whose games count for it.
  final Set<GameMode> modes;

  /// The number it reads (see [metrics]), and how it is compared with a target.
  final String metric;
  final bool strict;
  final bool smaller;

  /// The mode it is about, shown on it (quartet or relay), if any.
  final GameMode? tag;
  final bool separate;
  final List<String> icons;

  /// Whether a game does what a level of [target] asks, for the achievements
  /// that can be earned again: every such game is counted once the level is
  /// earned (null for the ones that count up, which cannot be done again).
  final bool Function(GameResult r, int target)? hit;

  /// Which level this is, when it stands for one (an earned one, say).
  final int level;

  /// This achievement as its level [i]: its medal, its icon, what it asks.
  Achievement atLevel(int i) => Achievement._at(this, i);

  /// What the level asks for.
  String get description =>
      describe == null ? _description : describe!(levels[level].target);

  Medal get medal => levels.isEmpty ? Medal.bronze : levels[level].medal;
  int get target => levels.isEmpty ? 0 : levels[level].target;

  /// Whether it has targets and a progress bar: it counts up to the next one (a
  /// best-of number, such as the best skill, has none).
  bool get numbered => track == Track.metric && _counted.contains(metric);

  /// Whether it spans languages (the ones that count languages, and the mastery
  /// badges), so belongs to none. Every other is earned, and counted, in one
  /// language at a time.
  bool get global =>
      track == Track.badges ||
      (track == Track.metric && _globalMetrics.contains(metric));

  /// The target of level [i], with "every language" as [languages] when it asks
  /// for more than there are.
  int targetAt(int i, {int languages = 0}) {
    final t = levels[i].target;
    return _globalMetrics.contains(metric) && languages > 0 && t > languages
        ? languages
        : t;
  }

  /// Whether [v] of its metric reaches level [i].
  bool reached(int i, double v, {int languages = 0}) {
    final t = targetAt(i, languages: languages).toDouble();
    if (smaller) return v > 0 && v <= t;
    return strict ? v > t : v >= t;
  }

  /// How many levels it has in all.
  int get count => levels.length;

  /// Whether it starts again once its top level is earned: the ones that count
  /// up do (the wins start from 0, the languages from those won so far), and
  /// every round is counted. The best-of ones count the games that do it
  /// again, the streaks the runs that get there, and a few cannot go further.
  bool get cycles =>
      track == Track.metric &&
      hit == null &&
      !separate &&
      !const {'completed', 'mastered', 'stylesWorn'}.contains(metric);
}

/// The metrics that count up (they get a progress bar), and those that count
/// languages (kept once for the player, not per language).
const _counted = {
  'wins',
  'played',
  'streak',
  'lastTry',
  'every95',
  'lengths',
  'langs',
  'mastered',
  'completed',
  'dailies',
  'streakClassic',
  'streakQuartet',
  'streakRelay',
  'doubles',
  'quartetWins',
  'quartetLast',
  'oneEach',
  'relayWins',
  'relayLast',
  'relayFree',
  'stylesWorn',
};
const _globalMetrics = {'langs', 'mastered', 'completed'};

const _classicOnly = {GameMode.classic};
const _anyMode = {GameMode.classic, GameMode.quartet, GameMode.relay};
const _quartetOnly = {GameMode.quartet};
const _relayOnly = {GameMode.relay};

/// The achievement with [id], or null for one this version does not have.
Achievement? achievementById(String id) {
  for (final a in allAchievements) {
    if (a.id == id) return a;
  }
  return null;
}

/// Every achievement a player sees. One for each thing to get better at, each
/// with levels from bronze to platinum; the streaks show each level as an icon.
final achievements = <Achievement>[
  Achievement.leveled(
    'wins',
    'shield-check',
    'wins',
    (n) => n == 1 ? 'win a game' : 'win $n games',
    'wins',
    _lv([1, 25, 100, 500], ['first light', 'regular', 'veteran', 'dustwalker']),
  ),
  Achievement.leveled(
    'played',
    'hourglass',
    'games played',
    (n) => 'play $n games',
    'played',
    _lv([10, 50, 250, 1000], ['persistent', 'devoted', 'diehard', 'lifer']),
  ),
  Achievement.leveled(
    'quick',
    'bolt',
    'fastest win',
    (n) => n == 1 ? 'win on the first guess' : 'win in $n guesses or fewer',
    'fastest',
    _lv([4, 3, 2, 1], ['quick draw', 'sharpshooter', 'two shot', 'one shot']),
    hit: (r, t) => r.won && r.used <= t,
    smaller: true,
  ),
  Achievement.leveled(
    'last_try',
    'lungs',
    'last try',
    (n) => n == 1
        ? 'win on your very last try (4+ tries)'
        : 'win on your very last try $n times',
    'lastTry',
    _lv(
      [1, 10, 30, 100],
      ['last breath', 'living dangerously', 'edge of the seat', 'nine lives'],
    ),
  ),
  Achievement.leveled(
    'skill_avg',
    'microscope',
    'average skill',
    (n) => 'win with an average skill of $n or more',
    'bestSkillAvg',
    _lv(
      [70, 80, 90, 95],
      ['steady hand', 'sharp mind', 'pure skill', 'flawless'],
    ),
    hit: (r, t) => r.won && r.skills.isNotEmpty && r.avgSkill >= t,
  ),
  Achievement.leveled(
    'skill_every',
    'sparkles',
    'every guess',
    (n) => 'win with every guess above $n skill',
    'bestEvery',
    _lv(
      [60, 75, 90, 95],
      ['no slip', 'clean sheet', 'clean sweep', 'skill issue'],
    ),
    hit: (r, t) => r.won && r.skills.isNotEmpty && r.skills.reduce(min) > t,
    strict: true,
  ),
  Achievement.leveled(
    'luck',
    'clover',
    'average luck',
    (n) => 'win with an average luck of +$n or more',
    'bestLuck',
    _lv(
      [20, 40, 60, 80],
      ['lucky break', 'fortune’s child', 'charmed', 'blessed'],
    ),
    hit: (r, t) => r.won && r.luck != null && r.luck! >= t,
  ),
  Achievement.leveled(
    'risk',
    'dice-5',
    'average risk',
    (n) => 'win with an average risk of $n or more',
    'bestRisk',
    _lv([25, 40, 55, 70], ['dabbler', 'risk taker', 'daredevil', 'all in']),
    hit: (r, t) => r.won && r.risk != null && r.risk! >= t,
  ),
  Achievement.leveled(
    'bits',
    'apps',
    'bits',
    (n) => 'gain $n bits or more with one guess',
    'bestBits',
    _lv([6, 8, 10, 12], ['big bite', 'wide net', 'landslide', 'jackpot']),
    hit: (r, t) => r.maxBits >= t,
  ),
  Achievement.leveled(
    'lengths',
    'compass',
    'word lengths',
    (n) => 'win at $n different word lengths',
    'lengths',
    _lv([2, 3, 4, 5], ['brevity', 'long haul', 'wide range', 'full range']),
  ),
  Achievement.leveled(
    'languages',
    'world',
    'languages',
    (n) => 'win in $n languages',
    'langs',
    _lv([2, 3, 6, 9], ['bilingual', 'polyglot', 'six tongues', 'nine tongues']),
  ),
  Achievement.leveled(
    'language_mastery',
    'feather',
    'language mastery',
    (n) => n == 1
        ? 'master a language: win once at every length and difficulty'
        : n >= 20
        ? 'master every language'
        : 'master $n languages',
    'mastered',
    _lv([1, 3, 6, 20], ['learner', 'scholar', 'master', 'sage']),
  ),
  Achievement.leveled(
    'completionist',
    'badges',
    'completionist',
    (n) => n == 1
        ? 'earn every level of a language'
        : n >= 20
        ? 'be a completionist in every language'
        : 'be a completionist in $n languages',
    'completed',
    _lv(
      [1, 3, 6, 20],
      ['completionist', 'collector', 'archivist', 'tower of babel'],
    ),
  ),
  Achievement.leveled(
    'dailies',
    'flame',
    'dailies',
    (n) => 'solve $n dailies',
    'dailies',
    _lv(
      [5, 25, 100, 365],
      ['daily habit', 'daily ritual', 'daily devotion', 'a year of dailies'],
    ),
  ),
  Achievement.leveled(
    'double_fire',
    'flare',
    'double fires',
    (n) => n == 1
        ? 'solve a daily in 3 guesses, or with every guess at 80 skill or more'
        : 'earn $n double fires',
    'doubles',
    _lv(
      [1, 10, 50, 200],
      ['double fire', 'twice as hot', 'blazing', 'inferno'],
    ),
  ),
  Achievement.leveled(
    'quartet_wins',
    'layout-grid',
    'quartet wins',
    (n) => n == 1 ? 'win a quartet' : 'win $n quartets',
    'quartetWins',
    _lv(
      [1, 10, 50, 200],
      ['all four', 'quartet regular', 'quartet veteran', 'quartet legend'],
    ),
    mode: GameMode.quartet,
  ),
  Achievement.leveled(
    'quartet_last',
    'lungs',
    'last gasp',
    (n) => n == 1
        ? 'win a quartet on your very last try'
        : 'win a quartet on your very last try $n times',
    'quartetLast',
    _lv(
      [1, 5, 20, 50],
      ['last gasp', 'close call', 'nail biter', 'by a thread'],
    ),
    mode: GameMode.quartet,
  ),
  Achievement.leveled(
    'quartet_spare',
    'clock',
    'room to spare',
    (n) => 'win a quartet with $n or more tries left',
    'quartetSpare',
    _lv(
      [3, 4, 5, 6],
      ['room to spare', 'comfortable', 'plenty in hand', 'walk in the park'],
    ),
    hit: (r, t) => r.won && r.tries - r.used >= t,
    mode: GameMode.quartet,
  ),
  Achievement.leveled(
    'quartet_skill',
    'diamond',
    'sharp four',
    (n) => 'win a quartet with an average skill above $n',
    'quartetSkill',
    _lv(
      [70, 80, 85, 90],
      ['steady four', 'sharp four', 'keen four', 'flawless four'],
    ),
    hit: (r, t) => r.won && r.skills.isNotEmpty && r.avgSkill > t,
    strict: true,
    mode: GameMode.quartet,
  ),
  Achievement.leveled(
    'one_each',
    'butterfly',
    'luckiest man alive',
    (n) => n == 1
        ? 'win a quartet or a relay race with one guess for each word'
        : 'win a quartet or a relay race with one guess for each word $n times',
    'oneEach',
    _lv(
      [1, 3, 10, 25],
      [
        'lucky guess',
        'beginner’s luck',
        'fortune’s favourite',
        'luckiest man alive',
      ],
    ),
  ),
  Achievement.leveled(
    'relay_wins',
    'chess-knight',
    'relay wins',
    (n) => n == 1 ? 'win a relay race' : 'win $n relay races',
    'relayWins',
    _lv(
      [1, 10, 50, 200],
      ['finish line', 'relay regular', 'relay veteran', 'relay legend'],
    ),
    mode: GameMode.relay,
  ),
  Achievement.leveled(
    'relay_last',
    'cards',
    'photo finish',
    (n) => n == 1
        ? 'win a relay race on your very last try'
        : 'win a relay race on your very last try $n times',
    'relayLast',
    _lv(
      [1, 5, 20, 50],
      ['photo finish', 'on the line', 'down to the wire', 'dead heat'],
    ),
    mode: GameMode.relay,
  ),
  Achievement.leveled(
    'relay_free',
    'flag',
    'free ride',
    (n) => n == 1
        ? 'win a relay race with a word solved the moment it opened'
        : 'win a relay race with a word solved the moment it opened $n times',
    'relayFree',
    _lv([1, 5, 20, 50], ['free ride', 'easy rider', 'joyride', 'grand tour']),
    mode: GameMode.relay,
  ),
  Achievement.leveled(
    'chameleon',
    'replace',
    'chameleon',
    (n) => n == 1
        ? 'be rated a playstyle'
        : n == 2
        ? 'change your playstyle: be rated a second one'
        : n >= 6
        ? 'be rated all 6 playstyles'
        : 'be rated $n different playstyles',
    'stylesWorn',
    _lv(
      [1, 2, 4, 6],
      ['first impression', 'chameleon', 'many faces', 'many hats'],
    ),
  ),
  // the streaks: each level is an icon of its own
  Achievement.leveled(
    'streak',
    'balloon',
    'win streak',
    (n) => 'win $n games in a row',
    'streak',
    _lv(
      [3, 7, 15, 30],
      [
        'three in a row',
        'seven in a row',
        'fifteen in a row',
        'thirty in a row',
      ],
    ),
    separate: true,
    icons: const ['square-number-3', 'square-number-7', 'balloon', 'diamonds'],
  ),
  Achievement.leveled(
    'daily_streak',
    'flame',
    'daily streak',
    (n) => 'solve the daily $n days in a row',
    'streakClassic',
    _lv([3, 14, 60, 365], ['kindling', 'bonfire', 'forge', 'eternal flame']),
    hit: (r, t) => r.daily && r.mode == GameMode.classic && r.dailyStreak == t,
    separate: true,
    icons: const ['candle', 'flame', 'flare', 'sparkles'],
  ),
  Achievement.leveled(
    'quartet_streak',
    'campfire',
    'quartet streak',
    (n) => 'solve the quartet daily $n days in a row',
    'streakQuartet',
    _lv(
      [3, 10, 30, 100],
      [
        'quartet kindling',
        'quartet campfire',
        'quartet furnace',
        'quartet phoenix',
      ],
    ),
    hit: (r, t) => r.daily && r.mode == GameMode.quartet && r.dailyStreak == t,
    separate: true,
    icons: const ['candle', 'campfire', 'temperature-plus', 'butterfly'],
    mode: GameMode.quartet,
  ),
  Achievement.leveled(
    'relay_streak',
    'campfire',
    'relay streak',
    (n) => 'solve the relay daily $n days in a row',
    'streakRelay',
    _lv(
      [3, 10, 30, 100],
      ['relay kindling', 'relay campfire', 'relay furnace', 'relay phoenix'],
    ),
    hit: (r, t) => r.daily && r.mode == GameMode.relay && r.dailyStreak == t,
    separate: true,
    icons: const ['candle', 'campfire', 'temperature-plus', 'butterfly'],
    mode: GameMode.relay,
  ),
];

/// Bronze, silver, gold and platinum levels at these targets.
List<Level> _lv(List<int> targets, List<String> names) => [
  for (final (i, t) in targets.indexed) Level(Medal.values[i], t, names[i]),
];

/// How many levels there are to earn in all.
int get levelCount => achievements.fold(0, (n, a) => n + a.count);

/// The achievements a player sees (for code where `achievements` is a field).
List<Achievement> get shownAchievements => achievements;

/// What collects the badges of the languages mastered and completed. They are
/// kept for the families that count languages, and are not shown.
const collectors = <Achievement>[
  Achievement(
    'mastery_badges',
    'badges',
    'language mastery',
    'win once at every length and every difficulty of a language',
    track: Track.badges,
    modes: _anyMode,
  ),
  Achievement(
    completionistId,
    'laurel-wreath',
    'completionist',
    'earn every achievement of one language',
    track: Track.badges,
    modes: _anyMode,
  ),
];

/// Every achievement there is, and the collectors.
final allAchievements = <Achievement>[...achievements, ...collectors];

/// The two achievements of completing a language, and all of them.
const completionistId = 'completionist_badges';

/// What one achievement has done so far.
class AchState {
  AchState({
    this.times = 0,
    List<String>? dates,
    this.progress = 0,
    Set<String>? seen,
    this.value = 0,
    List<int>? hits,
    int? cycle,
    this.rounds = 0,
    this.base = 0,
  }) : dates = dates ?? [],
       seen = seen ?? {},
       hits = hits ?? [],
       cycle = cycle ?? times;

  /// How many times it has been earned, and on which days.
  int times;
  final List<String> dates;

  /// Progress towards the next earning (numbered achievements).
  int progress;

  /// The languages or lengths counted so far, for those tracks.
  final Set<String> seen;

  /// The number a metric achievement reads: a count, or a best so far.
  double value;

  /// How many games did what each level asks (the first one earned it), for
  /// the achievements that can be earned again.
  final List<int> hits;

  /// For the ones that count up and start again once they are done: how many
  /// levels of the round now are earned, how many rounds are done, and where
  /// the count of the languages stood when this round began.
  int cycle;
  int rounds;
  double base;

  String? get first => dates.isEmpty ? null : dates.first;
  String? get latest => dates.isEmpty ? null : dates.last;

  Map<String, dynamic> toJson() => {
    'times': times,
    'dates': dates,
    'progress': progress,
    'seen': seen.toList(),
    if (value != 0) 'value': value,
    if (hits.any((h) => h != 0)) 'hits': hits,
    if (cycle != times) 'cycle': cycle,
    if (rounds != 0) 'rounds': rounds,
    if (base != 0) 'base': base,
  };

  static AchState fromJson(Map<String, dynamic> j) => AchState(
    times: j['times'] ?? 0,
    dates: [for (final d in j['dates'] ?? []) d as String],
    progress: j['progress'] ?? 0,
    seen: {for (final x in j['seen'] ?? []) x as String},
    value: (j['value'] ?? 0).toDouble(),
    hits: [for (final h in j['hits'] ?? []) h as int],
    cycle: j['cycle'],
    rounds: j['rounds'] ?? 0,
    base: (j['base'] ?? 0).toDouble(),
  );
}

/// How a metric reads a game: the modes it looks at, and what the game does to
/// the number [AchState.value] (a count, or a best so far). A streak also keeps
/// its run so far in [AchState.progress].
class Metric {
  const Metric(this.modes, this.step);
  final Set<GameMode> modes;
  final double Function(AchState st, GameResult r) step;
}

double _best(double v, double x) => x > v ? x : v;

Metric _count(Set<GameMode> modes, bool Function(GameResult r) when) =>
    Metric(modes, (st, r) => when(r) ? st.value + 1 : st.value);

Metric _most(Set<GameMode> modes, double? Function(GameResult r) of) =>
    Metric(modes, (st, r) {
      final x = of(r);
      return x == null ? st.value : _best(st.value, x);
    });

Metric _dailyStreak(GameMode mode) => Metric({
  mode,
}, (st, r) => r.daily ? _best(st.value, r.dailyStreak.toDouble()) : st.value);

Metric _style(String id) =>
    Metric(_anyMode, (st, r) => r.style == id ? 1 : st.value);

/// Every metric an achievement reads. The ones that count languages are not
/// here: they are given to [advanceAchievements] (see [_globalMetrics]).
final metrics = <String, Metric>{
  'wins': _count(_anyMode, (r) => r.won),
  'played': _count(_anyMode, (r) => true),
  'streak': Metric(_anyMode, (st, r) {
    st.progress = r.won ? st.progress + 1 : 0;
    return _best(st.value, st.progress.toDouble());
  }),
  'fastest': Metric(
    _classicOnly,
    (st, r) => !r.won || r.used <= 0
        ? st.value
        : (st.value == 0 || r.used < st.value ? r.used.toDouble() : st.value),
  ),
  'lastTry': _count(
    _classicOnly,
    (r) => r.won && r.used == r.tries && r.tries >= 4,
  ),
  'bestSkillAvg': _most(
    _classicOnly,
    (r) => r.won && r.skills.isNotEmpty ? r.avgSkill : null,
  ),
  'bestEvery': _most(
    _classicOnly,
    (r) => r.won && r.skills.isNotEmpty ? r.skills.reduce(min) : null,
  ),
  'every95': _count(_classicOnly, (r) => r.wonAllAbove(95)),
  'bestLuck': _most(_classicOnly, (r) => r.won ? r.luck : null),
  'bestRisk': _most(_classicOnly, (r) => r.won ? r.risk : null),
  'bestBits': _most(_classicOnly, (r) => r.maxBits > 0 ? r.maxBits : null),
  'lengths': Metric(_anyMode, (st, r) {
    if (r.won) st.seen.add('${r.length}');
    return st.seen.length.toDouble();
  }),
  'won4': _count(_anyMode, (r) => r.won && r.length == 4),
  'won8': _count(_anyMode, (r) => r.won && r.length == 8),
  'dailies': _count(_anyMode, (r) => r.daily && r.won),
  'streakClassic': _dailyStreak(GameMode.classic),
  'streakQuartet': _dailyStreak(GameMode.quartet),
  'streakRelay': _dailyStreak(GameMode.relay),
  'doubles': _count(_anyMode, (r) => r.daily && r.isDouble),
  'quartetWins': _count(_quartetOnly, (r) => r.won),
  'quartetLast': _count(_quartetOnly, (r) => r.won && r.used == r.tries),
  'quartetSpare': _most(
    _quartetOnly,
    (r) => r.won ? (r.tries - r.used).toDouble() : null,
  ),
  'quartetSkill': _most(
    _quartetOnly,
    (r) => r.won && r.skills.isNotEmpty ? r.avgSkill : null,
  ),
  'oneEach': _count({
    GameMode.quartet,
    GameMode.relay,
  }, (r) => r.won && r.used <= 4),
  'relayWins': _count(_relayOnly, (r) => r.won),
  'relayLast': _count(_relayOnly, (r) => r.won && r.used == r.tries),
  'relayFree': _count(_relayOnly, (r) => r.won && r.freeRides > 0),
  for (final p in playstyles) 'style_${p.id}': _style(p.id),
  'styleChanges': _count(_anyMode, (r) => r.styleChanged),
  'stylesWorn': Metric(
    _anyMode,
    (st, r) => _best(st.value, r.stylesHeld.toDouble()),
  ),
};

/// Applies one finished game to every achievement's state and returns the
/// ones it earned. Pure, so it is tested without any storage.
///
/// [mastered] is the codes of the languages whose mastery is complete now; the
/// badges are collected from it and never taken away. [counts] are the numbers
/// of the metrics that count languages (`langs`, `mastered`, `completed`) and
/// [languages] how many there are.
List<Achievement> advanceAchievements(
  Map<String, AchState> states,
  GameResult r,
  String today, {
  Set<String> mastered = const {},
  Map<String, int> counts = const {},
  int languages = 0,
}) {
  final earned = <Achievement>[];
  void ensureHits(Achievement a, AchState st) {
    while (st.hits.length < a.count) {
      st.hits.add(0);
    }
  }

  // every level the number has now reached, in order: one game can earn several
  void earnLevels(Achievement a, AchState st, {double? count}) {
    if (!a.cycles) {
      while (st.times < a.count &&
          a.reached(st.times, st.value, languages: languages)) {
        earned.add(a.atLevel(st.times));
        st.times++;
        st.cycle = st.times;
        st.dates.add(today);
      }
      return;
    }
    // it counts up and starts again: each level is counted every round, and the
    // medal stays once earned
    ensureHits(a, st);
    while (st.cycle < a.count &&
        a.reached(st.cycle, st.value, languages: languages)) {
      earned.add(a.atLevel(st.cycle));
      st.hits[st.cycle]++;
      if (st.cycle >= st.times) {
        st.times = st.cycle + 1;
        st.dates.add(today);
      }
      st.cycle++;
    }
    if (st.cycle >= a.count) {
      st.rounds++;
      st.cycle = 0;
      st.value = 0;
      st.progress = 0;
      st.seen.clear();
      if (count != null) st.base = count;
    }
  }

  for (final a in allAchievements) {
    final st = states.putIfAbsent(a.id, AchState.new);
    // earned by the app itself, from everything kept: see AppState.recordGame
    if (a.id == completionistId) continue;
    if (a.track == Track.badges) {
      final fresh = mastered.difference(st.seen);
      if (fresh.isNotEmpty) {
        st.seen.addAll(fresh);
        st.progress = st.seen.length;
        for (final _ in fresh) {
          st.times++;
          st.dates.add(today);
        }
        earned.add(a);
      }
      continue;
    }
    if (a.track != Track.metric) continue;
    final m = metrics[a.metric];
    if (m == null) {
      // a metric that counts languages: the languages now, less those when the
      // round began
      final now = (counts[a.metric] ?? 0).toDouble();
      st.value = now - st.base;
      earnLevels(a, st, count: now);
      continue;
    }
    // a game played in a mode the metric is not about leaves it alone: it
    // neither counts nor breaks a streak
    if (!m.modes.contains(r.mode)) continue;
    st.value = m.step(st, r);
    earnLevels(a, st);
    // a game that does what a level asks counts again, once it is earned; a
    // streak counts the runs that get to each level
    final hit = a.hit;
    final run = a.metric == 'streak';
    if (hit != null || run) {
      ensureHits(a, st);
      for (var i = 0; i < st.times && i < a.count; i++) {
        final t = a.levels[i].target;
        if (run ? st.progress == t : hit!(r, t)) st.hits[i]++;
      }
    }
  }
  return earned;
}

/// How far a player has got with one daily word: the guesses so far (so that
/// leaving and coming back resumes it, and cannot reroll it) and, once it is
/// over, whether it was won.
class DailyEntry {
  const DailyEntry(this.guesses, [this.won]);
  final List<String> guesses;

  /// Null while the daily is still being played.
  final bool? won;

  bool get over => won != null;

  Map<String, dynamic> toJson() => {
    'g': guesses,
    if (won != null) 'w': won! ? 1 : 0,
  };

  static DailyEntry fromJson(Map<String, dynamic> j) => DailyEntry([
    for (final g in j['g'] ?? []) g as String,
  ], j['w'] == null ? null : j['w'] == 1);
}

/// Settings, stats and achievements, kept in shared_preferences
/// (localStorage on the web). Every read and write tolerates failure: the
/// game must still play with storage blocked.
class AppState extends ChangeNotifier {
  String lang = 'en';
  int length = 5;
  int tries = 6;
  Helper helper = Helper.full;
  GameMode mode = GameMode.classic;

  /// Light, dark, or whichever the device is set to.
  ThemeMode themeMode = ThemeMode.system;

  /// The black theme: the dark one on true black. [themeMode] is dark while
  /// it is on.
  bool blackTheme = false;

  /// The theme as stored: 0 system, 1 light, 2 dark, 3 black.
  int get themeIndex => blackTheme ? maxThemeIndex : themeMode.index;

  /// The highest stored theme index (black).
  static const maxThemeIndex = 3;

  void _setThemeIndex(int i) {
    blackTheme = i == maxThemeIndex;
    themeMode = blackTheme ? ThemeMode.dark : ThemeMode.values[i];
  }

  /// Quartet and relay race: the chance, in percent, that answers share a letter.
  int share = 10;

  /// Whether the answer is drawn by how common each word is (on) or with every
  /// word of the length equally likely (off). A daily is always off.
  bool useFrequency = true;
  bool seenHowTo = false;

  /// Whether an update also saves its backup in the Downloads folder (it always
  /// saves one in the app's own storage). On until turned off.
  bool downloadsBackup = true;

  void setDownloadsBackup(bool on) {
    downloadsBackup = on;
    try {
      _w('downloadsBackup', _prefs?.setBool('downloadsBackup', on));
    } catch (_) {}
    notifyListeners();
  }

  /// The version of the app that last ran, to notice the first start of a new one.
  String? lastRunVersion;

  void noteRunVersion(String v) {
    lastRunVersion = v;
    try {
      _w('lastRunVersion', _prefs?.setString('lastRunVersion', v));
    } catch (_) {}
  }

  /// Whether presses give a short vibration (on a phone). On until turned off.
  bool haptics = true;

  void setHaptics(bool on) {
    haptics = on;
    try {
      _w('haptics', _prefs?.setBool('haptics', on));
    } catch (_) {}
    notifyListeners();
  }

  /// Whether the app looks for a newer version by itself when it opens (at most
  /// once a day). Off until chosen: each check is a request to GitHub.
  bool autoUpdateCheck = false;

  /// When the last check that got an answer was, and the newest version it found
  /// (null when it found none newer).
  DateTime? lastUpdateCheck;
  String? latestRelease;

  void setAutoUpdateCheck(bool on) {
    autoUpdateCheck = on;
    try {
      _w('autoUpdateCheck', _prefs?.setBool('autoUpdateCheck', on));
    } catch (_) {}
    notifyListeners();
  }

  /// Remembers a check that got an answer, and the version it found.
  void noteUpdateCheck({required String? latest}) {
    lastUpdateCheck = DateTime.now();
    latestRelease = latest;
    try {
      _w(
        'lastUpdateCheck',
        _prefs?.setInt(
          'lastUpdateCheck',
          lastUpdateCheck!.millisecondsSinceEpoch,
        ),
      );
      _w('latestRelease', _prefs?.setString('latestRelease', latest ?? ''));
    } catch (_) {}
    notifyListeners();
  }

  /// Whether settings have been read, so first-run decisions wait for them.
  bool loaded = false;

  /// Whether this browser can remember anything; first-run help is shown only
  /// when it can, or it would reappear on every visit.
  bool get canRemember => _prefs != null;
  Stats stats = Stats();

  // Achievements: the global ones (see [Achievement.global]) in one map, and the
  // rest in a map for each language.
  final Map<String, AchState> _globalAch = {};
  final Map<String, Map<String, AchState>> _langAch = {};

  /// The achievement states in view for [l]: the global ones and that
  /// language's. It is a live view: a state put into it is kept where it
  /// belongs (a global achievement with the global ones, any other with [l]).
  Map<String, AchState> achOf(String l) => _AchView(this, l);

  /// The achievements in view for the language being played.
  Map<String, AchState> get ach => achOf(lang);
  set ach(Map<String, AchState> all) => setAch(lang, all);

  /// Replaces the achievements: the global ones, and those of [l].
  void setAch(String l, Map<String, AchState> all) {
    final ids = {for (final a in allAchievements.where((a) => a.global)) a.id};
    _globalAch
      ..clear()
      ..addAll({
        for (final e in all.entries)
          if (ids.contains(e.key)) e.key: e.value,
      });
    _langAch[l] = {
      for (final e in all.entries)
        if (!ids.contains(e.key)) e.key: e.value,
    };
  }

  /// The languages that have achievements of their own.
  Iterable<String> get achLanguages => _langAch.keys;

  /// The languages the player has played, from the history and what is kept.
  Set<String> get playedLanguages => {
    for (final g in history.games) g.lang,
    ..._langAch.keys,
    ..._styles.keys,
    ..._dailyLogs.keys.where((k) => !k.contains('|')),
    lang,
  };

  /// The languages whose mastery the last recorded game completed.
  List<Language> lastMastered = const [];

  /// Whether every achievement that belongs to one language (the global ones,
  /// which count languages, aside) has been earned in [l].
  bool completedIn(String l) {
    final mine = achOf(l);
    return achievements
        .where((a) => !a.global)
        .every((a) => (mine[a.id]?.times ?? 0) >= a.count);
  }

  /// The languages every one of whose own achievements has been earned.
  Set<String> completedLanguages() => {
    for (final l in playedLanguages)
      if (completedIn(l)) l,
  };

  /// Adds the badge of each language newly completed to the completionist, and
  /// moves the achievements that count completed languages. Returns what was
  /// earned.
  List<Achievement> _grantCompletion(String today) {
    final earned = <Achievement>[];
    final done = completedLanguages();
    final badges = _globalAch.putIfAbsent(completionistId, AchState.new);
    final fresh = done.difference(badges.seen);
    if (fresh.isNotEmpty) {
      badges.seen.addAll(fresh);
      badges.progress = badges.seen.length;
      for (final _ in fresh) {
        badges.times++;
        badges.dates.add(today);
      }
      earned.add(achievementById(completionistId)!);
    }
    final languages = (WordBank.loadedLanguages ?? const <Language>[]).length;
    for (final a in achievements.where((a) => a.metric == 'completed')) {
      final st = _globalAch.putIfAbsent(a.id, AchState.new);
      st.value = badges.seen.length.toDouble();
      while (st.times < a.count &&
          a.reached(st.times, st.value, languages: languages)) {
        earned.add(a.atLevel(st.times));
        st.times++;
        st.dates.add(today);
      }
    }
    return earned;
  }

  /// The languages mastered so far: every length at every difficulty won once.
  List<Language> masteredLanguages() => [
    for (final l in WordBank.loadedLanguages ?? const <Language>[])
      if (masteryWon(l, stats.mastery[l.code]) >= masteryTarget(l)) l,
  ];

  /// How many levels of the achievements have been earned (of [levelCount]).
  int get unlockedCount =>
      achievements.fold(0, (n, a) => n + (ach[a.id]?.times ?? 0));

  /// Progress on the daily words, keyed `<language>|<date>`. Only the last few
  /// days are kept.
  Map<String, DailyEntry> daily = {};

  /// The progress of [lang]'s daily of [mode] on [date]: `language|date` for a
  /// classic game, with `|mode` added for the others.
  static String _dailyEntryKey(String lang, String date, GameMode mode) =>
      mode == GameMode.classic ? '$lang|$date' : '$lang|$date|${mode.name}';

  DailyEntry? dailyFor(
    String lang,
    String date, [
    GameMode mode = GameMode.classic,
  ]) => daily[_dailyEntryKey(lang, date, mode)];

  /// Saves the progress of the daily [lang] has on [date], and forgets days
  /// more than a week older than it.
  void saveDaily(
    String lang,
    String date,
    List<String> guesses, {
    bool? won,
    GameMode mode = GameMode.classic,
  }) {
    daily[_dailyEntryKey(lang, date, mode)] = DailyEntry(List.of(guesses), won);
    final oldest = dailyShift(date, -7);
    daily.removeWhere(
      (k, _) => k.substring(k.indexOf('|') + 1).compareTo(oldest) < 0,
    );
    try {
      _w(
        'daily',
        _prefs?.setString(
          'daily',
          jsonEncode({for (final e in daily.entries) e.key: e.value.toJson()}),
        ),
      );
    } catch (_) {}
    notifyListeners();
  }

  /// How each day's daily went in a language (date -> [dailyMissed],
  /// [dailySolved] or [dailyDouble]): each language has its own streak and its
  /// own calendar, and so has each mode (the quartet and the relay race have a
  /// daily of their own). A year is kept; the best is the longest streak ever.
  final Map<String, Map<String, int>> _dailyLogs = {};
  final Map<String, int> _dailyBests = {};

  /// The key of a language's daily log in [mode]: the language itself for a
  /// classic game, `language|mode` for the others.
  static String dailyKey(String l, GameMode mode) =>
      mode == GameMode.classic ? l : '$l|${mode.name}';

  Map<String, int> dailyLogOf(String l, [GameMode mode = GameMode.classic]) =>
      _dailyLogs[dailyKey(l, mode)] ??= {};
  int dailyBestOf(String l, [GameMode mode = GameMode.classic]) =>
      _dailyBests[dailyKey(l, mode)] ?? 0;

  /// The log and the best streak of the language being played (classic).
  Map<String, int> get dailyLog => dailyLogOf(lang);
  set dailyLog(Map<String, int> v) => _dailyLogs[lang] = v;
  int get dailyBest => dailyBestOf(lang);
  set dailyBest(int v) => _dailyBests[lang] = v;

  /// The daily streak in [l] now, in [mode] (see [dailyStreakOf]).
  int dailyStreakFor(String l, [GameMode mode = GameMode.classic]) =>
      dailyStreakOf(dailyLogOf(l, mode), dailyDate());

  /// The classic daily streak of the language being played.
  int get dailyStreak => dailyStreakFor(lang);

  /// Logs how [date]'s daily went in [l] (the language being played when not
  /// given) in [mode], and returns the streak it leaves there.
  int recordDaily(
    String date,
    int tier, {
    String? lang,
    GameMode mode = GameMode.classic,
  }) {
    final l = lang ?? this.lang;
    final key = dailyKey(l, mode);
    final log = dailyLogOf(l, mode);
    final old = log[date];
    if (old == null || tier > old) log[date] = tier;
    final oldest = dailyShift(date, -400);
    log.removeWhere((k, _) => k.compareTo(oldest) < 0);
    final streak = dailyStreakOf(log, date);
    if (streak > (_dailyBests[key] ?? 0)) _dailyBests[key] = streak;
    _saveDailyLog();
    notifyListeners();
    return streak;
  }

  /// Every game played, as tables (see history.dart): kept so skill, luck and
  /// daring can be worked out again, games reviewed, and a playstyle read from
  /// the last 100.
  History history = History();

  /// The playstyle in each language (a [Playstyle.id]; none until rated),
  /// every one the player has been rated there, and how many times it has
  /// changed. See playstyle.dart.
  final Map<String, String> _styles = {};
  final Map<String, Set<String>> _stylesHeld = {};
  final Map<String, int> _styleChanges = {};

  String? styleIdOf(String l) => _styles[l];
  Playstyle? styleOf(String l) => playstyleById(_styles[l]);
  Set<String> stylesHeldOf(String l) => _stylesHeld[l] ??= {};
  int styleChangesOf(String l) => _styleChanges[l] ?? 0;

  /// The playstyle, and those held, of the language being played.
  String? get styleId => styleIdOf(lang);
  set styleId(String? v) =>
      v == null ? _styles.remove(lang) : _styles[lang] = v;
  Set<String> get stylesHeld => stylesHeldOf(lang);
  set stylesHeld(Set<String> v) => _stylesHeld[lang] = v;
  int get styleChanges => styleChangesOf(lang);
  set styleChanges(int v) => _styleChanges[lang] = v;
  Playstyle? get style => styleOf(lang);

  /// Reads the playstyle in [l] (the language being played when not given)
  /// again from its last 100 games, after a game was saved to the [history]. A
  /// player not yet rated keeps none; one who has been rated keeps their style
  /// while the numbers stay near it (see [classify]). Returns the style and
  /// whether this moved them from one to another.
  ({Playstyle? style, bool changed}) updateStyle({String? lang}) {
    final l = lang ?? this.lang;
    final current = styleOf(l);
    final next = classify(habitsOf(history, lang: l), current: current);
    if (next == null) return (style: current, changed: false);
    final changed = _styles[l] != null && _styles[l] != next.id;
    if (changed) _styleChanges[l] = styleChangesOf(l) + 1;
    _styles[l] = next.id;
    stylesHeldOf(l).add(next.id);
    _saveStyle();
    notifyListeners();
    return (style: next, changed: changed);
  }

  void _saveStyle() {
    try {
      final p = _prefs;
      if (p == null) return;
      _w('styles', p.setString('styles', jsonEncode(_styles)));
      _w(
        'stylesHeldBy',
        p.setString(
          'stylesHeldBy',
          jsonEncode({
            for (final e in _stylesHeld.entries) e.key: e.value.toList(),
          }),
        ),
      );
      _w(
        'styleChangesBy',
        p.setString('styleChangesBy', jsonEncode(_styleChanges)),
      );
      _w('style', p.remove('style'));
      _w('stylesHeld', p.remove('stylesHeld'));
      _w('styleChanges', p.remove('styleChanges'));
    } catch (_) {}
  }

  /// Tells the screens to redraw (the clock they show a date from changed).
  void refresh() => notifyListeners();

  /// Saves a finished game and its guesses to the [history].
  void recordHistory({
    required String lang,
    required GameMode mode,
    required int length,
    required int tries,
    required int pool,
    required List<String> answers,
    required bool won,
    required List<GuessRow> guesses,
    String daily = '',
    bool freq = true,
    DateTime? now,
  }) {
    appLog.i(
      'game',
      'recorded: ${mode.name}, $length letters, $tries tries, '
          '${won ? 'won' : 'lost'}${daily.isEmpty ? '' : ', daily'}',
    );
    history.add(
      at: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      lang: lang,
      mode: mode,
      length: length,
      tries: tries,
      pool: pool,
      answers: answers,
      won: won,
      guesses: guesses,
      daily: daily,
      freq: freq,
    );
    saveHistory();
    notifyListeners();
  }

  /// Where the history is kept: a list of the months that have games, and one
  /// string of rows per month (`history:2026-10`). There can be thousands of
  /// games, so finishing one rewrites a month, not the whole record.
  static const historyIndexKey = 'history:months';
  static String historyChunkKey(String month) => 'history:$month';

  /// Writes out the months of the history that have changed (also after the
  /// numbers of games were worked out again). A month that could not be written
  /// stays changed, and is tried again next time.
  void saveHistory() {
    try {
      final p = _prefs;
      if (p == null) return;
      for (final m in history.dirtyMonths.toList()) {
        final chunk = history.chunk(m);
        if ((chunk['games'] as List).isEmpty) {
          _w(historyChunkKey(m), p.remove(historyChunkKey(m)));
        } else {
          _w(
            historyChunkKey(m),
            p.setString(historyChunkKey(m), jsonEncode(chunk)),
          );
        }
      }
      _w(historyIndexKey, p.setStringList(historyIndexKey, history.months()));
      _w('history', p.remove('history')); // the one string of earlier versions
      history.dirtyMonths.clear();
    } catch (_) {}
  }

  /// Reads the history back: month by month, skipping one that is damaged
  /// without losing the rest; or, from an earlier version, the one string.
  History _readHistory(SharedPreferences p) {
    final months = p.getStringList(historyIndexKey);
    if (months != null) {
      final good = <Object?>[];
      for (final m in months) {
        final key = historyChunkKey(m);
        final s = p.getString(key);
        if (s == null) continue;
        try {
          final chunk = jsonDecode(s);
          try {
            History.fromJson(chunk); // checked whole
          } catch (_) {
            _keepUnread(p, key, s); // a row is bad: read what can be, keep this
          }
          good.add(chunk);
        } catch (_) {
          _keepUnread(p, key, s); // not even readable as JSON
        }
      }
      final (h, dropped) = History.recover(good);
      skippedRows += dropped;
      return h;
    }
    final old = p.getString('history');
    if (old == null) return History();
    Object? whole;
    try {
      whole = jsonDecode(old);
    } catch (_) {
      _keepUnread(p, 'history', old);
      return History();
    }
    try {
      History.fromJson(whole);
    } catch (_) {
      _keepUnread(p, 'history', old);
    }
    final (h, dropped) = History.recover([whole]);
    skippedRows += dropped;
    h.markAllDirty(); // moved to months on the next save
    return h;
  }

  /// Keeps a copy of stored text that could not be read whole, under the same
  /// key with `:unread` added, so that saving what was read does not overwrite
  /// the only copy. Not done twice for one key.
  void _keepUnread(SharedPreferences p, String key, String raw) {
    try {
      final k = '$key:unread';
      if (p.getString(k) == null) p.setString(k, raw);
    } catch (_) {}
  }

  /// Replaces the history (a restored backup), removing the months that are no
  /// longer in it.
  void _replaceHistory(History h) {
    final p = _prefs;
    final before = p?.getStringList(historyIndexKey) ?? const <String>[];
    history = h;
    h.markAllDirty();
    try {
      for (final m in before) {
        if (!h.months().contains(m)) p?.remove(historyChunkKey(m));
      }
    } catch (_) {}
    saveHistory();
  }

  void _saveDailyLog() {
    try {
      _w('dailyLogs', _prefs?.setString('dailyLogs', jsonEncode(_dailyLogs)));
      _w(
        'dailyBests',
        _prefs?.setString('dailyBests', jsonEncode(_dailyBests)),
      );
      _w('dailyLog', _prefs?.remove('dailyLog'));
      _w('dailyBest', _prefs?.remove('dailyBest'));
    } catch (_) {}
  }

  SharedPreferences? _prefs;

  /// How many saves failed since the start (see [_w]).
  int saveFailures = 0;

  /// Logs a save that failed: the store answered no, or threw. Saves are not
  /// waited for, so without this a failure would pass unseen.
  void _w(Object what, Future<bool>? f) {
    if (f == null) {
      // there is no store (it could not be opened), so this was not kept
      saveFailures++;
      // (the first twenty are written: the rest would only fill the log)
      if (saveFailures <= 20) {
        appLog.e('save', '$what was not saved: storage is not available');
      }
      return;
    }
    f.then(
      (ok) {
        if (!ok) {
          saveFailures++;
          appLog.e('save', '$what was not saved (the store answered no)');
        }
      },
      onError: (Object e) {
        saveFailures++;
        appLog.e('save', '$what failed: $e');
      },
    );
  }

  /// How many stored history rows could not be read on the last start.
  int skippedRows = 0;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      try {
        lang = p.getString('lang') ?? lang;
        length = p.getInt('length') ?? length;
        tries = p.getInt('tries') ?? tries;
        useFrequency = p.getBool('useFrequency') ?? true;
        final h = p.getInt('helper');
        if (h != null && h >= 0 && h < Helper.values.length) {
          helper = Helper.values[h];
        } else if (p.getBool('showWordsLeft') == false) {
          helper = Helper.off; // the setting this replaced
        }
        final mi = p.getInt('mode');
        if (mi != null && mi >= 0 && mi < GameMode.values.length) {
          mode = GameMode.values[mi];
        }
        share = (p.getInt('share') ?? share).clamp(0, maxShare);
        final ti = p.getInt('theme');
        if (ti != null && ti >= 0 && ti <= maxThemeIndex) _setThemeIndex(ti);
        seenHowTo = p.getBool('seenHowTo') ?? false;
        haptics = p.getBool('haptics') ?? true;
        downloadsBackup = p.getBool('downloadsBackup') ?? true;
        lastRunVersion = p.getString('lastRunVersion');
        autoUpdateCheck = p.getBool('autoUpdateCheck') ?? false;
        final last = p.getInt('lastUpdateCheck');
        if (last != null) {
          lastUpdateCheck = DateTime.fromMillisecondsSinceEpoch(last);
        }
        final found = p.getString('latestRelease');
        latestRelease = found == null || found.isEmpty ? null : found;
      } catch (e) {
        appLog.w('store', 'could not read a setting: $e');
        // a setting of an unexpected kind must not stop the progress being read
      }
      final s = p.getString('stats');
      if (s != null) {
        try {
          stats = Stats.fromJson(jsonDecode(s));
        } catch (e) {
          appLog.w('store', 'could not read the statistics: $e');
          _keepUnread(p, 'stats', s); // the rest is still read
        }
      }
      try {
        // its own guard: a damaged daily must not stop the rest being read
        final dl = p.getString('daily');
        if (dl != null) {
          daily = {
            for (final e in (jsonDecode(dl) as Map).entries)
              e.key as String: DailyEntry.fromJson(
                (e.value as Map).cast<String, dynamic>(),
              ),
          };
        }
      } catch (e) {
        appLog.w('store', 'could not read the daily entries: $e');
        daily = {};
      }
      try {
        history = _readHistory(p);
        if (history.dirtyMonths.isNotEmpty) saveHistory(); // from the old form
      } catch (e) {
        appLog.w('store', 'could not read the history: $e');
        history = History(); // damaged: start the record again
      }
      try {
        _readStyles(p);
      } catch (e) {
        appLog.w('store', 'could not read the playstyles: $e');
        _styles.clear();
        _stylesHeld.clear();
        _styleChanges.clear();
      }
      try {
        _readDaily(p);
      } catch (e) {
        appLog.w('store', 'could not read the daily log: $e');
        _dailyLogs.clear();
        _dailyBests.clear();
      }
      _readAchievements(p);
      // the achievements were changed to levels: once, work them all out again
      // from the games kept. The flag is kept with the rest; without it (a
      // first start of this version, or it was lost) it is done again.
      if ((p.getInt('achievementsVersion') ?? 0) < achievementsVersion) {
        try {
          rebuildAchievements();
          _w(
            'achievementsVersion',
            p.setInt('achievementsVersion', achievementsVersion),
          );
        } catch (e) {
          appLog.w('store', 'could not rebuild the achievements: $e');
        }
      }
      appLog.i(
        'store',
        'load ends: version ${p.getString('lastRunVersion')}, '
            '${p.getKeys().length} keys, ${history.games.length} games, '
            '${stats.played} played, $skippedRows rows skipped',
      );
    } catch (e) {
      appLog.e('store', 'storage could not be read at all: $e');
    }
    loaded = true;
    notifyListeners();
  }

  // What is kept for each language is read as it was saved; the forms from
  // before each language had its own go to the language that was being played.
  void _readStyles(SharedPreferences p) {
    final by = p.getString('styles');
    if (by != null) {
      for (final e in (jsonDecode(by) as Map).entries) {
        final id = playstyleById(e.value as String?)?.id;
        if (id != null) _styles[e.key as String] = id;
      }
      final held = p.getString('stylesHeldBy');
      if (held != null) {
        for (final e in (jsonDecode(held) as Map).entries) {
          _stylesHeld[e.key as String] = {
            for (final id in e.value as List)
              if (playstyleById(id as String) != null) id,
          };
        }
      }
      final changes = p.getString('styleChangesBy');
      if (changes != null) {
        for (final e in (jsonDecode(changes) as Map).entries) {
          _styleChanges[e.key as String] = (e.value as int).clamp(0, 1000000);
        }
      }
      return;
    }
    final id = playstyleById(p.getString('style'))?.id;
    if (id != null) _styles[lang] = id;
    _stylesHeld[lang] = {
      for (final id in p.getStringList('stylesHeld') ?? const <String>[])
        if (playstyleById(id) != null) id,
    };
    _styleChanges[lang] = (p.getInt('styleChanges') ?? 0).clamp(0, 1000000);
  }

  void _readDaily(SharedPreferences p) {
    Map<String, int> day(Object? raw) => {
      for (final e in (raw as Map).entries)
        e.key as String: (e.value as int).clamp(dailyMissed, dailyDouble),
    };
    final logs = p.getString('dailyLogs');
    if (logs != null) {
      for (final e in (jsonDecode(logs) as Map).entries) {
        _dailyLogs[e.key as String] = day(e.value);
      }
      final bests = p.getString('dailyBests');
      if (bests != null) {
        for (final e in (jsonDecode(bests) as Map).entries) {
          _dailyBests[e.key as String] = e.value as int;
        }
      }
      return;
    }
    final log = p.getString('dailyLog');
    if (log != null) _dailyLogs[lang] = day(jsonDecode(log));
    final best = p.getInt('dailyBest');
    if (best != null) _dailyBests[lang] = best;
  }

  void _readAchievements(SharedPreferences p) {
    try {
      Map<String, AchState> states(Object? raw) => {
        for (final e in (raw as Map).entries)
          e.key as String: AchState.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      };
      final ids = {
        for (final a in allAchievements.where((a) => a.global)) a.id,
      };
      final a = p.getString('ach');
      if (a != null) {
        final all = states(jsonDecode(a));
        for (final e in all.entries) {
          if (ids.contains(e.key)) {
            _globalAch[e.key] = e.value;
          } else {
            // from before each language had its own
            (_langAch[lang] ??= {})[e.key] = e.value;
          }
        }
        final by = p.getString('achLang');
        if (by != null) {
          for (final e in (jsonDecode(by) as Map).entries) {
            _langAch[e.key as String] = states(e.value);
          }
        }
      } else {
        // the earliest format: achievement id -> the day it was earned, once
        final u = p.getString('unlocked');
        if (u != null) {
          for (final e in (jsonDecode(u) as Map).entries) {
            final st = AchState(times: 1, dates: [e.value as String]);
            if (ids.contains(e.key)) {
              _globalAch[e.key as String] = st;
            } else {
              (_langAch[lang] ??= {})[e.key as String] = st;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// The version of the achievements kept: when it is older than this, they are
  /// worked out again from the games kept (see [rebuildAchievements]).
  static const achievementsVersion = 2;

  /// Works every achievement out again from the games kept, oldest first, as
  /// if each had just been played: what was earned, on which day, and how far
  /// each number has got. What cannot be known from a game (a relay's free
  /// rides, the style it was played in) is taken from what is kept now.
  void rebuildAchievements() {
    _globalAch.clear();
    _langAch.clear();
    final games = [...history.games]..sort((a, b) => a.at.compareTo(b.at));
    final temp = Stats();
    final logs = <String, Map<String, int>>{};
    final langs = WordBank.loadedLanguages ?? const <Language>[];
    final lastOf = {for (final g in games) g.lang: g.id};
    for (final g in games) {
      final rows = history.guessesOf(g.id);
      var luck = 0.0, risk = 0.0, n = 0, rn = 0, bits = 0.0;
      for (final r in rows) {
        if (r.gain > bits) bits = r.gain;
        if (r.before <= 1) continue;
        luck += r.luck;
        n++;
        final k = r.risk;
        if (k != null) {
          risk += k;
          rn++;
        }
      }
      final last = lastOf[g.lang] == g.id;
      GameResult result({int streak = 0}) => GameResult(
        lang: g.lang,
        length: g.length,
        tries: g.tries,
        used: rows.length,
        won: g.won,
        pool: g.pool,
        mode: g.mode,
        skills: [for (final r in rows) r.skill],
        luck: n == 0 ? null : luck / n,
        risk: rn == 0 ? null : risk / rn,
        maxBits: bits,
        daily: g.daily.isNotEmpty,
        dailyStreak: streak,
        style: last ? styleIdOf(g.lang) : null,
        stylesHeld: last ? stylesHeldOf(g.lang).length : 0,
      );
      var played = result();
      if (g.daily.isNotEmpty) {
        final log = logs.putIfAbsent(dailyKey(g.lang, g.mode), () => {});
        final old = log[g.daily];
        if (old == null || played.dailyTier > old) {
          log[g.daily] = played.dailyTier;
        }
        played = result(streak: dailyStreakOf(log, g.daily));
      }
      temp.record(played);
      final mastered = {
        for (final l in langs)
          if (masteryWon(l, temp.mastery[l.code]) >= masteryTarget(l)) l.code,
      };
      final day = DateTime.fromMillisecondsSinceEpoch(
        g.at,
        isUtc: true,
      ).toLocal().toIso8601String().substring(0, 10);
      advanceAchievements(
        achOf(g.lang),
        played,
        day,
        mastered: mastered,
        counts: {
          'langs': temp.langsWon.length,
          'mastered': mastered.length,
          'completed': 0,
        },
        languages: langs.length,
      );
    }
    _grantCompletion(DateTime.now().toIso8601String().substring(0, 10));
    _saveAchievements();
  }

  /// The achievements as they are saved: the global ones, then each language's.
  void _saveAchievements() {
    try {
      _w(
        'ach',
        _prefs?.setString(
          'ach',
          jsonEncode({
            for (final e in _globalAch.entries) e.key: e.value.toJson(),
          }),
        ),
      );
      _w(
        'achLang',
        _prefs?.setString(
          'achLang',
          jsonEncode({
            for (final l in _langAch.entries)
              l.key: {for (final e in l.value.entries) e.key: e.value.toJson()},
          }),
        ),
      );
    } catch (_) {}
  }

  /// The settings as they are saved (and as a backup keeps them).
  Map<String, Object> settingsJson() => {
    'lang': lang,
    'length': length,
    'tries': tries,
    'useFrequency': useFrequency,
    'helper': helper.index,
    'mode': mode.index,
    'share': share,
    'theme': themeIndex,
    'seenHowTo': seenHowTo,
  };

  /// Replaces what is kept with a checked backup (see backup.dart): the
  /// settings it has (the others stay as they are), and all of the statistics
  /// and achievements. Saved at once, like everything else.
  void restore({
    required Map<String, Object> settings,
    required Stats stats,
    required Map<String, AchState> ach,
    Map<String, LanguageKept>? languages,
    History? history,
  }) {
    appLog.i(
      'restore',
      'a backup is restored: ${stats.played} played'
          '${history == null ? '' : ', ${history.games.length} games'}',
    );
    // the global achievements, then what each language has: its playstyle, its
    // daily calendar and streak, and its achievements. A backup from before the
    // daily or the playstyles has none of them, and what is here stays.
    _globalAch.clear();
    final code = settings['lang'] as String? ?? lang;
    for (final e in ach.entries) {
      if (achievementById(e.key)?.global ?? false) {
        _globalAch[e.key] = e.value;
      } else if (languages == null) {
        // one that is not global, without languages to put it in: the one in use
        (_langAch[code] ??= {})[e.key] = e.value;
      }
    }
    if (languages != null) {
      _langAch.clear();
      for (final e in languages.entries) {
        final k = e.value;
        if (k.style != null) _styles[e.key] = k.style!;
        if (k.held != null) _stylesHeld[e.key] = Set.of(k.held!);
        if (k.changes != null) _styleChanges[e.key] = k.changes!;
        if (k.dailyLog != null) _dailyLogs[e.key] = Map.of(k.dailyLog!);
        if (k.dailyBest != null) _dailyBests[e.key] = k.dailyBest!;
        for (final m in k.dailyModes.entries) {
          _dailyLogs['${e.key}|${m.key}'] = Map.of(m.value.$1);
          _dailyBests['${e.key}|${m.key}'] = m.value.$2;
        }
        _langAch[e.key] = Map.of(k.achievements);
      }
    }
    _saveStyle();
    _saveDailyLog();
    // likewise a backup from before the history
    if (history != null) _replaceHistory(history);
    lang = settings['lang'] as String? ?? lang;
    length = settings['length'] as int? ?? length;
    tries = settings['tries'] as int? ?? tries;
    useFrequency = settings['useFrequency'] as bool? ?? useFrequency;
    final h = settings['helper'] as int?;
    if (h != null) helper = Helper.values[h];
    final m = settings['mode'] as int?;
    if (m != null) mode = GameMode.values[m];
    share = settings['share'] as int? ?? share;
    final t = settings['theme'] as int?;
    if (t != null && t >= 0 && t <= maxThemeIndex) _setThemeIndex(t);
    seenHowTo = settings['seenHowTo'] as bool? ?? seenHowTo;
    this.stats = stats;
    try {
      final p = _prefs;
      if (p != null) {
        _w('lang', p.setString('lang', lang));
        _w('length', p.setInt('length', length));
        _w('tries', p.setInt('tries', tries));
        _w('useFrequency', p.setBool('useFrequency', useFrequency));
        _w('helper', p.setInt('helper', helper.index));
        _w('mode', p.setInt('mode', mode.index));
        _w('share', p.setInt('share', share));
        _w('theme', p.setInt('theme', themeIndex));
        _w('seenHowTo', p.setBool('seenHowTo', seenHowTo));
        _w('stats', p.setString('stats', jsonEncode(stats.toJson())));
        _w(
          'unlocked',
          p.remove('unlocked'),
        ); // the earlier format, now replaced
      }
    } catch (_) {}
    _saveAchievements();
    notifyListeners();
  }

  void markHowToSeen() {
    seenHowTo = true;
    try {
      _w('seenHowTo', _prefs?.setBool('seenHowTo', true));
    } catch (_) {}
  }

  void setup({
    String? lang,
    int? length,
    int? tries,
    bool? useFrequency,
    Helper? helper,
    GameMode? mode,
    int? share,
    ThemeMode? themeMode,
    bool? black,
  }) {
    this.lang = lang ?? this.lang;
    this.length = length ?? this.length;
    this.tries = tries ?? this.tries;
    this.useFrequency = useFrequency ?? this.useFrequency;
    this.helper = helper ?? this.helper;
    this.mode = mode ?? this.mode;
    this.themeMode = themeMode ?? this.themeMode;
    // choosing a mode on its own leaves black; black is only ever with dark
    blackTheme =
        (black ?? (themeMode == null && blackTheme)) &&
        this.themeMode == ThemeMode.dark;
    this.share = (share ?? this.share).clamp(0, maxShare);
    try {
      _w('lang', _prefs?.setString('lang', this.lang));
      _w('length', _prefs?.setInt('length', this.length));
      _w('tries', _prefs?.setInt('tries', this.tries));
      _w('useFrequency', _prefs?.setBool('useFrequency', this.useFrequency));
      _w('helper', _prefs?.setInt('helper', this.helper.index));
      _w('mode', _prefs?.setInt('mode', this.mode.index));
      _w('share', _prefs?.setInt('share', this.share));
      _w('theme', _prefs?.setInt('theme', themeIndex));
    } catch (_) {}
    notifyListeners();
  }

  /// Records a finished game; returns the achievements it earned.
  List<Achievement> recordGame(GameResult r) {
    stats.record(r);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final had = Set.of(_globalAch['mastery_badges']?.seen ?? const <String>{});
    // the achievements of this game's language, with the global ones: the
    // states are shared, so what the game changes lands in both maps
    final view = achOf(r.lang);
    final earned = advanceAchievements(
      view,
      r,
      today,
      mastered: masteredLanguages().map((l) => l.code).toSet(),
      counts: {
        'langs': stats.langsWon.length,
        'mastered': masteredLanguages().length,
        'completed': completedLanguages().length,
      },
      languages: (WordBank.loadedLanguages ?? const <Language>[]).length,
    );
    final ids = {for (final a in allAchievements.where((a) => a.global)) a.id};
    for (final e in view.entries) {
      if (ids.contains(e.key)) {
        _globalAch[e.key] = e.value;
      } else {
        (_langAch[r.lang] ??= {})[e.key] = e.value;
      }
    }
    earned.addAll(_grantCompletion(today));
    final fresh = (_globalAch['mastery_badges']?.seen ?? const <String>{})
        .difference(had);
    lastMastered = [
      for (final l in WordBank.loadedLanguages ?? const <Language>[])
        if (fresh.contains(l.code)) l,
    ];
    try {
      _w('stats', _prefs?.setString('stats', jsonEncode(stats.toJson())));
    } catch (_) {}
    _saveAchievements();
    notifyListeners();
    return earned;
  }
}

/// The achievements of one language with the global ones, as one map that
/// writes through to where each belongs.
class _AchView extends MapBase<String, AchState> {
  _AchView(this._s, this._lang);
  final AppState _s;
  final String _lang;

  bool _global(String id) => achievementById(id)?.global ?? false;

  @override
  AchState? operator [](Object? key) {
    if (key is! String) return null;
    return _global(key) ? _s._globalAch[key] : _s._langAch[_lang]?[key];
  }

  @override
  void operator []=(String key, AchState value) {
    if (_global(key)) {
      _s._globalAch[key] = value;
    } else {
      (_s._langAch[_lang] ??= {})[key] = value;
    }
  }

  @override
  void clear() {
    _s._globalAch.clear();
    _s._langAch[_lang]?.clear();
  }

  @override
  Iterable<String> get keys => [
    ..._s._globalAch.keys,
    ...?_s._langAch[_lang]?.keys,
  ];

  @override
  AchState? remove(Object? key) {
    if (key is! String) return null;
    return _global(key)
        ? _s._globalAch.remove(key)
        : _s._langAch[_lang]?.remove(key);
  }
}

/// What is kept for one language besides its games: the playstyle, the daily
/// calendar and streak, and the achievements that are its own. A field the
/// backup did not have is null and leaves what is held alone.
class LanguageKept {
  const LanguageKept({
    this.style,
    this.held,
    this.changes,
    this.dailyLog,
    this.dailyBest,
    this.dailyModes = const {},
    this.achievements = const {},
  });
  final String? style;
  final Set<String>? held;
  final int? changes;
  final Map<String, int>? dailyLog;
  final int? dailyBest;

  /// The log and best streak of the daily quartet and relay race, by mode name.
  final Map<String, (Map<String, int>, int)> dailyModes;
  final Map<String, AchState> achievements;
}
