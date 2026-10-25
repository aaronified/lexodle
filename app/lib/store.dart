import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_log.dart';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'daily.dart';
import 'difficulty.dart';
import 'history.dart';
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

  /// The daily streak reaching the target. It is earned once, and its bar
  /// follows the streak instead of starting again.
  dailyStreak,

  /// Earned once, when the app finds a condition over everything kept to be true
  /// (see [AppState.recordGame]), not by a game.
  granted,
}

class Achievement {
  const Achievement(
    this.id,
    this.icon,
    this.title,
    this.description, {
    this.track = Track.event,
    this.target = 0,
    this.repeat = true,
    this.qualifies = _always,
    this.modes = _classicOnly,
  });
  final String id;

  /// Name of a Tabler filled icon in assets/icons.
  final String icon;
  final String title;
  final String description;
  final Track track;

  /// Progress needed to earn a numbered achievement (0 for events).
  final int target;

  /// Whether it can be earned again. Numbered ones restart from 0 each time.
  final bool repeat;

  /// For events: the game meets the condition. For counters: the game counts.
  final bool Function(GameResult r) qualifies;

  /// The modes whose games count for it. Most that assume a single word (one
  /// shot, last breath, skill) are classic only; the general ones (a win, a
  /// streak, a language) take any.
  final Set<GameMode> modes;

  /// Whether it has a target and so a progress bar (a badge collection has not).
  bool get numbered =>
      track != Track.event && track != Track.badges && track != Track.granted;

  /// Whether it spans languages (the ones that count languages, and the mastery
  /// badges), so belongs to none. Every other is earned, and counted, in one
  /// language at a time.
  bool get global =>
      track == Track.languages ||
      track == Track.badges ||
      track == Track.granted;
}

bool _always(GameResult r) => true;

const _classicOnly = {GameMode.classic};
const _anyMode = {GameMode.classic, GameMode.quartet, GameMode.relay};
const _quartetOnly = {GameMode.quartet};
const _relayOnly = {GameMode.relay};

/// Every achievement. Numbered ones show a progress bar and, once earned, start
/// again from 0; events can be earned again too, and every earning is counted.
/// The achievement with [id], or null for one this version does not have.
Achievement? achievementById(String id) {
  for (final a in achievements) {
    if (a.id == id) return a;
  }
  return null;
}

