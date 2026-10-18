import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'difficulty.dart';
import 'modes.dart';
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
  });
  final String lang;
  final int length;
  final int tries;
  final int used;
  final bool won;

  /// The answer-pool size the game was played at (0 when not known).
  final int pool;

  /// The skill score of every guess, in order.
  final List<double> skills;

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
      final cell = masteryCell(r.length, r.tries, r.pool);
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
/// offers at every tries level and pool level.
int masteryTarget(Language l) =>
    l.lengths.length * triesLevels.length * poolSizes.length;

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

  bool get numbered => track != Track.event;
}

bool _always(GameResult r) => true;

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
  ),
  Achievement(
    'long_haul',
    'square-number-8',
    'long haul',
    'win an 8-letter word',
    qualifies: (r) => r.won && r.length == 8,
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
  ),
  Achievement(
    'streak_3',
    'flame',
    'three in a row',
    'win 3 games in a row',
    track: Track.streak,
    target: 3,
  ),
  Achievement(
    'streak_7',
    'sparkles',
    'seven in a row',
    'win 7 games in a row',
    track: Track.streak,
    target: 7,
  ),
  Achievement(
    'bilingual',
    'bubble-text',
    'bilingual',
    'win in 2 languages',
    track: Track.languages,
    target: 2,
  ),
  Achievement(
    'polyglot_3',
    'world',
    'polyglot',
    'win in 3 languages',
    track: Track.languages,
    target: 3,
  ),
  Achievement(
    'polyglot_9',
    'building-broadcast-tower',
    'babel',
    'win in 9 languages',
    track: Track.languages,
    target: 9,
  ),
  Achievement(
    'wins_10',
    'award',
    'regular',
    'win 10 games',
    track: Track.counter,
    target: 10,
    qualifies: (r) => r.won,
  ),
  Achievement(
    'wins_50',
    'shield-check',
    'veteran',
    'win 50 games',
    track: Track.counter,
    target: 50,
    qualifies: (r) => r.won,
  ),
  Achievement(
    'wins_100',
    'crown',
    'dustwalker',
    'win 100 games',
    track: Track.counter,
    target: 100,
    qualifies: (r) => r.won,
  ),
  Achievement(
    'played_25',
    'hourglass',
    'persistent',
    'play 25 games',
    track: Track.counter,
    target: 25,
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
List<Achievement> advanceAchievements(
  Map<String, AchState> states,
  GameResult r,
  String today,
) {
  final earned = <Achievement>[];
  for (final a in achievements) {
    final st = states.putIfAbsent(a.id, AchState.new);
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
    }
    if (got) {
      st.times++;
      st.dates.add(today);
      if (a.numbered) {
        // numbered achievements start again from 0 once earned
        st.progress = 0;
        st.seen.clear();
      }
      earned.add(a);
    }
  }
  return earned;
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

  /// How many different achievements have been earned at least once.
  int get unlockedCount => ach.values.where((s) => s.times > 0).length;

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
    final earned = advanceAchievements(ach, r, today);
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
