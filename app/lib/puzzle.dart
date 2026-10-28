import 'clock.dart';
import 'daily.dart';
import 'modes.dart';

/// A daily puzzle named by a link: the language, the mode and the date. Anyone
/// who opens the link gets the same words as the daily of that day, to play as
/// practice: it never touches the streak, the history or the achievements.
///
/// The link is the web app's address with the puzzle in it:
/// `https://…/lexodle/#/puzzle?l=en&m=quartet&d=2026-10-28`.
class Puzzle {
  const Puzzle(this.lang, this.mode, this.date);
  final String lang;
  final GameMode mode;
  final String date;

  /// The link to share.
  String get link => '$puzzleBase#$puzzlePath?l=$lang&m=${mode.name}&d=$date';

  /// The puzzle a link names, or null when it names none: the language and the
  /// mode are missing or unknown, the date is not a date, or it is a day that has
  /// not come yet (its words would spoil it).
  static Puzzle? parse(Uri uri, {String? today}) {
    final lang = uri.queryParameters['l'];
    final date = uri.queryParameters['d'];
    final mode = GameMode.values.where(
      (m) => m.name == uri.queryParameters['m'],
    );
    if (lang == null || !RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
    if (mode.isEmpty) return null;
    if (date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      return null;
    }
    final d = DateTime.tryParse(date);
    // a date that does not exist (2026-02-31) rolls over: it is not one
    if (d == null || dailyShift(date, 0) != date) return null;
    if (date.compareTo(today ?? dailyDate()) > 0) return null;
    return Puzzle(lang, mode.first, date);
  }
}

/// The address the links start from: the web app.
const puzzleBase = TrustedClock.hostUrl;

/// The route a link opens (see Routes.puzzle).
const puzzlePath = '/puzzle';