final achievements = <Achievement>[
  Achievement(
    'first_light',
    'sun-high',
    'first light',
    'win a game',
    repeat: false,
    qualifies: (r) => r.won,
    modes: _anyMode,
  ),
  Achievement(
    'one_shot',
    'bolt',
    'one shot',
    'win on the first guess',
    qualifies: (r) => r.won && r.used == 1,
  ),
  Achievement(
    'last_breath',
    'lungs',
    'last breath',
    'win on your very last try (4+ tries)',
    qualifies: (r) => r.won && r.used == r.tries && r.tries >= 4,
  ),
  Achievement(
    'no_mercy',
    'bomb',
    'no mercy',
    'win with 3 tries or fewer',
    qualifies: (r) => r.won && r.tries <= 3,
  ),
  Achievement(
    'brevity',
    'square-number-4',
    'brevity',
    'win a 4-letter word',
    qualifies: (r) => r.won && r.length == 4,
    modes: _anyMode,
  ),
  Achievement(
    'long_haul',
    'square-number-8',
    'long haul',
    'win an 8-letter word',
    qualifies: (r) => r.won && r.length == 8,
    modes: _anyMode,
  ),
  Achievement(
    'pure_skill',
    'diamond',
    'pure skill',
    'win with every guess above 90 skill',
    qualifies: (r) => r.wonAllAbove(90),
  ),
  Achievement(
    'skill_issue',
    'mood-crazy-happy',
    'skill issue',
    'win 10 games with every guess above 95 skill',
    track: Track.counter,
    target: 10,
    qualifies: (r) => r.wonAllAbove(95),
  ),
  Achievement(
    'full_range',
    'compass',
    'full range',
    'win at every length, 4 to 8',
    track: Track.lengths,
    target: 5,
    modes: _anyMode,
  ),
  Achievement(
    'streak_3',
    'square-number-3',
    'three in a row',
    'win 3 games in a row',
    track: Track.streak,
    target: 3,
    modes: _anyMode,
  ),
  Achievement(
    'streak_7',
    'square-number-7',
    'seven in a row',
    'win 7 games in a row',
    track: Track.streak,
    target: 7,
    modes: _anyMode,
  ),
  Achievement(
    'bilingual',
    'bubble-text',
    'bilingual',
    'win in 2 languages',
    track: Track.languages,
    target: 2,
    modes: _anyMode,
  ),
  Achievement(
    'polyglot_3',
    'world',
    'polyglot',
    'win in 3 languages',
    track: Track.languages,
    target: 3,
    modes: _anyMode,
  ),
  Achievement(
    'polyglot_9',
    'trophy',
    'nine tongues',
    'win in 9 languages',
    track: Track.languages,
    target: 9,
    modes: _anyMode,
  ),
  Achievement(
    'wins_10',
    'award',
    'regular',
    'win 10 games',
    track: Track.counter,
    target: 10,
    qualifies: (r) => r.won,
    modes: _anyMode,
  ),
  Achievement(
    'wins_50',
    'shield-check',
    'veteran',
    'win 50 games',
    track: Track.counter,
    target: 50,
    qualifies: (r) => r.won,
    modes: _anyMode,
  ),
  Achievement(
    'wins_100',
    'crown',
    'dustwalker',
    'win 100 games',
    track: Track.counter,
    target: 100,
    qualifies: (r) => r.won,
    modes: _anyMode,
  ),
  Achievement(
    'played_25',
    'hourglass',
    'persistent',
    'play 25 games',
    track: Track.counter,
    target: 25,
    modes: _anyMode,
  ),
  // quartet
  Achievement(
    'quartet_win',
    'layout-grid',
    'all four',
    'win a quartet',
    modes: _quartetOnly,
    qualifies: (r) => r.won,
  ),
  Achievement(
    'quartet_spare',
    'balloon',
    'room to spare',
    'win a quartet with 3 or more tries left',
    modes: _quartetOnly,
    qualifies: (r) => r.won && r.tries - r.used >= 3,
  ),
  Achievement(
    'quartet_last',
    'clock',
    'last gasp',
    'win a quartet on your very last try',
    modes: _quartetOnly,
    qualifies: (r) => r.won && r.used == r.tries,
  ),
  Achievement(
    'quartet_sharp',
    'diamonds',
    'sharp four',
    'win a quartet with an average skill above 80',
    modes: _quartetOnly,
    qualifies: (r) => r.won && r.avgSkill > 80,
  ),
  Achievement(
    'quartet_10',
    'apps',
    'quartet regular',
    'win 10 quartets',
    track: Track.counter,
    target: 10,
    modes: _quartetOnly,
    qualifies: (r) => r.won,
  ),
  // relay race
  Achievement(
    'relay_win',
    'flag',
    'finish line',
    'win a relay race',
    modes: _relayOnly,
    qualifies: (r) => r.won,
  ),
  Achievement(
    'relay_free',
    'gift',
    'free ride',
    'win a relay race with a word solved the moment it opened',
    modes: _relayOnly,
    qualifies: (r) => r.won && r.freeRides > 0,
  ),
  Achievement(
    'relay_last',
    'speedboat',
    'photo finish',
    'win a relay race on your very last try',
    modes: _relayOnly,
    qualifies: (r) => r.won && r.used == r.tries,
  ),
  Achievement(
    'relay_10',
    'bike',
    'relay regular',
    'win 10 relay races',
    track: Track.counter,
    target: 10,
    modes: _relayOnly,
    qualifies: (r) => r.won,
  ),
  // the luckiest of all: one guess for every word, in either multi-board mode.
  // Four guesses is the least a quartet can take; a relay race can take fewer,
  // when a guess made earlier solves a board the moment it opens.
  Achievement(
    'luckiest',
    'clover',
    'luckiest man alive',
    'win a quartet or a relay race with one guess for each word',
    modes: {GameMode.quartet, GameMode.relay},
    qualifies: (r) => r.won && r.used <= r.mode.boards,
  ),
  // the daily word: a streak ladder, and the double fire
  for (final (id, icon, title, days) in const [
    ('daily_3', 'candle', 'kindling', 3),
    ('daily_7', 'campfire', 'campfire', 7),
    ('daily_14', 'flame', 'bonfire', 14),
    ('daily_30', 'temperature-plus', 'furnace', 30),
    ('daily_60', 'flare', 'forge', 60),
    ('daily_100', 'boom', 'inferno', 100),
    ('daily_200', 'butterfly', 'phoenix', 200),
    ('daily_365', 'sparkles', 'eternal flame', 365),
  ])
    Achievement(
      id,
      icon,
      title,
      'solve the daily word $days days in a row',
      track: Track.dailyStreak,
      target: days,
      repeat: false,
    ),
  Achievement(
    'double_fire',
    'confetti',
    'double fire',
    'solve the daily in 3 guesses, or with every guess at 80 skill or more',
    qualifies: (r) => r.daily && r.isDouble,
  ),
  Achievement(
    'double_10',
    'bulb',
    'twice as hot',
    'earn 10 double fires',
    track: Track.counter,
    target: 10,
    qualifies: (r) => r.daily && r.isDouble,
  ),
  // playstyles: one for being rated each, one for changing, one for all
  for (final p in playstyles)
    Achievement(
      'style_${p.id}',
      p.icon,
      p.name,
      'have the ${p.name} playstyle: ${p.blurb}',
      repeat: false,
      qualifies: (r) => r.style == p.id,
    ),
  Achievement(
    'chameleon',
    'replace',
    'chameleon',
    'change your playstyle',
    repeat: false,
    qualifies: (r) => r.styleChanged,
  ),
  Achievement(
    'many_hats',
    'chef-hat',
    'many hats',
    'have been every one of the ${playstyles.length} playstyles',
    repeat: false,
    qualifies: (r) => r.stylesHeld >= playstyles.length,
  ),
  // one achievement for every language: a badge each, kept for good
  Achievement(
    'mastery',
    'badges',
    'language mastery',
    'win once at every length and every difficulty of a language, '
        'and keep its badge',
    track: Track.badges,
    modes: _anyMode,
  ),
  // every other achievement of a language: a badge each, kept for good
  Achievement(
    completionistId,
    'laurel-wreath',
    'completionist',
    'earn every achievement of one language (not the ones that count languages), '
        'and keep its badge',
    track: Track.badges,
    modes: _anyMode,
  ),
  // completionist, in every language
  Achievement(
    towerOfBabelId,
    'building-broadcast-tower',
    'tower of babel',
    'be a completionist in every language',
    track: Track.granted,
    repeat: false,
    modes: _anyMode,
  ),
];

