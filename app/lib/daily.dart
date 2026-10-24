import 'clock.dart';
import 'difficulty.dart';
import 'words.dart';

/// The daily word: one word per language per day, the same for everyone on that
/// date.
///
/// It is not drawn at random on the device. The date and the language are
/// hashed to a number, and that number picks one word of the fixed pool, so
/// every device that has the same word list gets the same word with no server.
/// The day is the player's own: it changes at their local midnight (the time
/// itself comes from the server, see [TrustedClock], so the device clock cannot
/// be set to another day). The difficulty is fixed too, whatever the settings
/// say.
const dailyLength = 5;
const dailyTries = 6;
const dailyPool = 3000;

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

/// The seven dates of the week that [today] falls in, Monday first.
List<String> dailyWeek(String today) {
  final d = DateTime.tryParse(today);
  if (d == null) return const [];
  final monday = -(d.weekday - DateTime.monday);
  return [for (var i = 0; i < 7; i++) dailyShift(today, monday + i)];
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

/// Which of [n] words the daily for [lang] on [date] is.
int dailyIndex(String lang, String date, int n) =>
    dailyHash('lexodle-daily|$lang|$date') % n;

/// Today's (or [date]'s) daily: the date and its answer.
class Daily {
  const Daily(this.date, this.answer);
  final String date;
  final String answer;

  /// The daily of [bank]'s language on [date] (default today), or null when the
  /// language has no words of the daily's length.
  static Daily? of(WordBank bank, [String? date]) {
    final d = date ?? dailyDate();
    final pool = bank.answers(
      dailyLength,
      poolWords(dailyPool, bank.language.counts[dailyLength]),
    );
    if (pool.isEmpty) return null;
    return Daily(d, pool[dailyIndex(bank.language.code, d, pool.length)]);
  }
}
