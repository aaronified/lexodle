import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/ca.dart';
import 'package:lexodle/wikt/es.dart';
import 'package:lexodle/wikt/it.dart';
import 'package:lexodle/wikt/pt.dart';
import 'package:lexodle/wikt/ro.dart';
import 'package:lexodle/wiktionary.dart';

String _fx(String name) => File('test/fixtures/$name.html').readAsStringSync();

/// A page whose language section is followed by another language's section
/// with a part of speech of its own: nothing of it may be read.
const _tail =
    '<div class="mw-heading mw-heading2"><h2 id="Other">Other</h2></div>'
    '<ol><li>leaked</li></ol>';

void main() {
  group('spanish edition', () {
    WordInfo es(String w, {int maxBlocks = 3}) =>
        parseSpanish(_fx('es-wikt-$w'), 'u', maxBlocks: maxBlocks)!;

    test('noche: ipa, audio, gender, forms, senses, etymology', () {
      final i = es('noche', maxBlocks: 10);
      expect(i.ipa.first, '[ˈnot͡ʃe]');
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      expect(i.blocks.length, 1); // castellano antiguo is left out
      final b = i.blocks.first;
      expect(b.pos, 'sustantivo');
      expect(b.gender, 'f');
      expect(b.forms, 'plural: noches');
      expect(b.senses.first.text, startsWith('Tiempo entre dos días'));
      expect(i.etymology, startsWith('Del castellano antiguo noche'));
    });

    test('decir: verb blocks, labels, example, synonyms', () {
      final i = es('decir', maxBlocks: 10);
      expect(i.blocks.map((b) => b.pos), [
        'verbo transitivo',
        'verbo intransitivo',
        'sustantivo',
      ]);
      expect(i.blocks.first.gender, '');
      expect(i.blocks.first.senses.first.labels, [
        'se emplea también como pronominal',
      ]);
      expect(
        i.blocks[1].senses[1].examples.first.text,
        contains('El verde dice mal'),
      );
      expect(i.blocks[2].gender, 'm');
      expect(i.ipa.length, 2);
      expect(i.synonyms, contains('hablar'));
      expect(i.etymology, 'Del latín dicĕre.');
    });

    test('bueno: adjective forms, three blocks, antonyms, regions', () {
      final i = es('bueno');
      expect(i.blocks.map((b) => b.pos), [
        'adjetivo',
        'interjección',
        'sustantivo',
      ]);
      expect(
        i.blocks.first.forms,
        startsWith('plural: buenos · femenino: buena'),
      );
      expect(
        i.blocks.first.senses[1].examples.first.text,
        contains('Wikcionario'),
      );
      expect(i.blocks[2].gender, 'm');
      expect(i.blocks[2].senses[2].labels, ['argentina', 'ecuador', 'uruguay']);
      expect(i.antonyms, containsAll(['malo', 'inútil']));
      expect(i.synonyms, contains('útil'));
      expect(es('bueno', maxBlocks: 2).blocks.length, 2);
    });

    test('nothing of another language is read, no section gives null', () {
      final page = _fx('es-wikt-noche');
      expect(
        parseSpanish(
          page.replaceFirst(
            RegExp(
              r'<div class="mw-heading mw-heading2"><h2 id="Castellano_antiguo".*',
              dotAll: true,
            ),
            _tail,
          ),
          'u',
        )!.blocks.length,
        1,
      );
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
    WordInfo it(String w, {int maxBlocks = 3}) =>
        parseItalian(_fx('it-wikt-$w'), 'u', maxBlocks: maxBlocks)!;

    test('tempo: ipa, gender, forms, labels, examples, nyms, etymology', () {
      final i = it('tempo', maxBlocks: 10);
      expect(i.ipa, ['/ˈtɛmpo/']);
      expect(i.blocks.length, 1); // the english section is left out
      final b = i.blocks.first;
      expect(b.pos, 'sostantivo');
      expect(b.gender, 'm');
      expect(b.forms, contains('tempi'));
      expect(b.senses.first.labels, contains('filosofia'));
      expect(b.senses.first.examples.first.text, contains('col tempo'));
      expect(b.senses[1].examples.length, 2);
      expect(i.synonyms, containsAll(['durata', 'epoca']));
      expect(i.etymology, startsWith('dal latino tĕmpus'));
    });

    test('avere: noun and verb, sub-headings, recording', () {
      final i = it('avere');
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      expect(i.blocks.map((b) => b.pos), ['sostantivo', 'verbo']);
      expect(i.blocks[0].senses[1].labels, ['economia', 'commercio']);
      expect(i.blocks[1].senses.first.text, 'essere in possesso di');
      expect(
        i.blocks[1].senses.first.examples.first.text,
        contains('Metallica'),
      );
      expect(i.antonyms, contains('mancare'));
    });

    test('nuovo: adjective, antonyms', () {
      final i = it('nuovo');
      expect(i.blocks.first.pos, 'aggettivo');
      expect(i.blocks.first.senses.first.text, 'qualcosa mai visto prima');
      expect(i.antonyms, containsAll(['antico', 'vecchio']));
      expect(i.etymology, 'dal latino nŏvus');
    });

    test('no section gives null', () {
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
    WordInfo pt(String w, {int maxBlocks = 3}) =>
        parsePortuguese(_fx('pt-wikt-$w'), 'u', maxBlocks: maxBlocks)!;

    test('noite: gender, plural, labels, examples, nyms, no ipa', () {
      final i = pt('noite');
      expect(i.ipa, isEmpty);
      final b = i.blocks.first;
      expect(b.pos, 'substantivo');
      expect(b.gender, 'f');
      expect(b.forms, 'plural noites');
      expect(b.senses.first.labels, ['cronônimo']);
      expect(
        b.senses[1].examples.first.text,
        startsWith('Até o início da noite'),
      );
      expect(b.senses[3].labels, ['figurado']);
      expect(i.synonyms, ['noute']);
      expect(i.antonyms, ['dia']);
      expect(i.etymology, startsWith('Do latim noctem'));
    });

    test('falar: verb, ipa of two regions, asturian left out', () {
      final i = pt('falar', maxBlocks: 10);
      expect(i.blocks.length, 1);
      expect(i.blocks.first.pos, 'verbo');
      expect(i.blocks.first.senses[1].examples.first.text, 'Você fala alemão?');
      expect(i.ipa, ['/fɐ.ˈlaɾ/', "/fa.'lax/"]);
      expect(i.etymology, 'Do latim fabulari.');
    });

    test('maior: two parts of speech, common gender, latin left out', () {
      final i = pt('maior', maxBlocks: 10);
      expect(i.blocks.map((b) => b.pos), ['adjetivo', 'substantivo']);
      expect(i.blocks.first.gender, 'm/f');
      expect(i.blocks.first.forms, 'plural maiores');
      expect(i.antonyms, ['menor']);
    });

    test('no section gives null', () {
      expect(
        parsePortuguese(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading1"><h1 id="Galego">Galego</h1></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  group('catalan edition', () {
    WordInfo ca(String w, {int maxBlocks = 3}) =>
        parseCatalan(_fx('ca-wikt-$w'), 'u', maxBlocks: maxBlocks)!;

    test('poble: noun and verb form, labels, synonyms, etymology', () {
      final i = ca('poble');
      final b = i.blocks.first;
      expect(b.pos, 'nom');
      expect(b.gender, 'm');
      expect(b.forms, 'plural pobles');
      expect(b.senses[3].labels, ['castellanisme']);
      expect(i.blocks[1].pos, 'verb');
      expect(i.blocks[1].senses.first.labels, ['valencià']);
      expect(i.synonyms, containsAll(['gent', 'massa']));
      expect(i.etymology, startsWith('Del llatí populus'));
    });

    test('veure: transitivity is not a gender, examples', () {
      final i = ca('veure');
      final v = i.blocks.first;
      expect(v.pos, 'verb');
      expect(v.gender, '');
      expect(v.forms, contains('pronominal veure'));
      expect(v.senses.first.text, 'Percebre amb la vista');
      expect(v.senses.first.examples.first.text, startsWith('Al vespre'));
      expect(v.senses[1].examples.first.text.length, lessThanOrEqualTo(201));
    });

    test('major: ipa, five blocks, english left out', () {
      final i = ca('major', maxBlocks: 10);
      expect(i.ipa, ['/məˈʒoɾ/']);
      expect(i.blocks.map((b) => b.pos), [
        'adjectiu',
        'nom',
        'nom',
        'nom',
        'verb',
      ]);
      expect(i.blocks.take(3).map((b) => b.gender), ['', 'm', 'f']);
      expect(i.blocks[0].senses[3].labels, ['nàutica']);
    });

    test('no section gives null, old catalan is not catalan', () {
      expect(
        parseCatalan(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Català_antic">Català antic</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  group('romanian edition', () {
    WordInfo ro(String w, {int maxBlocks = 3}) =>
        parseRomanian(_fx('ro-wikt-$w'), 'u', maxBlocks: maxBlocks)!;

    test('viață: ipa, gender, plural, example, synonyms without numbers', () {
      final i = ro('viață');
      expect(i.ipa, ['/ˈvja.ʦə/']);
      final b = i.blocks.first;
      expect(b.pos, 'substantiv');
      expect(b.gender, 'f');
      expect(b.forms, 'plural vieți');
      expect(b.senses.first.examples.first.text, 'Pe când nu era viață.');
      expect(i.synonyms, containsAll(['ființă', 'existență', 'trai']));
      expect(i.synonyms.any((s) => s.contains(':')), isFalse);
      expect(i.antonyms, ['moarte']);
      expect(i.etymology, startsWith('Din latină'));
    });

    test('vedea: verb, labels, antonyms by use', () {
      final i = ro('vedea');
      final v = i.blocks.first;
      expect(v.pos, 'verb');
      expect(v.senses.first.labels, ['v.tranz și refl. recipr.']);
      expect(v.senses.first.text, startsWith('a (se) percepe'));
      expect(i.antonyms, ['se pierde', 'orbi']);
    });

    test('vechi: adjective forms and a neuter noun', () {
      final i = ro('vechi');
      expect(i.blocks.map((b) => b.pos), ['adjectiv', 'substantiv']);
      expect(i.blocks.first.forms, 'feminin veche, plural vechi');
      expect(i.blocks.first.senses[1].labels, ['despre limbi']);
      expect(i.blocks[1].gender, 'n');
    });

    test('another language after romanian is left out, no section is null', () {
      final page = _fx('ro-wikt-vechi');
      final i = parseRomanian(
        page.replaceFirst(RegExp(r'\n</div>\n$'), '$_tail\n</div>\n'),
        'u',
        maxBlocks: 10,
      )!;
      expect(i.blocks.length, 2);
      expect(
        parseRomanian(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="engleză">engleză</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });
}
