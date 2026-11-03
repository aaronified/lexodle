import 'package:flutter/services.dart';

import 'words.dart';

/// The lengths of the equations mode, in tiles.
const equationLengths = [6, 7, 8];

/// The length of the daily equation, and its tries.
const equationDailyLength = 8;
const equationDailyTries = 6;

/// The keys of the equations keyboard, a number pad, by row (enter and
/// backspace flank the last). The signs are kept as `*`, `/` and `-` (a
/// hardware keyboard has them) and drawn by [faceOf].
const equationRows = ['789/', '456*', '123-', '0+='];

/// What a character is drawn as: the times, divide and minus signs for the
/// ASCII ones; every other character is itself.
String faceOf(String ch) => switch (ch) {
  '*' => '×',
  '/' => '÷',
  '-' => '−',
  _ => ch,
};

/// The character a typed one stands for in an equation: `x` and the drawn
/// signs are the ASCII ones.
String typedEquationChar(String ch) => switch (ch) {
  'x' || '×' => '*',
  '÷' => '/',
  '−' => '-',
  _ => ch,
};

/// The equations of assets/equations (see tools/build_equations.py), as a bank
/// in the language [lang]: every equation is a valid guess and an answer, all
/// as likely as each other.
class Equations {
  const Equations._();

  static final _banks = <String, WordBank>{};

  /// How many equations there are at each length, once the bank is loaded.
  static Map<int, int> counts = const {};

  static Future<WordBank> load(Language lang) async {
    final hit = _banks[lang.code];
    if (hit != null) return hit;
    final words = <int, List<String>>{};
    for (final n in equationLengths) {
      final raw = await rootBundle.loadString('assets/equations/$n.txt');
      words[n] = [
        for (final l in raw.split('\n'))
          if (l.length == n) l,
      ];
    }
    counts = {for (final e in words.entries) e.key: e.value.length};
    return _banks[lang.code] = WordBank.custom(
      lang,
      words,
      {for (final e in words.entries) e.key: List.filled(e.value.length, 1)},
      curveOrigin: WordBank.defaultCurveOrigin,
      curveWidth: WordBank.defaultCurveWidth,
      anyChar: true,
    );
  }
}

/// Why [s] is not an equation of the list, in a few words: the rules a player
/// can read the fault off, or null when it breaks none of them (it is an
/// equation but not one the list has, which is only so for rules the list
/// keeps: a lone 0 is not allowed).
String? equationProblem(String s) {
  final sides = s.split('=');
  if (sides.length != 2) return 'needs exactly one =';
  final (left, right) = (sides[0], sides[1]);
  if (!RegExp(r'^[1-9]\d*$|^0$').hasMatch(right)) {
    return 'the right of = is one number';
  }
  final tokens = RegExp(r'\d+|[-+*/]').allMatches(left).map((m) => m[0]!);
  if (tokens.join() != left || left.isEmpty) return 'check the signs';
  final list = tokens.toList();
  final shape =
      list.length.isOdd &&
      [
        for (final (i, t) in list.indexed)
          i.isEven == RegExp(r'^\d').hasMatch(t),
      ].every((b) => b);
  if (!shape) return 'check the signs';
  if (list.length < 3) return 'needs a sum on the left';
  if (list.any(
    (t) => RegExp(r'^\d').hasMatch(t) && t.length > 1 && t[0] == '0',
  )) {
    return 'no number starts with 0';
  }
  final v = _value(list);
  if (v == null) return 'no dividing by 0';
  if (v.$1 != int.parse(right) * v.$2) return 'both sides must be equal';
  if (list.contains('0') || right == '0') return 'a lone 0 is not allowed';
  return null;
}

/// A sum as an exact fraction (numerator, denominator), read with the order of
/// operations; null for a division by 0.
(int, int)? _value(List<String> t) {
  (int, int) norm(int n, int d) {
    final g = n.abs().gcd(d);
    return g == 0 ? (n, d) : (n ~/ g, d ~/ g);
  }

  final terms = <(int, int)>[(int.parse(t[0]), 1)];
  final signs = <String>[];
  for (var i = 1; i < t.length; i += 2) {
    final n = int.parse(t[i + 1]);
    final (a, b) = terms.last;
    switch (t[i]) {
      case '*':
        terms[terms.length - 1] = norm(a * n, b);
      case '/':
        if (n == 0) return null;
        terms[terms.length - 1] = norm(a, b * n);
      default:
        signs.add(t[i]);
        terms.add((n, 1));
    }
  }
  var (a, b) = terms.first;
  for (var i = 0; i < signs.length; i++) {
    final (c, d) = terms[i + 1];
    a = signs[i] == '+' ? a * d + c * b : a * d - c * b;
    b *= d;
    (a, b) = norm(a, b);
  }
  return (a, b);
}
