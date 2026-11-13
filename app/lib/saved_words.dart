import 'wiktionary.dart';
import 'app_log.dart';

/// A word the player saved from the end of a game: the language, the word, the
/// day it was saved, the player's own note and a copy of its Wiktionary entry as
/// it was then, so that it opens without a connection. [info] is null when the
/// entry could not be had at the time (the word is kept all the same).
class SavedWord {
  SavedWord({
    required this.lang,
    required this.word,
    required this.date,
    this.note = '',
    this.info,
  });

  final String lang;
  final String word;

  /// The local day it was saved, as 2026-11-12.
  final String date;
  String note;
  WordInfo? info;

  /// What identifies it: the same word in two languages is two saved words.
  String get key => '$lang|$word';

  /// The first meaning, for the list; empty when there is no entry.
  String get firstMeaning {
    for (final b in info?.blocks ?? const <PosBlock>[]) {
      if (b.senses.isNotEmpty) return b.senses.first.text;
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
    'l': lang,
    'w': word,
    'd': date,
    if (note.isNotEmpty) 'n': note,
    if (info != null) 'i': info!.toJson(),
  };

  /// The word in [j], or null when it is not one (a damaged entry is left out
  /// rather than refusing the whole list).
  static SavedWord? fromJson(Object? j) {
    if (j is! Map) return null;
    final l = j['l'], w = j['w'], d = j['d'];
    if (l is! String || w is! String || d is! String || w.isEmpty) return null;
    WordInfo? info;
    final i = j['i'];
    if (i is Map) {
      try {
        info = WordInfo.fromJson(i.cast<String, dynamic>());
      } catch (e) {
        appLog.w(
          'saved',
          'a saved word\'s info could not be read: ${e.runtimeType}',
        );
      }
    }
    return SavedWord(
      lang: l,
      word: w,
      date: d,
      note: j['n'] is String ? j['n'] as String : '',
      info: info,
    );
  }
}

/// The player's personal dictionary, newest first.
class SavedWords {
  SavedWords([Iterable<SavedWord> words = const []]) {
    for (final w in words) {
      if (!contains(w.lang, w.word)) _words.add(w);
    }
  }

  final _words = <SavedWord>[];

  List<SavedWord> get words => List.unmodifiable(_words);
  int get length => _words.length;
  bool get isEmpty => _words.isEmpty;

  /// How many saved words have a note.
  int get notedCount => _words.where((w) => w.note.trim().isNotEmpty).length;

  bool contains(String lang, String word) =>
      _words.any((w) => w.lang == lang && w.word == word);

  SavedWord? find(String lang, String word) {
    for (final w in _words) {
      if (w.lang == lang && w.word == word) return w;
    }
    return null;
  }

  /// Saves [word] at the front. A word already saved is left as it is.
  void add(SavedWord word) {
    if (contains(word.lang, word.word)) return;
    _words.insert(0, word);
  }

  /// Removes the word; true when there was one.
  bool remove(String lang, String word) {
    final before = _words.length;
    _words.removeWhere((w) => w.lang == lang && w.word == word);
    return _words.length != before;
  }

  /// Sets the note of a saved word; true when there was such a word.
  bool setNote(String lang, String word, String note) {
    final w = find(lang, word);
    if (w == null) return false;
    w.note = note;
    return true;
  }

  List<dynamic> toJson() => [for (final w in _words) w.toJson()];

  static SavedWords fromJson(Object? j) => SavedWords([
    if (j is List)
      for (final e in j) ?SavedWord.fromJson(e),
  ]);
}
