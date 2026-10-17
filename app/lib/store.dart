import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much the game tells you while you play. Whatever the level, a finished
/// game reveals everything (as in the original).
enum Helper {
  off('off', 'nothing', false, false, false),
  skill('skill', 'per guess', true, false, false),
  skillLuck('skill + luck', 'per guess', true, true, false),
  full('full', 'and words left', true, true, true);

  const Helper(this.label, this.sub, this.showSkill, this.showLuck, this.showWordsLeft);
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
  });
  final String lang;
  final int length;
  final int tries;
  final int used;
  final bool won;
}

class Stats {
  int played = 0;
  int wins = 0;
  int streak = 0;
  int bestStreak = 0;
  Set<String> langsWon = {};
  Set<int> lengthsWon = {};

  Map<String, dynamic> toJson() => {
        'played': played,
        'wins': wins,
        'streak': streak,
        'bestStreak': bestStreak,
        'langsWon': langsWon.toList(),
        'lengthsWon': lengthsWon.toList(),
      };

  static Stats fromJson(Map<String, dynamic> j) => Stats()
    ..played = j['played'] ?? 0
    ..wins = j['wins'] ?? 0
    ..streak = j['streak'] ?? 0
    ..bestStreak = j['bestStreak'] ?? 0
    ..langsWon = {for (final l in j['langsWon'] ?? []) l as String}
    ..lengthsWon = {for (final l in j['lengthsWon'] ?? []) l as int};

  void record(GameResult r) {
    played++;
    if (r.won) {
      wins++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      langsWon.add(r.lang);
      lengthsWon.add(r.length);
    } else {
      streak = 0;
    }
  }
}

class Achievement {
  const Achievement(this.id, this.title, this.description, this.test);
  final String id;
  final String title;
  final String description;
  final bool Function(Stats s, GameResult r) test;
}

/// Tested after every game, with the stats already updated.
final achievements = <Achievement>[
  Achievement('first_light', 'first light', 'win a game', (s, r) => r.won),
  Achievement('one_shot', 'one shot', 'win on the first guess',
      (s, r) => r.won && r.used == 1),
  Achievement('last_breath', 'last breath',
      'win on your very last try (4+ tries)',
      (s, r) => r.won && r.used == r.tries && r.tries >= 4),
  Achievement('no_mercy', 'no mercy', 'win with 3 tries or fewer',
      (s, r) => r.won && r.tries <= 3),
  Achievement('brevity', 'brevity', 'win a 4-letter word',
      (s, r) => r.won && r.length == 4),
  Achievement('long_haul', 'long haul', 'win an 8-letter word',
      (s, r) => r.won && r.length == 8),
  Achievement('full_range', 'full range', 'win at every length, 4 to 8',
      (s, r) => {4, 5, 6, 7, 8}.every(s.lengthsWon.contains)),
  Achievement('streak_3', 'three in a row', 'win 3 games in a row',
      (s, r) => s.streak >= 3),
  Achievement('streak_7', 'seven in a row', 'win 7 games in a row',
      (s, r) => s.streak >= 7),
  Achievement('polyglot_3', 'polyglot', 'win in 3 languages',
      (s, r) => s.langsWon.length >= 3),
  Achievement('polyglot_9', 'babel', 'win in 9 languages',
      (s, r) => s.langsWon.length >= 9),
  Achievement('wins_10', 'regular', 'win 10 games', (s, r) => s.wins >= 10),
  Achievement('wins_50', 'veteran', 'win 50 games', (s, r) => s.wins >= 50),
  Achievement('wins_100', 'dustwalker', 'win 100 games',
      (s, r) => s.wins >= 100),
  Achievement('played_25', 'persistent', 'play 25 games',
      (s, r) => s.played >= 25),
];

/// Settings, stats and unlocked achievements, kept in shared_preferences
/// (localStorage on the web). Every read and write tolerates failure: the
/// game must still play with storage blocked.
class AppState extends ChangeNotifier {
  String lang = 'en';
  int length = 5;
  int tries = 6;
  Helper helper = Helper.full;
  Stats stats = Stats();
  Map<String, String> unlocked = {};

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      lang = p.getString('lang') ?? lang;
      length = p.getInt('length') ?? length;
      tries = p.getInt('tries') ?? tries;
      final h = p.getInt('helper');
      if (h != null && h >= 0 && h < Helper.values.length) {
        helper = Helper.values[h];
      } else if (p.getBool('showWordsLeft') == false) {
        helper = Helper.off; // the setting this replaced
      }
      final s = p.getString('stats');
      if (s != null) stats = Stats.fromJson(jsonDecode(s));
      final u = p.getString('unlocked');
      if (u != null) {
        unlocked = (jsonDecode(u) as Map).cast<String, String>();
      }
    } catch (_) {}
    notifyListeners();
  }

  void setup({String? lang, int? length, int? tries, Helper? helper}) {
    this.lang = lang ?? this.lang;
    this.length = length ?? this.length;
    this.tries = tries ?? this.tries;
    this.helper = helper ?? this.helper;
    try {
      _prefs
        ?..setString('lang', this.lang)
        ..setInt('length', this.length)
        ..setInt('tries', this.tries)
        ..setInt('helper', this.helper.index);
    } catch (_) {}
    notifyListeners();
  }

  /// Records a finished game; returns the achievements it unlocked.
  List<Achievement> recordGame(GameResult r) {
    stats.record(r);
    final fresh = [
      for (final a in achievements)
        if (!unlocked.containsKey(a.id) && a.test(stats, r)) a,
    ];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    for (final a in fresh) {
      unlocked[a.id] = today;
    }
    try {
      _prefs
        ?..setString('stats', jsonEncode(stats.toJson()))
        ..setString('unlocked', jsonEncode(unlocked));
    } catch (_) {}
    notifyListeners();
    return fresh;
  }
}
