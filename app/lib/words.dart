import 'dart:convert';

import 'package:flutter/services.dart';

/// The answer-pool sizes the difficulty matrix offers: how many of the most
/// frequent words of a length the answer can be. Every word in the file is
/// still accepted as a guess.
const poolSizes = [500, 1500, 3000, 6000];
const defaultPool = 3000;

class Language {
  const Language(
    this.code,
    this.name,
    this.wikt,
    this.lengths, [
    this.counts = const {},
    this.flag = '',
  ]);
  final String code;
  final String name;

  /// The language's heading on en.wiktionary.org, e.g. "Norwegian Bokmål".
  final String wikt;
  final List<int> lengths;

  /// How many words the language has at each length.
  final Map<int, int> counts;

  /// A flag emoji, or `svg:<name>` for one drawn in assets/flags.
  final String flag;
}

class WordBank {
  WordBank._(this.language, this._words, this._weights, this.valid);

  final Language language;
  final Map<int, List<String>> _words;
  final Map<int, List<int>> _weights;
  final Set<String> valid;

  /// The words an answer can be at [length]: the [size] most frequent.
  List<String> answers(int length, [int size = defaultPool]) {
    final w = _words[length] ?? const [];
    return w.length > size ? w.sublist(0, size) : w;
  }

  /// Every word accepted as a guess at [length], most frequent first.
  List<String> guessable(int length) => _words[length] ?? const [];

  /// How common each word of [guessable] is, in the same order.
  List<int> guessWeights(int length) => _weights[length] ?? const [];

  final _weightMaps = <int, Map<String, int>>{};

  /// [guessWeights] by word, for the daring of a guess (how likely it was).
  Map<String, int> weightMap(int length) => _weightMaps[length] ??= {
    for (var i = 0; i < guessable(length).length; i++)
      guessable(length)[i]: i < guessWeights(length).length
          ? guessWeights(length)[i]
          : 1,
  };

  List<int> answerWeights(int length, [int size = defaultPool]) {
    final w = _weights[length] ?? const [];
    return w.length > size ? w.sublist(0, size) : w;
  }

  /// Letters seen in the words of [length], for the on-screen keyboard.
  Set<String> letters(int length) => {
    for (final w in _words[length] ?? const <String>[]) ...w.split(''),
  };

  static final _cache = <String, WordBank>{};
  static List<Language>? _languages;

  /// The languages, once they have been loaded (null before).
  static List<Language>? get loadedLanguages => _languages;

  static Future<List<Language>> languages() async {
    if (_languages != null) return _languages!;
    final raw = await rootBundle.loadString('assets/words/languages.json');
    _languages = [
      for (final m in jsonDecode(raw) as List)
        Language(
          m['code'] as String,
          m['name'] as String,
          m['wikt'] as String,
          [for (final n in m['lengths'] as List) n as int],
          {
            for (final e in ((m['counts'] ?? {}) as Map).entries)
              int.parse(e.key as String): e.value as int,
          },
          (m['flag'] ?? '') as String,
        ),
    ];
    return _languages!;
  }

  static Future<WordBank> load(Language lang) async {
    final hit = _cache[lang.code];
    if (hit != null) return hit;
    final raw = await rootBundle.loadString('assets/words/${lang.code}.txt');
    final words = <int, List<String>>{};
    final weights = <int, List<int>>{};
    final valid = <String>{};
    for (final line in const LineSplitter().convert(raw)) {
      final tab = line.indexOf('\t');
      if (tab < 0) continue;
      final w = line.substring(0, tab);
      (words[w.length] ??= []).add(w);
      (weights[w.length] ??= []).add(int.parse(line.substring(tab + 1)));
      valid.add(w);
    }
    return _cache[lang.code] = WordBank._(lang, words, weights, valid);
  }
}