/// The two achievements of completing a language, and all of them.
const completionistId = 'completionist';
const towerOfBabelId = 'tower_of_babel';

/// What one achievement has done so far.
class AchState {
  AchState({
    this.times = 0,
    List<String>? dates,
    this.progress = 0,
    Set<String>? seen,
  }) : dates = dates ?? [],
       seen = seen ?? {};

  /// How many times it has been earned, and on which days.
  int times;
  final List<String> dates;

  /// Progress towards the next earning (numbered achievements).
  int progress;

  /// The languages or lengths counted so far, for those tracks.
  final Set<String> seen;

  String? get first => dates.isEmpty ? null : dates.first;
  String? get latest => dates.isEmpty ? null : dates.last;

  Map<String, dynamic> toJson() => {
    'times': times,
    'dates': dates,
    'progress': progress,
    'seen': seen.toList(),
  };

  static AchState fromJson(Map<String, dynamic> j) => AchState(
    times: j['times'] ?? 0,
    dates: [for (final d in j['dates'] ?? []) d as String],
    progress: j['progress'] ?? 0,
    seen: {for (final x in j['seen'] ?? []) x as String},
  );
}

/// Applies one finished game to every achievement's state and returns the
/// ones it earned. Pure, so it is tested without any storage.
///
/// [mastered] is the codes of the languages whose mastery is complete now; the
/// badges are collected from it and never taken away.
List<Achievement> advanceAchievements(
  Map<String, AchState> states,
  GameResult r,
  String today, {
  Set<String> mastered = const {},
}) {
  final earned = <Achievement>[];
  for (final a in achievements) {
    final st = states.putIfAbsent(a.id, AchState.new);
    // earned by the app itself, from everything kept: see AppState.recordGame
    if (a.track == Track.granted || a.id == completionistId) continue;
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
    // a game played in a mode the achievement is not about leaves it alone:
    // it neither counts nor breaks a streak
    if (!a.modes.contains(r.mode)) continue;
    var got = false;
    switch (a.track) {
      case Track.event:
        got = a.qualifies(r) && (a.repeat || st.times == 0);
      case Track.counter:
        if (a.qualifies(r)) st.progress++;
        got = st.progress >= a.target;
      case Track.streak:
        st.progress = r.won ? st.progress + 1 : 0;
        got = st.progress >= a.target;
      case Track.languages:
      case Track.lengths:
        if (r.won) {
          st.seen.add(a.track == Track.languages ? r.lang : '${r.length}');
        }
        st.progress = st.seen.length;
        got = st.progress >= a.target;
      case Track.dailyStreak:
        // only a daily moves it: a win carries the streak on, a miss ends it
        if (!r.daily) continue;
        st.progress = r.dailyStreak;
        got = r.won && st.progress >= a.target && st.times == 0;
      case Track.badges:
      case Track.granted:
        break; // collected above, or by the app
    }
    if (got) {
      st.times++;
      st.dates.add(today);
      if (a.numbered && a.track != Track.dailyStreak) {
        // numbered achievements start again from 0 once earned
        st.progress = 0;
        st.seen.clear();
      }
      earned.add(a);
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
      _prefs
        ?..setInt('lastUpdateCheck', lastUpdateCheck!.millisecondsSinceEpoch)
        ..setString('latestRelease', latest ?? '');
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
    final ids = {for (final a in achievements.where((a) => a.global)) a.id};
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
    ..._dailyLogs.keys,
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
        .every((a) => (mine[a.id]?.times ?? 0) > 0);
  }

  /// The languages every one of whose own achievements has been earned.
  Set<String> completedLanguages() => {
    for (final l in playedLanguages)
      if (completedIn(l)) l,
  };

  /// Adds the badge of each language newly completed to the completionist, and
  /// earns the tower of babel once every language there is has one. Returns what
  /// was earned.
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
    final all = WordBank.loadedLanguages ?? const <Language>[];
    final tower = _globalAch.putIfAbsent(towerOfBabelId, AchState.new);
    if (tower.times == 0 &&
        all.isNotEmpty &&
        all.every((l) => badges.seen.contains(l.code))) {
      tower.times++;
      tower.dates.add(today);
      earned.add(achievementById(towerOfBabelId)!);
    }
    return earned;
  }

  /// The languages mastered so far: every length at every difficulty won once.
  List<Language> masteredLanguages() => [
    for (final l in WordBank.loadedLanguages ?? const <Language>[])
      if (masteryWon(l, stats.mastery[l.code]) >= masteryTarget(l)) l,
  ];

  /// How many different achievements have been earned at least once.
  int get unlockedCount => ach.values.where((s) => s.times > 0).length;

  /// Progress on the daily words, keyed `<language>|<date>`. Only the last few
  /// days are kept.
  Map<String, DailyEntry> daily = {};

  DailyEntry? dailyFor(String lang, String date) => daily['$lang|$date'];

  /// Saves the progress of the daily [lang] has on [date], and forgets days
  /// more than a week older than it.
  void saveDaily(String lang, String date, List<String> guesses, {bool? won}) {
    daily['$lang|$date'] = DailyEntry(List.of(guesses), won);
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
  /// own calendar. A year is kept; the best is the longest streak ever.
  final Map<String, Map<String, int>> _dailyLogs = {};
  final Map<String, int> _dailyBests = {};

  Map<String, int> dailyLogOf(String l) => _dailyLogs[l] ??= {};
  int dailyBestOf(String l) => _dailyBests[l] ?? 0;

  /// The log and the best streak of the language being played.
  Map<String, int> get dailyLog => dailyLogOf(lang);
  set dailyLog(Map<String, int> v) => _dailyLogs[lang] = v;
  int get dailyBest => dailyBestOf(lang);
  set dailyBest(int v) => _dailyBests[lang] = v;

  /// The daily streak in [l] now (see [dailyStreakOf]).
  int dailyStreakFor(String l) => dailyStreakOf(dailyLogOf(l), dailyDate());

  /// The daily streak of the language being played.
  int get dailyStreak => dailyStreakFor(lang);

  /// Logs how [date]'s daily went in [l] (the language being played when not
  /// given) and returns the streak it leaves there.
  int recordDaily(String date, int tier, {String? lang}) {
    final l = lang ?? this.lang;
    final log = dailyLogOf(l);
    final old = log[date];
    if (old == null || tier > old) log[date] = tier;
    final oldest = dailyShift(date, -400);
    log.removeWhere((k, _) => k.compareTo(oldest) < 0);
    final streak = dailyStreakOf(log, date);
    if (streak > dailyBestOf(l)) _dailyBests[l] = streak;
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
    final next = classify(traitsOf(history, lang: l), current: current);
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
      p
        ..setString('styles', jsonEncode(_styles))
        ..setString(
          'stylesHeldBy',
          jsonEncode({
            for (final e in _stylesHeld.entries) e.key: e.value.toList(),
          }),
        )
        ..setString('styleChangesBy', jsonEncode(_styleChanges))
        // the forms before each language had its own
        ..remove('style')
        ..remove('stylesHeld')
        ..remove('styleChanges');
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
      _prefs
        ?..setString('dailyLogs', jsonEncode(_dailyLogs))
        ..setString('dailyBests', jsonEncode(_dailyBests))
        ..remove('dailyLog')
        ..remove('dailyBest');
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
      appLog.e('save', '$what was not saved: storage is not available');
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
        if (ti != null && ti >= 0 && ti < ThemeMode.values.length) {
          themeMode = ThemeMode.values[ti];
        }
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
      final ids = {for (final a in achievements.where((a) => a.global)) a.id};
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

  /// The achievements as they are saved: the global ones, then each language's.
  void _saveAchievements() {
    try {
      _prefs
        ?..setString(
          'ach',
          jsonEncode({
            for (final e in _globalAch.entries) e.key: e.value.toJson(),
          }),
        )
        ..setString(
          'achLang',
          jsonEncode({
            for (final l in _langAch.entries)
              l.key: {for (final e in l.value.entries) e.key: e.value.toJson()},
          }),
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
    'theme': themeMode.index,
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
    if (t != null) themeMode = ThemeMode.values[t];
    seenHowTo = settings['seenHowTo'] as bool? ?? seenHowTo;
    this.stats = stats;
    try {
      final p = _prefs;
      if (p != null) {
        p
          ..setString('lang', lang)
          ..setInt('length', length)
          ..setInt('tries', tries)
          ..setBool('useFrequency', useFrequency)
          ..setInt('helper', helper.index)
          ..setInt('mode', mode.index)
          ..setInt('share', share)
          ..setInt('theme', themeMode.index)
          ..setBool('seenHowTo', seenHowTo)
          ..setString('stats', jsonEncode(stats.toJson()))
          ..remove('unlocked'); // the earlier format, now replaced
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
  }) {
    this.lang = lang ?? this.lang;
    this.length = length ?? this.length;
    this.tries = tries ?? this.tries;
    this.useFrequency = useFrequency ?? this.useFrequency;
    this.helper = helper ?? this.helper;
    this.mode = mode ?? this.mode;
    this.themeMode = themeMode ?? this.themeMode;
    this.share = (share ?? this.share).clamp(0, maxShare);
    try {
      _prefs
        ?..setString('lang', this.lang)
        ..setInt('length', this.length)
        ..setInt('tries', this.tries)
        ..setBool('useFrequency', this.useFrequency)
        ..setInt('helper', this.helper.index)
        ..setInt('mode', this.mode.index)
        ..setInt('share', this.share)
        ..setInt('theme', this.themeMode.index);
    } catch (_) {}
    notifyListeners();
  }

  /// Records a finished game; returns the achievements it earned.
  List<Achievement> recordGame(GameResult r) {
    stats.record(r);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final had = Set.of(_globalAch['mastery']?.seen ?? const <String>{});
    // the achievements of this game's language, with the global ones: the
    // states are shared, so what the game changes lands in both maps
    final view = achOf(r.lang);
    final earned = advanceAchievements(
      view,
      r,
      today,
      mastered: masteredLanguages().map((l) => l.code).toSet(),
    );
    final ids = {for (final a in achievements.where((a) => a.global)) a.id};
    for (final e in view.entries) {
      if (ids.contains(e.key)) {
        _globalAch[e.key] = e.value;
      } else {
        (_langAch[r.lang] ??= {})[e.key] = e.value;
      }
    }
    earned.addAll(_grantCompletion(today));
    final fresh = (_globalAch['mastery']?.seen ?? const <String>{}).difference(
      had,
    );
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
    this.achievements = const {},
  });
  final String? style;
  final Set<String>? held;
  final int? changes;
  final Map<String, int>? dailyLog;
  final int? dailyBest;
  final Map<String, AchState> achievements;
}
