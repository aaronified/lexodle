import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      for (final e in ((j['mastery'] ?? {}) as Map).entries)
        e.key as String: {for (final x in e.value as List) x as String},
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
          ? masteryCell(r.length, r.tries, r.pool)
          : null;
      if (cell != null) (mastery[r.lang] ??= {}).add(cell);
    } else {
      streak = 0;
    }
  }
}

/// The settings a win counts towards mastery for: one word length, one tries
/// level and one pool level of the difficulty matrix. Null for a game played
/// at settings outside the matrix.
String? masteryCell(int length, int tries, int pool) =>
    triesLevels.any((l) => l.$2 == tries) && poolSizes.contains(pool)
    ? '$length:$tries:$pool'
    : null;

/// How many settings a language has to be won at for mastery: every length it
/// offers at every tries level and at every pool level it has the words for
/// (see [poolsOffered]).
int masteryTarget(Language l) => [
  for (final n in l.lengths)
    triesLevels.length * poolsOffered(l.counts[n]).length,
].fold(0, (a, b) => a + b);

/// How many of [cells] (`length:tries:pool`) are settings [l] still offers. A
/// win at a setting a language no longer offers stays recorded but does not
/// count towards its mastery.
int masteryWon(Language l, Set<String>? cells) {
  if (cells == null) return 0;
  var n = 0;
  for (final cell in cells) {
    final p = cell.split(':');
    if (p.length != 3) continue;
    final length = int.tryParse(p[0]), tries = int.tryParse(p[1]);
    final pool = int.tryParse(p[2]);
    if (length == null || tries == null || pool == null) continue;
    if (l.lengths.contains(length) &&
        triesLevels.any((t) => t.$2 == tries) &&
        poolsOffered(l.counts[length]).contains(pool)) {
      n++;
    }
  }
  return n;
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
  bool get numbered => track != Track.event && track != Track.badges;
}

bool _always(GameResult r) => true;

const _classicOnly = {GameMode.classic};
const _anyMode = {GameMode.classic, GameMode.quartet, GameMode.relay};
const _quartetOnly = {GameMode.quartet};
const _relayOnly = {GameMode.relay};

