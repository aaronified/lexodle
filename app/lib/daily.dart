import 'dart:math' show min;

import 'clock.dart';
import 'modes.dart';
import 'words.dart';

/// The daily word: one word per language per day, the same for everyone on that
/// date.
///
/// It is not drawn at random on the device. The date and the language are
/// hashed to a number, and that number picks one of the [dailyAnswers] most
/// common words of the language at the daily's length, each equally likely (the
/// word frequency is never used for a daily, and no other word can be the
/// answer), so every device that has the same word list gets the same word with
/// no server.
/// The day is the player's own: it changes at their local midnight (the time
/// itself comes from the server, see [TrustedClock], so the device clock cannot
/// be set to another day). The difficulty is fixed too, whatever the settings
/// say.
const dailyLength = 5;
const dailyTries = 6;

/// How many of the most common words a daily can be: the rest are valid guesses
/// but never the answer.
const dailyAnswers = 3000;

/// The first date a daily is drawn by the sigmoid curve of [WordBank.curveWeights]
/// from the whole list, every word of it a valid guess: the commonest words
/// about equally likely, fewer and fewer past the 3,000th, and none to speak of
/// by the 3,500th. Earlier dates keep the draw they had, so that a daily played
/// before it replays against the same word.
const dailyCurveFrom = '2026-10-30';

/// From this date the words of a daily quartet or relay race may share a letter
/// with the chance of [dailyShare] percent, as in any other game (a word with
/// a letter twice counts as sharing one). Before, they shared none, which
/// favoured words with a letter twice: all four of them, one day.
const dailyShareFrom = '2026-11-01';

/// The chance, in percent, that a daily word may share a letter with an earlier
/// one, from [dailyShareFrom].
const dailyShare = 10;

/// The tries of a blind daily.
const blindDailyTries = 10;

/// Whether the daily of [date] is drawn by the curve.
bool dailyUsesCurve(String date) =>
    date.length == 10 && date.compareTo(dailyCurveFrom) >= 0;

/// The clock the daily reads: the server's time when it could be had, else the
/// device's. Tests replace it.
DateTime Function() dailyClock = TrustedClock.now;

String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// The date of a daily as `2026-10-24`, on the player's own calendar: the day
/// changes at their local midnight, so the word is the same for everyone who is
/// on the same date, not at the same instant.
String dailyDate([DateTime? now]) => _ymd((now ?? dailyClock()).toLocal());

/// [date] moved by [days] (negative for earlier), still as `2026-10-24`.
/// A malformed [date] comes back unchanged.
String dailyShift(String date, int days) {
  final d = DateTime.tryParse(date);
  if (d == null) return date;
  // plain calendar arithmetic: no time zone is involved in moving a date
  return _ymd(DateTime.utc(d.year, d.month, d.day + days));
}

/// How each day of a daily log went: 0 missed, 1 solved, 2 solved with a double
/// fire (in three guesses or fewer, or with every guess at 80 skill or more).
const dailyMissed = 0, dailySolved = 1, dailyDouble = 2;

/// The daily streak: the days in a row, up to [today], on which the daily was
/// solved. [log] maps a date to how that day went. A day not yet played does
/// not break it (the streak is still alive until the day is over); a day played
/// and missed does.
int dailyStreakOf(Map<String, int> log, String today) {
  final t = log[today];
  if (t == dailyMissed) return 0;
  var day = t == null ? dailyShift(today, -1) : today;
  var n = 0;
  while ((log[day] ?? dailyMissed) >= dailySolved) {
    n++;
    day = dailyShift(day, -1);
  }
  return n;
}

/// The last [days] dates ending with [today], oldest first: a rolling week,
/// not a calendar one, so today is always the last of them.
List<String> dailyRolling(String today, [int days = 7]) {
  if (DateTime.tryParse(today) == null) return const [];
  return [for (var i = days - 1; i >= 0; i--) dailyShift(today, -i)];
}

/// The weekday of [date] as one letter (m t w t f s s), for the calendar.
String dailyLetter(String date) {
  final d = DateTime.tryParse(date);
  return d == null ? '' : 'mtwtfss'[d.weekday - 1];
}

const _prime = 2147483647; // 2^31 - 1

