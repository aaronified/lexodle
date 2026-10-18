import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wiktionary.dart';

WordInfo parse(String f) =>
    parseSection(File('test/fixtures/$f.html').readAsStringSync(), 'u');

void main() {
  test('french: ipa, audio and definitions', () {
    final i = parse('fr-maison');
    expect(i.ipa.first, '/mɛ.zɔ̃/');
    expect(i.audio, startsWith('https://upload.wikimedia.org/'));
    expect(i.blocks.first.pos, 'noun');
    expect(i.blocks.first.definitions.first, 'house');
  });

  test('french: gender, labels, examples with translations', () {
    final blocks = parse('fr-maison').blocks;
    final b = blocks.first;
    expect(b.gender, 'f');
    expect(b.forms, contains('plural'));
    expect(b.forms, isNot(contains('maison ')));
    final senses = [for (final x in blocks) ...x.senses];
    final withExamples = senses.where((s) => s.examples.isNotEmpty);
    expect(withExamples, isNotEmpty);
    final e = withExamples.expand((s) => s.examples).first;
    expect(e.text, isNotEmpty);
    expect(e.translation, isNotEmpty);
    expect(
      senses.any((s) => s.labels.isNotEmpty),
      isTrue,
      reason: 'sense labels are kept apart from the gloss',
    );
    for (final s in senses) {
      for (final l in s.labels) {
        expect(s.text, isNot(contains(l)));
      }
    }
  });

  test('english: definitions plus synonyms from headings and inline spans', () {
    final i = parse('en-about');
    expect(i.blocks.map((b) => b.pos), containsAll(['preposition', 'adverb']));
    expect(i.synonyms, contains('apropos'));
    expect(i.synonyms.any((s) => s.startsWith('Thesaurus')), isFalse);
    // no nested example text leaks into a gloss
    for (final b in i.blocks) {
      for (final d in b.definitions) {
        expect(d, isNot(contains('\n')));
      }
    }
  });

  test('german: inline synonyms', () {
    final i = parse('de-Haus');
    expect(i.blocks, isNotEmpty);
    expect(i.synonyms, contains('Zuhause'));
  });

  test('norwegian: pos headings nested under etymology sections', () {
    final i = parse('nb-hus');
    expect(i.blocks.map((b) => b.pos), contains('noun'));
  });

  test('title candidates', () {
    expect(titleCandidates('haus', 'de'), ['Haus', 'haus']);
    expect(titleCandidates('maison', 'fr'), ['maison', 'Maison']);
    expect(titleCandidates('iyi', 'tr'), ['iyi', 'İyi']);
    expect(titleCandidates('ıssız', 'tr'), ['ıssız', 'Issız']);
  });
}
