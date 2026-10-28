import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No list holds a swear word (tools/swears.py), and the ordinary words a
/// swear list would also catch stay.
void main() {
  Set<String> words(String code) => {
    for (final l in File('assets/words/$code.txt').readAsLinesSync())
      if (l.isNotEmpty) l.split('\t').first,
  };

  test('the swear words are out, in several languages', () {
    const bad = {
      'en': ['shit', 'fuck', 'bitch', 'cunt', 'nigger'],
      'es': ['puta', 'culo', 'mierda'],
      'fr': ['pute', 'merde', 'salope'],
      'de': ['fotze', 'arsch', 'hure'],
      'it': ['cazzo', 'merda', 'troia'],
      'pt': ['puta', 'merda', 'caralho'],
      'tr': ['siktir', 'orospu'],
      'pl': ['kurwa', 'chuj'],
    };
    for (final e in bad.entries) {
      final list = words(e.key);
      for (final w in e.value) {
        expect(list, isNot(contains(w)), reason: '$w in ${e.key}');
      }
    }
  });

  test('ordinary words a swear list catches stay', () {
    expect(words('en'), containsAll(['sexy', 'butt', 'nude']));
    expect(words('es'), contains('sexo'));
    expect(words('pt'), contains('comer'));
    expect(words('sv'), contains('hård'));
  });
}