/// A number from [s], the same on every platform: only integer arithmetic that
/// stays below 2^53 (a web build has no 64-bit ints) and no `Random`, whose
/// sequence for a seed is not promised to stay the same between versions.
///
/// Characters are folded in with a polynomial hash; the rounds after it mix
/// bits non-linearly, so that dates a day apart land far apart rather than on
/// neighbouring words.
int dailyHash(String s) {
  var h = 1;
  for (final u in s.codeUnits) {
    h = (h * 1000003 + u) % _prime;
  }
  for (var i = 0; i < 3; i++) {
    h ^= h >> 15;
    h = h * 48271 % _prime;
  }
  return h;
}

/// A word is not picked again for this many days after it was a daily.
const dailyNoRepeat = 90;

/// The first date the no-repeat rule runs from; earlier dates are a plain hash.
const _dailyAnchor = '2026-10-26';

// The picks made so far per language and list size, one per day from the anchor.
final _picks = <String, List<int>>{};

/// Which of [n] words the daily for [lang] on [date] is.
///
/// Each day takes a hashed pick; a word that was a daily in the last
/// [dailyNoRepeat] days is drawn again with the next counter. The days are
/// replayed from the anchor date, so the answer depends only on the date, never
/// on when the app was last opened or on any stored state.
int dailyIndex(String lang, String date, int n) {
  final d = DateTime.tryParse(date);
  final a = DateTime.utc(2026, 10, 26);
  final day = d == null
      ? -1
      : DateTime.utc(d.year, d.month, d.day).difference(a).inDays;
  if (day < 0 || day > 36500) return dailyHash('lexodle-daily|$lang|$date') % n;
  final picks = _picks.putIfAbsent('$lang|$n', () => []);
  final window = min(dailyNoRepeat, n - 1);
  while (picks.length <= day) {
    final ds = dailyShift(_dailyAnchor, picks.length);
    final from = picks.length - window;
    var k = 0;
    int pick;
    do {
      pick = dailyHash('lexodle-daily|$lang|$ds|$k') % n;
      k++;
    } while (picks.indexOf(pick, from < 0 ? 0 : from) >= 0);
    picks.add(pick);
  }
  return picks[day];
}

/// The running totals of [weights]: entry i is the sum of the first i + 1.
List<int> _totals(List<int> weights) {
  var t = 0;
  return [for (final w in weights) t += w];
}

/// The word a hash picks when each word has its weight: the first whose running
/// total is above the hash taken modulo the whole. Whole numbers only, so every
/// device picks the same.
int _byWeight(List<int> totals, int hash) {
  final r = hash % totals.last;
  var lo = 0, hi = totals.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (totals[mid] > r) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo;
}

final _curveTotals = <String, List<int>>{};
final _curvePicks = <String, List<int>>{};

List<int> _totalsOf(String key, List<int> weights) =>
    _curveTotals.putIfAbsent('$key|${weights.length}', () => _totals(weights));

/// Which word the curve daily of [key] (the language, and the mode when it is
/// not classic) on [date] is, among words with [weights]. Like [dailyIndex],
/// a word that was a daily in the last [dailyNoRepeat] days is drawn again; the
/// days are replayed from [dailyCurveFrom].
int dailyCurveIndex(String key, String date, List<int> weights) {
  final d = DateTime.tryParse(date);
  final a = DateTime.utc(2026, 10, 30);
  final day = d == null
      ? 0
      : DateTime.utc(d.year, d.month, d.day).difference(a).inDays;
  final totals = _totalsOf(key, weights);
  int pick(String ds, int k) =>
      _byWeight(totals, dailyHash('lexodle-daily-curve|$key|$ds|$k'));
  if (day < 0 || day > 36500) return pick(date, 0);
  final picks = _curvePicks.putIfAbsent('$key|${weights.length}', () => []);
  final window = min(dailyNoRepeat, weights.length - 1);
  while (picks.length <= day) {
    final ds = dailyShift(dailyCurveFrom, picks.length);
    final from = picks.length - window;
    var k = 0;
    int p;
    do {
      p = pick(ds, k);
      k++;
    } while (picks.indexOf(p, from < 0 ? 0 : from) >= 0);
    picks.add(p);
  }
  return picks[day];
}

/// Today's (or [date]'s) daily: the date and its answer.
class Daily {
  const Daily(
    this.date,
    this.answer, {
    this.length = dailyLength,
    this.tries = dailyTries,
  });
  final String date;
  final String answer;

