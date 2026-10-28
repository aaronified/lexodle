import 'clock.dart';
import 'daily.dart';
import 'modes.dart';
import 'words.dart';

/// A puzzle named by a link: the language, the mode, the length, the tries and
/// the words themselves, hashed. (The daily is not shared this way: everyone
/// has the same one in the app.) Anyone who opens the link plays it as practice: it never touches the streak, the history or the
/// achievements. A link can also carry the guesses of whoever shares it, in
/// plain, which the page opens already played.
///
/// The link is the web app's address with the puzzle in it:
/// `https://…/lexodle/#/puzzle?l=en&m=classic&n=5&t=6&w=<hash>&g=crane.slate`.
class Puzzle {
  const Puzzle(
    this.lang,
    this.mode, {
    required this.length,
    required this.tries,
    required this.hashes,
    this.guesses = const [],
  });

  /// A puzzle of these [answers] (one for classic, four for the others), with
  /// the guesses made so far when they are shared too. The words go in the link
  /// only as hashes.
  Puzzle.hashed(
    this.lang,
    this.mode, {
    required this.length,
    required this.tries,
    required List<String> answers,
    this.guesses = const [],
  }) : hashes = [for (final a in answers) wordHash(a)];

  final String lang;
  final GameMode mode;

  final int length;
  final int tries;
  final List<String> hashes;
  final List<String> guesses;

  /// The link to share.
  String get link {
    final q = 'l=$lang&m=${mode.name}&n=$length&t=$tries&w=${hashes.join('.')}';
    return '$puzzleBase#$puzzlePath?$q'
        '${guesses.isEmpty ? '' : '&g=${guesses.join('.')}'}';
  }

  /// The puzzle a link names, or null when it names none: the language and the
  /// mode are missing or unknown, or the words, the length, the tries or the
  /// guesses are not what a puzzle has.
  static Puzzle? parse(Uri uri) {
    final q = uri.queryParameters;
    final lang = q['l'];
    final mode = GameMode.values.where((m) => m.name == q['m']);
    if (lang == null || !RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
    if (mode.isEmpty) return null;
    final m = mode.first;

    // the guesses the link carries, if any
    List<String> guesses = const [];
    final g = q['g'];
    if (g != null && g.isNotEmpty) {
      guesses = g.split('.');
    }

    final n = int.tryParse(q['n'] ?? ''), t = int.tryParse(q['t'] ?? '');
    final w = (q['w'] ?? '').split('.');
    if (n == null || n < 4 || n > 8 || t == null || t < 1 || t > 20) {
      return null;
    }
    if (w.length != m.boards ||
        w.any((h) => !RegExp(r'^[0-9a-f]{16}$').hasMatch(h))) {
      return null;
    }
    if (!_guessesOk(guesses, n, t)) return null;
    return Puzzle(lang, m, length: n, tries: t, hashes: w, guesses: guesses);
  }

  static bool _guessesOk(List<String> guesses, int length, int tries) =>
      guesses.length <= tries &&
      guesses.every(
        (x) =>
            x.length == length &&
            RegExp(r'^\p{L}+$', unicode: true).hasMatch(x),
      );

  /// The words of the puzzle in [bank]: the ones whose hashes the link carries,
  /// found among the words of the length (null when one is not there: a link
  /// from a newer word list, or a damaged one).
  List<String>? answersIn(WordBank bank) {
    final byHash = {for (final w in bank.answers(length)) wordHash(w): w};
    final out = <String>[];
    for (final h in hashes) {
      final w = byHash[h];
      if (w == null) return null;
      out.add(w);
    }
    return out;
  }
}

/// A word as 16 hex digits, for a link that must not give the word away at a
/// glance: two integer hashes (the same on every platform, see [dailyHash]) of
/// the word. It hides the word from a reader, not from someone who hashes the
/// word list; the app finds the word by hashing the words of the length.
String wordHash(String word) {
  String hex(int n) => n.toRadixString(16).padLeft(8, '0');
  return hex(dailyHash('lexodle-word-1|$word')) +
      hex(dailyHash('lexodle-word-2|$word'));
}

/// The address the links start from: the web app.
const puzzleBase = TrustedClock.hostUrl;

/// The route a link opens (see Routes.puzzle).
const puzzlePath = '/puzzle';
