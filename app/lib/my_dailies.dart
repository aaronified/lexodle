import 'modes.dart';

/// The dailies a player chose to play, per language. Today shows these, the
/// reminders follow them, and "done for the day" means all of them. At least one
/// is always chosen; a new player has classic.
class MyDailies {
  MyDailies([Map<String, Set<GameMode>>? chosen])
    : _chosen = {
        for (final e in (chosen ?? const {}).entries)
          if (e.value.isNotEmpty) e.key: Set.of(e.value),
      };

  final Map<String, Set<GameMode>> _chosen;

  /// The modes chosen for [lang], in the app's own order; classic when none.
  List<GameMode> of(String lang) {
    final set = _chosen[lang] ?? const {GameMode.classic};
    return [
      for (final m in GameMode.values)
        if (set.contains(m)) m,
    ];
  }

  bool has(String lang, GameMode m) => of(lang).contains(m);

  /// Adds [m]; true when it was not there.
  bool add(String lang, GameMode m) {
    if (!m.hasDaily) return false;
    final set = _chosen.putIfAbsent(lang, () => {GameMode.classic});
    return set.add(m);
  }

  /// Drops [m]; false when it is the last one chosen (one must stay) or was not
  /// there.
  bool remove(String lang, GameMode m) {
    final set = _chosen.putIfAbsent(lang, () => {GameMode.classic});
    if (!set.contains(m) || set.length == 1) return false;
    return set.remove(m);
  }

  /// A veteran meeting the choice for the first time: every daily that has a
  /// streak, or classic when none has.
  void startFrom(String lang, Iterable<GameMode> withStreak) {
    final set = {
      for (final m in withStreak)
        if (m.hasDaily) m,
    };
    _chosen[lang] = set.isEmpty ? {GameMode.classic} : set;
  }

  /// Whether [lang] has had its choice made (stored or started from streaks).
  bool decided(String lang) => _chosen.containsKey(lang);

  Map<String, dynamic> toJson() => {
    for (final e in _chosen.entries) e.key: [for (final m in e.value) m.index],
  };

  /// The choice in [j]; a damaged entry is left out and that language falls back
  /// to classic.
  static MyDailies fromJson(Object? j) {
    final out = <String, Set<GameMode>>{};
    if (j is Map) {
      for (final e in j.entries) {
        final k = e.key, v = e.value;
        if (k is! String || v is! List) continue;
        final set = <GameMode>{
          for (final i in v)
            if (i is int && i >= 0 && i < GameMode.values.length)
              GameMode.values[i],
        };
        if (set.isNotEmpty) out[k] = set;
      }
    }
    return MyDailies(out);
  }
}