  /// The word length and the tries: the daily's own, or those of a puzzle a
  /// link carries (its [date] is then empty).
  final int length;
  final int tries;

  /// The daily of [bank]'s language on [date] (default today), or null when the
  /// language has no words of the daily's length.
  static Daily? of(
    WordBank bank, [
    String? date,
    GameMode mode = GameMode.classic,
  ]) {
    final d = date ?? dailyDate();
    final all = bank.answers(dailyLength);
    if (all.isEmpty) return null;
    final code = bank.language.code;
    final key = mode == GameMode.classic ? code : '$code|${mode.name}';
    if (dailyUsesCurve(d)) {
      final w = bank.curveWeights(dailyLength);
      return Daily(
        d,
        all[dailyCurveIndex(key, d, w)],
        tries: mode == GameMode.lockdown ? lockdownTries : dailyTriesOf(mode),
      );
    }
    final pool = all.length > dailyAnswers ? all.sublist(0, dailyAnswers) : all;
    return Daily(d, pool[dailyIndex(code, d, pool.length)]);
  }
}

/// The tries of a daily in [mode]: the fixed daily difficulty, with the extra
/// tries the mode has (9 for a quartet, 10 for a relay race).
int dailyTriesOf(GameMode mode) =>
    mode == GameMode.blind ? blindDailyTries : triesFor(mode, dailyTries);

/// Today's (or [date]'s) daily quartet or relay race: four words, drawn from
/// the date, the language and the mode alone, so that every device with the same
/// word list gets the same four. They are five letters long, among the
/// [dailyAnswers] most common words, and share no letter, in the order they are
/// played.
class DailyMulti {
  DailyMulti(
    this.date,
    this.mode,
    this.answers, {
    this.length = dailyLength,
    int? tries,
  }) : tries = tries ?? dailyTriesOf(mode);
  final String date;
  final GameMode mode;
  final List<String> answers;

  /// The word length and the tries: the daily's own, or those of a puzzle a
  /// link carries (its [date] is then empty).
  final int length;
  final int tries;

  /// The daily of [mode] for [bank]'s language on [date] (default today), or
  /// null when the language has too few words of the daily's length.
  static DailyMulti? of(WordBank bank, GameMode mode, [String? date]) {
    final d = date ?? dailyDate();
    final all = bank.answers(dailyLength);
    final curve = dailyUsesCurve(d);
    final pool = curve || all.length <= dailyAnswers
        ? all
        : all.sublist(0, dailyAnswers);
    if (pool.length < mode.boards) return null;
    final code = bank.language.code;
    final totals = curve
        ? _totalsOf(code, bank.curveWeights(dailyLength))
        : null;
    String word(int k, int j, int t) {
      final h = dailyHash('lexodle-daily|$code|$d|${mode.name}|$k|$j|$t');
      return pool[totals == null ? h % pool.length : _byWeight(totals, h)];
    }

    // from dailyShareFrom a word that shares a letter is kept with the chance
    // dailyShare, drawn from the date like everything else
    final mayShare = d.length == 10 && d.compareTo(dailyShareFrom) >= 0;
    bool keeps(List<String> chosen, String w, int k, int j, int t) {
      if (chosen.contains(w)) return false;
      if (!mayShare) return chosen.every((o) => !sharesLetter(o, w));
      final shared =
          chosen.where((o) => sharesLetter(o, w)).length +
          (hasRepeatedLetter(w) ? 1 : 0);
      if (shared == 0) return true;
      final u = dailyHash('lexodle-share|$code|$d|${mode.name}|$k|$j|$t');
      return u % 100 < dailyShare;
    }

    for (var k = 0; k < 2000; k++) {
      final chosen = <String>[];
      for (var j = 0; j < mode.boards; j++) {
        String? pick;
        for (var t = 0; t < 60 && pick == null; t++) {
          final w = word(k, j, t);
          if (keeps(chosen, w, k, j, t)) pick = w;
        }
        if (pick == null) break;
        chosen.add(pick);
      }
      if (chosen.length == mode.boards) return DailyMulti(d, mode, chosen);
    }
    // no four words without a shared letter (a very small list): any four
    final chosen = <String>[];
    for (var t = 0; chosen.length < mode.boards; t++) {
      final w = word(0, 0, t);
      if (!chosen.contains(w)) chosen.add(w);
    }
    return DailyMulti(d, mode, chosen);
  }
}
