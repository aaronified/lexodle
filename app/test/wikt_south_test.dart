import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/es.dart';
import 'package:lexodle/wikt/it.dart';
import 'package:lexodle/wikt/pt.dart';
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
      expect(v.senses.first.labels, ['literario', 'se emplea más como pronominal']);
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

  group('italian edition', () {
    WordInfo it(String w) => parseItalian(_fx('it-wikt-$w'), 'u')!;

    test('metà: ipa, gender, senses, examples, labels, nyms', () {
      final i = it('metà');
      expect(i.ipa, ['/meˈta/']);
      expect(i.audio, isNull);
      final b = i.blocks.first;
      expect(b.pos, 'sostantivo');
      expect(b.gender, 'f');
      expect(b.forms, 'inv');
      expect(b.senses.first.text, startsWith('due parti anche non perfette'));
      expect(b.senses.first.examples.first.text, 'La metà di dieci è cinque');
      expect(b.senses[2].labels, ['senso figurato']);
      expect(b.senses[2].text, startsWith('sinonimo di marito'));
      expect(i.synonyms, containsAll(['mezzo', 'mezza parte']));
      expect(i.antonyms, ['intero', 'tutto']);
      expect(i.etymology, startsWith('dal latino medietas'));
    });

    test('finì: verb form, the other languages are left out', () {
      final i = it('finì');
      expect(i.blocks.length, 1);
      expect(i.blocks.first.pos, 'voce verbale');
      expect(
        i.blocks.first.senses.first.text,
        startsWith('terza persona singolare'),
      );
      expect(i.etymology, 'vedi finire');
    });

    test('indù: adjective for both genders, a label', () {
      final i = it('indù');
      final b = i.blocks.first;
      expect(b.pos, 'aggettivo');
      expect(b.gender, 'm/f');
      expect(b.senses.first.labels, ['religione']);
      expect(b.senses.first.text, startsWith('che riguarda le religioni'));
      expect(i.etymology, 'Dal persiano hindu');
    });

    test('a page with no italian section gives nothing', () {
      expect(
        parseItalian(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Lombardo">Lombardo</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  group('portuguese edition', () {
    WordInfo pt(String w) => parsePortuguese(_fx('pt-wikt-$w'), 'u')!;

    test('irmã: gender, plural of the feminine row, senses, synonym', () {
      final i = pt('irmã');
      expect(i.ipa, ['/iɾ.ˈmɐ̃/']);
      final b = i.blocks.first;
      expect(b.pos, 'substantivo');
      expect(b.gender, 'f');
      expect(b.forms, 'plural irmãs');
      expect(b.senses.length, 3);
      expect(b.senses.first.text, startsWith('aquela que em relação a outrem'));
      expect(i.synonyms, ['irmã bilateral']);
      expect(i.etymology, startsWith('Do latim germana'));
    });

    test('faça: verb form, galician and medieval sections left out', () {
      final i = pt('faça');
      expect(i.blocks.length, 1);
      expect(i.blocks.first.pos, 'forma verbal');
      expect(i.blocks.first.senses.length, 3);
      expect(
        i.blocks.first.senses.first.text,
        startsWith('primeira pessoa do singular'),
      );
      expect(i.etymology, '');
      expect(i.synonyms, isEmpty);
    });

    test('útil: two parts of speech, examples, pronunciations', () {
      final i = pt('útil');
      expect(i.blocks.map((b) => b.pos), ['adjetivo', 'substantivo']);
      final a = i.blocks.first;
      expect(a.gender, 'm/f');
      expect(a.forms, 'plural úteis');
      expect(a.senses.first.text, 'que pode ter ou tem algum uso ou é necessário');
      expect(a.senses.first.examples.first.text, contains('coisas úteis'));
      expect(i.blocks[1].gender, 'm');
      expect(i.ipa.length, 3);
      expect(i.ipa.last, '/ˈu.tiɫ/');
      expect(i.etymology, startsWith('Do latim utilis'));
    });

    test('a page with no portuguese section gives nothing', () {
      expect(
        parsePortuguese(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading1"><h1 id="Galego">Galego</h1></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });
}
