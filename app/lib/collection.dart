/// The words a player has won, kept like trophies: every answer of a won game,
/// by language, and the places of won geography games. It holds the words only
/// (an entry is fetched when it is looked at); a word saved to the personal
/// dictionary keeps a copy of its entry besides (see saved_words.dart).
class Collection {
  Collection();

  /// Per language, in the order won (oldest first).
  final _words = <String, Set<String>>{};
  final _places = <String>{};

  /// The languages with a collected word, sorted.
  List<String> get languages => _words.keys.toList()..sort();

  /// The words of [lang], newest first.
  List<String> wordsOf(String lang) =>
      (_words[lang] ?? const <String>{}).toList().reversed.toList();

  /// The places, newest first.
  List<String> get places => _places.toList().reversed.toList();

  int countOf(String lang) => _words[lang]?.length ?? 0;
  int get placeCount => _places.length;
  int get total => _words.values.fold(0, (n, s) => n + s.length) + placeCount;
  bool get isEmpty => total == 0;

  bool contains(String lang, String word) =>
      _words[lang]?.contains(word) ?? false;

  /// Collects [word] of [lang]; true when it is new.
  bool addWord(String lang, String word) {
    if (word.isEmpty) return false;
    return (_words[lang] ??= {}).add(word);
  }

  /// Collects the place [key]; true when it is new.
  bool addPlace(String key) => key.isNotEmpty && _places.add(key);

  Map<String, dynamic> toJson() => {
    'w': {
      for (final e in _words.entries)
        if (e.value.isNotEmpty) e.key: e.value.toList(),
    },
    if (_places.isNotEmpty) 'p': _places.toList(),
  };

  /// The collection in [j]; what is not a word is left out rather than
  /// refusing the whole.
  static Collection fromJson(Object? j) {
    final c = Collection();
    if (j is! Map) return c;
    final w = j['w'];
    if (w is Map) {
      for (final e in w.entries) {
        if (e.key is! String || e.value is! List) continue;
        for (final x in e.value as List) {
          if (x is String) c.addWord(e.key as String, x);
        }
      }
    }
    final p = j['p'];
    if (p is List) {
      for (final x in p) {
        if (x is String) c.addPlace(x);
      }
    }
    return c;
  }
}

/// A collected word (or place) as a route argument: [lang] is empty for a place.
class CollectedRef {
  const CollectedRef(this.lang, this.word);
  final String lang;
  final String word;
}
