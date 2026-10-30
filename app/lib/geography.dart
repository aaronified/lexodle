import 'package:flutter/services.dart';

import 'words.dart';

/// A place of the themed wordle: its name as letters, as shown, what it is,
/// where, and its page on Wikipedia (empty when it has none).
class Place {
  const Place(this.key, this.name, this.kind, this.country, this.wiki);
  final String key;
  final String name;
  final String kind;
  final String country;
  final String wiki;

  /// Where the info dot sends the player.
  Uri get link => Uri.parse(
    wiki.isEmpty
        ? 'https://en.wikipedia.org/w/index.php?search=${Uri.encodeQueryComponent(name)}'
        : 'https://en.wikipedia.org/wiki/$wiki',
  );
}

/// The place names of assets/geography/places.tsv (see tools/build_geography.py):
/// key, name, kind, country, tier, Wikipedia page, English Wikipedia views.
/// Every name is a valid guess; the answer is drawn by how often the page is
/// read, on a sigmoid curve that is about even for the best known 1,200 and
/// nothing past 2,000 (the dailies' formula, on a smaller list).
class Geography {
  const Geography._();

  static const curveOrigin = 1500.0;
  static const curveWidth = 100.0;

  static final _places = <String, Place>{};
  static WordBank? _bank;

  /// How many places there are at each length, once the bank is loaded.
  static Map<int, int> counts = const {};

  /// The place a word is, once the bank is loaded.
  static Place? placeOf(String key) => _places[key];

  /// The places as a bank in the language [lang] (English), most read first.
  static Future<WordBank> load(Language lang) async {
    final hit = _bank;
    if (hit != null) return hit;
    final raw = await rootBundle.loadString('assets/geography/places.tsv');
    final rows = <int, List<(Place, int)>>{};
    for (final line in raw.split('\n')) {
      final f = line.split('\t');
      if (f.length < 6) continue;
      final place = Place(f[0], f[1], f[2], f[3], f[5]);
      _places[place.key] = place;
      final views = f.length > 6 ? int.tryParse(f[6]) ?? 0 : 0;
      (rows[place.key.length] ??= []).add((place, views));
    }
    final words = <int, List<String>>{};
    final weights = <int, List<int>>{};
    for (final e in rows.entries) {
      e.value.sort((a, b) {
        final v = b.$2.compareTo(a.$2);
        return v != 0 ? v : a.$1.key.compareTo(b.$1.key);
      });
      words[e.key] = [for (final r in e.value) r.$1.key];
      weights[e.key] = [for (final r in e.value) r.$2 < 1 ? 1 : r.$2];
    }
    counts = {for (final e in words.entries) e.key: e.value.length};
    return _bank = WordBank.custom(
      lang,
      words,
      weights,
      curveOrigin: curveOrigin,
      curveWidth: curveWidth,
    );
  }
}
