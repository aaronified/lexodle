import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/es.dart';
import 'package:lexodle/wiktionary.dart';

String _fx(String name) => File('test/fixtures/$name.html').readAsStringSync();

void main() {
  group('spanish edition', () {
    WordInfo es(String w) => parseSpanish(_fx('es-wikt-$w'), 'u')!;

    test('niño: ipa, audio, gender, forms, senses, labels, nyms', () {
      final i = es('niño');
      expect(i.ipa.first, '[ˈniɲo]');
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      final b = i.blocks.first;
      expect(b.pos, 'sustantivo');
      expect(b.gender, 'm/f');
      expect(b.forms, contains('plural: niños'));
      expect(b.forms, contains('femenino: niña'));
      expect(b.senses.first.text, startsWith('Ser humano de corta edad'));
      expect(b.senses[1].labels, ['andalucía', 'canarias', 'honduras']);
      expect(b.senses[2].labels, ['por extensión']);
      expect(i.antonyms, containsAll(['adulto', 'viejo']));
      expect(i.synonyms, containsAll(['soltero', 'solterón']));
      expect(i.synonyms, isNot(contains('niño')));
      expect(i.etymology, startsWith('Del castellano antiguo ninno'));
    });

    test('reír: verb blocks, example under the sense, nyms', () {
      final i = es('reír');
      final v = i.blocks.first;
      expect(v.pos, 'verbo intransitivo');
      expect(v.senses.first.text, startsWith('Reírse'));
      expect(v.senses.first.labels, ['literario, se emplea más como pronominal']);
      expect(v.senses.first.examples.first.text, contains('lord Henry'));
      expect(v.senses.first.examples.first.text, isNot(contains('Wilde')));
      expect(v.senses[1].examples.first.text, contains('ríe la vida'));
      expect(i.blocks[1].pos, 'verbo transitivo');
      expect(i.synonyms, contains('carcajear'));
    });

    test('ágil: adjective, antonyms, other language left out', () {
      final i = es('ágil');
      expect(i.blocks.first.pos, 'adjetivo');
      expect(i.blocks.first.gender, '');
      expect(i.blocks.first.forms, contains('plural: ágiles'));
      expect(i.antonyms, containsAll(['lento', 'torpe']));
      expect(i.ipa, ['[ˈaxil]']);
    });

    test('a page with no spanish section gives nothing', () {
      expect(
        parseSpanish(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Gallego"><span id="gl" class="headline-lang"></span>Gallego</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });
}