/// Every achievement. Numbered ones show a progress bar and, once earned, start
/// again from 0; events can be earned again too, and every earning is counted.
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
    'flame',
    'three in a row',
    'win 3 games in a row',
    track: Track.streak,
    target: 3,
    modes: _anyMode,
  ),
  Achievement(
    'streak_7',
    'sparkles',
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
    'building-broadcast-tower',
    'babel',
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
    ('daily_14', 'meteor', 'bonfire', 14),
    ('daily_30', 'sun', 'furnace', 30),
    ('daily_60', 'mountain', 'forge', 60),
    ('daily_100', 'star', 'inferno', 100),
    ('daily_200', 'stars', 'phoenix', 200),
    ('daily_365', 'moon', 'eternal flame', 365),
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
    'butterfly',
    'chameleon',
    'change your playstyle',
    repeat: false,
    qualifies: (r) => r.styleChanged,
  ),
  Achievement(
    'many_hats',
    'rosette',
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
];

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
        break; // collected above
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

  /// How many of the most common words an answer can be drawn from.
  int pool = defaultPool;
  bool seenHowTo = false;

  /// Whether settings have been read, so first-run decisions wait for them.
  bool loaded = false;

  /// Whether this browser can remember anything; first-run help is shown only
  /// when it can, or it would reappear on every visit.
  bool get canRemember => _prefs != null;
  Stats stats = Stats();
  Map<String, AchState> ach = {};

  /// The languages whose mastery the last recorded game completed.
  List<Language> lastMastered = const [];

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
      _prefs?.setString(
        'daily',
        jsonEncode({for (final e in daily.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
    notifyListeners();
  }

  /// How each day's daily went (date -> [dailyMissed], [dailySolved] or
  /// [dailyDouble]), across every language: the streak counts a day on which a
  /// daily was solved in any of them. A year is kept; [dailyBest] is the longest
  /// streak ever.
  Map<String, int> dailyLog = {};
  int dailyBest = 0;

  /// The daily streak now (see [dailyStreakOf]).
  int get dailyStreak => dailyStreakOf(dailyLog, dailyDate());

  /// Logs how [date]'s daily went and returns the streak it leaves. A day
  /// already solved is never marked missed by a second language.
  int recordDaily(String date, int tier) {
    final old = dailyLog[date];
    if (old == null || tier > old) dailyLog[date] = tier;
    final oldest = dailyShift(date, -400);
    dailyLog.removeWhere((k, _) => k.compareTo(oldest) < 0);
    final streak = dailyStreakOf(dailyLog, date);
    if (streak > dailyBest) dailyBest = streak;
    _saveDailyLog();
    notifyListeners();
    return streak;
  }

  /// Every game played, as tables (see history.dart): kept so skill, luck and
  /// daring can be worked out again, games reviewed, and a playstyle read from
  /// the last 100.
  History history = History();

  /// The playstyle now (a [Playstyle.id]; null until rated), every one the player
  /// has been rated, and how many times it has changed. See playstyle.dart.
  String? styleId;
  Set<String> stylesHeld = {};
  int styleChanges = 0;

  Playstyle? get style => playstyleById(styleId);

  /// Reads the playstyle again from the last 100 games, after a game was saved
  /// to the [history]. A player not yet rated keeps none; one who has been rated
  /// keeps their style while the numbers stay near it (see [classify]). Returns
  /// the style and whether this moved them from one to another.
  ({Playstyle? style, bool changed}) updateStyle() {
    final next = classify(traitsOf(history), current: style);
    if (next == null) return (style: style, changed: false);
    final changed = styleId != null && styleId != next.id;
    if (changed) styleChanges++;
    styleId = next.id;
    stylesHeld.add(next.id);
    _saveStyle();
    notifyListeners();
    return (style: next, changed: changed);
  }

  void _saveStyle() {
    try {
      final p = _prefs;
      if (p == null) return;
      if (styleId == null) {
        p.remove('style');
      } else {
        p.setString('style', styleId!);
      }
      p
        ..setStringList('stylesHeld', stylesHeld.toList())
        ..setInt('styleChanges', styleChanges);
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
    DateTime? now,
  }) {
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
          p.remove(historyChunkKey(m));
        } else {
          p.setString(historyChunkKey(m), jsonEncode(chunk));
        }
      }
      p.setStringList(historyIndexKey, history.months());
      p.remove('history'); // the one string of earlier versions
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
        final s = p.getString(historyChunkKey(m));
        if (s == null) continue;
        try {
          final chunk = jsonDecode(s);
          History.fromJson(chunk); // checked on its own
          good.add(chunk);
        } catch (_) {
          // a damaged month is left out, the others are kept
        }
      }
      return History.fromChunks(good);
    }
    final old = p.getString('history');
    if (old == null) return History();
    final h = History.fromJson(jsonDecode(old));
    h.markAllDirty(); // moved to months on the next save
    return h;
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
        ?..setString('dailyLog', jsonEncode(dailyLog))
        ..setInt('dailyBest', dailyBest);
    } catch (_) {}
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      lang = p.getString('lang') ?? lang;
      length = p.getInt('length') ?? length;
      tries = p.getInt('tries') ?? tries;
      final pl = p.getInt('pool');
      if (pl != null && poolSizes.contains(pl)) pool = pl;
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
      final s = p.getString('stats');
      if (s != null) stats = Stats.fromJson(jsonDecode(s));
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
      } catch (_) {
        daily = {};
      }
      try {
        history = _readHistory(p);
        if (history.dirtyMonths.isNotEmpty) saveHistory(); // from the old form
      } catch (_) {
        history = History(); // damaged: start the record again
      }
      try {
        styleId = playstyleById(p.getString('style'))?.id;
        stylesHeld = {
          for (final id in p.getStringList('stylesHeld') ?? const <String>[])
            if (playstyleById(id) != null) id,
        };
        styleChanges = (p.getInt('styleChanges') ?? 0).clamp(0, 1000000);
      } catch (_) {
        styleId = null;
        stylesHeld = {};
        styleChanges = 0;
      }
      try {
        final log = p.getString('dailyLog');
        if (log != null) {
          dailyLog = {
            for (final e in (jsonDecode(log) as Map).entries)
              e.key as String: (e.value as int).clamp(dailyMissed, dailyDouble),
          };
        }
        dailyBest = p.getInt('dailyBest') ?? 0;
      } catch (_) {
        dailyLog = {};
      }
      final a = p.getString('ach');
      if (a != null) {
        ach = {
          for (final e in (jsonDecode(a) as Map).entries)
            e.key as String: AchState.fromJson(
              (e.value as Map).cast<String, dynamic>(),
            ),
        };
      } else {
        // the earlier format: achievement id -> the day it was earned, once
        final u = p.getString('unlocked');
        if (u != null) {
          for (final e in (jsonDecode(u) as Map).entries) {
            ach[e.key as String] = AchState(
              times: 1,
              dates: [e.value as String],
            );
          }
        }
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  /// The settings as they are saved (and as a backup keeps them).
  Map<String, Object> settingsJson() => {
    'lang': lang,
    'length': length,
    'tries': tries,
    'pool': pool,
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
    Map<String, int>? dailyLog,
    int? dailyBest,
    History? history,
    ({String? style, Set<String> held, int changes})? playstyle,
  }) {
    // and one from before the playstyles
    if (playstyle != null) {
      styleId = playstyleById(playstyle.style)?.id;
      stylesHeld = {
        for (final id in playstyle.held)
          if (playstyleById(id) != null) id,
      };
      styleChanges = playstyle.changes;
      _saveStyle();
    }
    // a backup from before the daily existed has none: what is here stays
    if (dailyLog != null) this.dailyLog = Map.of(dailyLog);
    if (dailyBest != null) this.dailyBest = dailyBest;
    _saveDailyLog();
    // likewise a backup from before the history
    if (history != null) _replaceHistory(history);
    lang = settings['lang'] as String? ?? lang;
    length = settings['length'] as int? ?? length;
    tries = settings['tries'] as int? ?? tries;
    pool = settings['pool'] as int? ?? pool;
    final h = settings['helper'] as int?;
    if (h != null) helper = Helper.values[h];
    final m = settings['mode'] as int?;
    if (m != null) mode = GameMode.values[m];
    share = settings['share'] as int? ?? share;
    final t = settings['theme'] as int?;
    if (t != null) themeMode = ThemeMode.values[t];
    seenHowTo = settings['seenHowTo'] as bool? ?? seenHowTo;
    this.stats = stats;
    this.ach = ach;
    try {
      final p = _prefs;
      if (p != null) {
        p
          ..setString('lang', lang)
          ..setInt('length', length)
          ..setInt('tries', tries)
          ..setInt('pool', pool)
          ..setInt('helper', helper.index)
          ..setInt('mode', mode.index)
          ..setInt('share', share)
          ..setInt('theme', themeMode.index)
          ..setBool('seenHowTo', seenHowTo)
          ..setString('stats', jsonEncode(stats.toJson()))
          ..setString(
            'ach',
            jsonEncode({for (final e in ach.entries) e.key: e.value.toJson()}),
          )
          ..remove('unlocked'); // the earlier format, now replaced
      }
    } catch (_) {}
    notifyListeners();
  }

  void markHowToSeen() {
    seenHowTo = true;
    try {
      _prefs?.setBool('seenHowTo', true);
    } catch (_) {}
  }

  void setup({
    String? lang,
    int? length,
    int? tries,
    int? pool,
    Helper? helper,
    GameMode? mode,
    int? share,
    ThemeMode? themeMode,
  }) {
    this.lang = lang ?? this.lang;
    this.length = length ?? this.length;
    this.tries = tries ?? this.tries;
    this.pool = pool ?? this.pool;
    this.helper = helper ?? this.helper;
    this.mode = mode ?? this.mode;
    this.themeMode = themeMode ?? this.themeMode;
    this.share = (share ?? this.share).clamp(0, maxShare);
    try {
      _prefs
        ?..setString('lang', this.lang)
        ..setInt('length', this.length)
        ..setInt('tries', this.tries)
        ..setInt('pool', this.pool)
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
    final had = Set.of(ach['mastery']?.seen ?? const <String>{});
    final earned = advanceAchievements(
      ach,
      r,
      today,
      mastered: masteredLanguages().map((l) => l.code).toSet(),
    );
    final fresh = (ach['mastery']?.seen ?? const <String>{}).difference(had);
    lastMastered = [
      for (final l in WordBank.loadedLanguages ?? const <Language>[])
        if (fresh.contains(l.code)) l,
    ];
    try {
      _prefs
        ?..setString('stats', jsonEncode(stats.toJson()))
        ..setString(
          'ach',
          jsonEncode({for (final e in ach.entries) e.key: e.value.toJson()}),
        );
    } catch (_) {}
    notifyListeners();
    return earned;
  }
}
