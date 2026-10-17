import 'dart:convert';

import 'package:flutter/services.dart';

/// How many of the most frequent words of each length can be the answer.
/// Every word in the file is still accepted as a guess.
const answerPoolSize = 2000;

class Language {
  const Language(this.code, this.name, this.wikt, this.lengths);
  final String code;
  final String name;

  /// The language's heading on en.wiktionary.org, e.g. "Norwegian Bokmål".
  final String wikt;
  final List<int> lengths;
}

class WordBank {
  WordBank._(this.language, this._words, this._weights, this.valid);

  final Language language;
  final Map<int, List<String>> _words;
  final Map<int, List<int>> _weights;
  final Set<String> valid;

  List<String> answers(int length) {
    final w = _words[length] ?? const [];
    return w.length > answerPoolSize ? w.sublist(0, answerPoolSize) : w;
  }

  /// Every word accepted as a guess at [length], most frequent first.
  List<String> guessable(int length) => _words[length] ?? const [];

  List<int> answerWeights(int length) {
    final w = _weights[length] ?? const [];
    return w.length > answerPoolSize ? w.sublist(0, answerPoolSize) : w;
  }

  /// Letters seen in the words of [length], for the on-screen keyboard.
  Set<String> letters(int length) =>
      {for (final w in _words[length] ?? const <String>[]) ...w.split('')};

  static final _cache = <String, WordBank>{};
  static List<Language>? _languages;

  static Future<List<Language>> languages() async {
    if (_languages != null) return _languages!;
    final raw = await rootBundle.loadString('assets/words/languages.json');
    _languages = [
      for (final m in jsonDecode(raw) as List)
        Language(m['code'] as String, m['name'] as String, m['wikt'] as String,
            [for (final n in m['lengths'] as List) n as int]),
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
