/// What learn mode keeps: one event for each word solved in free practice and
/// each finished round of a drill, newest last. It is the whole record: the
/// progress shown on the learn home and the learn achievements are worked out
/// from it, so a backup of the log restores both.
library;

/// The things there are to score in learn mode. (The opening lesson is only
/// read, so it has no event.)
enum LearnKind {
  /// A word solved with the answer shown, every guess graded.
  free,

  /// A round of "choose the best": ten positions, four words each.
  choose,

  /// Three words picked to be played first, whatever the answer, scored by what
  /// they tell together.
  sequence,

  /// A round of closing: ten endgame positions, the guess most likely to win in
  /// the tries left.
  closing,
}

/// How many questions a round of a drill has.
const drillRoundLength = 10;

/// One finished piece of learning.
class LearnEvent {
  const LearnEvent({
    required this.kind,
    required this.language,
    required this.length,
    required this.date,
    required this.questions,
    required this.right,
    required this.avgSkill,
    this.hints = 0,
  });

  final LearnKind kind;
  final String language;
  final int length;

  /// The local day, as 2026-11-01.
  final String date;

  /// How many things were graded: the guesses of a word, or the positions of a
  /// round.
  final int questions;

  /// How many of them were the best there was: guesses with skill 100, or
  /// positions where the best word was picked.
  final int right;

  /// The mean skill of what was chosen, 0 to 100.
  final double avgSkill;

  /// The hints a word used (0 for a drill).
  final int hints;

  /// Whether everything graded was the best there was.
  bool get flawless => questions > 0 && right == questions;

  Map<String, dynamic> toJson() => {
    'k': kind.index,
    'l': language,
    'n': length,
    'd': date,
    'q': questions,
    'r': right,
    's': double.parse(avgSkill.toStringAsFixed(1)),
    if (hints != 0) 'h': hints,
  };

  /// The event in [j], or null when it is not one (a damaged entry is left out
  /// rather than refusing the whole log).
  static LearnEvent? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = j['k'], l = j['l'], n = j['n'], d = j['d'];
    final q = j['q'], r = j['r'], s = j['s'];
    if (k is! int || k < 0 || k >= LearnKind.values.length) return null;
    if (l is! String || n is! int || d is! String) return null;
    if (q is! int || r is! int || s is! num) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) return null;
    final h = j['h'];
    return LearnEvent(
      kind: LearnKind.values[k],
      language: l,
      length: n,
      date: d,
      questions: q,
      right: r.clamp(0, q),
      avgSkill: s.toDouble().clamp(0.0, 100.0),
      hints: h is int ? h : 0,
    );
  }
}

/// The most events kept: the oldest go first. A round is about 100 bytes, so
/// this is a few hundred kilobytes at the most.
const learnLogLimit = 3000;

/// The events of learn mode, oldest first, with the numbers the learn home
/// shows.
class LearnLog {
  LearnLog([Iterable<LearnEvent> events = const []]) : events = List.of(events);

  final List<LearnEvent> events;

  bool get isEmpty => events.isEmpty;

  void add(LearnEvent e) {
    events.add(e);
    if (events.length > learnLogLimit) {
      events.removeRange(0, events.length - learnLogLimit);
    }
  }

  /// The events of [kind] (all kinds when null) in [language] at [length]
  /// (either left out for all), oldest first.
  List<LearnEvent> where({LearnKind? kind, String? language, int? length}) => [
    for (final e in events)
      if ((kind == null || e.kind == kind) &&
          (language == null || e.language == language) &&
          (length == null || e.length == length))
        e,
  ];

  /// The mean skill of the last [n] events matching, oldest first, one number
  /// each: the trend shown on the learn home.
  List<double> recentSkill(
    int n, {
    LearnKind? kind,
    String? language,
    int? length,
  }) {
    final all = where(kind: kind, language: language, length: length);
    return [
      for (final e in all.skip(all.length > n ? all.length - n : 0)) e.avgSkill,
    ];
  }

  /// How many days in a row, up to and including [today] (or yesterday, when
  /// nothing was done yet today), something was learned.
  int streak(String today) {
    final days = {for (final e in events) e.date};
    var day = DateTime.parse(today);
    String text(DateTime d) => d.toIso8601String().substring(0, 10);
    if (!days.contains(text(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var n = 0;
    while (days.contains(text(day))) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  List<Map<String, dynamic>> toJson() => [for (final e in events) e.toJson()];

  static LearnLog fromJson(Object? j) {
    if (j is! List) return LearnLog();
    return LearnLog([for (final e in j) ?LearnEvent.fromJson(e)]);
  }
}

/// A trend as a row of eight-step blocks, one per number (0 to 100): ▁ low, █
/// high. Empty for no numbers.
String sparkline(Iterable<double> values) {
  const blocks = '▁▂▃▄▅▆▇█';
  return [for (final v in values) blocks[(v.clamp(0, 100) / 100 * 7).round()]]
      .join();
}
