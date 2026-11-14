import 'modes.dart';

/// How the dailies on Today are put in order.
enum TodaySort {
  /// in progress first, then not started, then done (the app's own way)
  status,

  /// the order the player gave them (see [orderModes])
  mine,

  /// by the name of the mode
  name,

  /// the longest streak first
  streak;

  String get label => switch (this) {
    status => 'status',
    mine => 'my order',
    name => 'name',
    streak => 'streak',
  };

  /// The sort stored as [i]; status when it is not one.
  static TodaySort fromIndex(Object? i) =>
      i is int && i >= 0 && i < values.length ? values[i] : status;
}

/// [modes] in the order the player gave them in [mine]; modes [mine] does not
/// name follow, in the app's own order.
List<GameMode> orderModes(Iterable<GameMode> modes, List<GameMode> mine) {
  final set = modes.toSet();
  return [
    for (final m in mine)
      if (set.remove(m)) m,
    for (final m in GameMode.values)
      if (set.contains(m)) m,
  ];
}

/// The order stored as the mode indices in [j]; damaged entries are left out.
List<GameMode> dailyOrderFromJson(Object? j) {
  if (j is! List) return const [];
  final out = <GameMode>[];
  for (final i in j) {
    if (i is int && i >= 0 && i < GameMode.values.length) {
      final m = GameMode.values[i];
      if (m.hasDaily && !out.contains(m)) out.add(m);
    }
  }
  return out;
}
