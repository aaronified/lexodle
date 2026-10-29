import 'dart:convert';
import 'dart:math' show exp, max;

import 'package:flutter/services.dart';

import 'modes.dart' show Draw;

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

  /// The words an answer can be at [length]: every word of that length, most
  /// frequent first. How likely each is to be drawn is [answerWeights].
  List<String> answers(int length) => _words[length] ?? const [];

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

  /// How likely each word of [answers] is to be drawn as the answer: by how
  /// common it is when [frequency] is on, and equally likely when it is off.
  List<int> answerWeights(int length, {bool frequency = true}) {
    final n = answers(length).length;
    if (!frequency) return List.filled(n, 1);
    final w = _weights[length] ?? const [];
    return w.length >= n
        ? w.sublist(0, n)
        : [...w, ...List.filled(n - w.length, 1)];
  }

  final _curves = <int, List<int>>{};
  final _curveMaps = <int, Map<String, int>>{};

  /// Where the sigmoid curve is at half: the 3,000th word, whatever the size
  /// of the list (a short list most likely means an incomplete one). It falls
  /// from about full to about nothing over 1,000 words around that: [curveWidth]
  /// is the logistic scale, so the 2,500th word is at 98% and the 3,500th at 2%.
  static const curveOrigin = 3000.0;
  static const curveWidth = 125.0;

  /// The chance of each word of [answers], as a whole number up to 1,000, by a
  /// sigmoid curve on its rank by frequency: the commonest words almost equally
  /// likely, half at the origin ([curveOrigin]) and almost none
  /// 500 words past it. Whole numbers, so that every device draws the same word.
  List<int> curveWeights(int length) => _curves[length] ??= () {
    final n = answers(length).length;
    return [
      for (var i = 0; i < n; i++)
        max(1, (1000 / (1 + exp((i + 1 - curveOrigin) / curveWidth))).round()),
    ];
  }();

  /// How likely each word of [answers] is to be drawn under [draw].
  List<int> drawWeights(int length, Draw draw) => switch (draw) {
    Draw.sigmoid => curveWeights(length),
    Draw.equal => List.filled(answers(length).length, 1),
    Draw.frequency => answerWeights(length),
  };

  /// [drawWeights] by word, as the scores weigh the words still possible; null
  /// when every word is as likely as the next.
  Map<String, int>? law(int length, Draw draw) => switch (draw) {
    Draw.equal => null,
    Draw.frequency => weightMap(length),
    Draw.sigmoid => _curveMaps[length] ??= {
      for (var i = 0; i < answers(length).length; i++)
        answers(length)[i]: curveWeights(length)[i],
    },
  };

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
