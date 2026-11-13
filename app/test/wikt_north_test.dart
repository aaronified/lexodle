import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/de.dart';
import 'package:lexodle/wikt/nl.dart';
import 'package:lexodle/wikt/sv.dart';
import 'package:lexodle/wiktionary.dart';

String fixture(String name) => File('test/fixtures/$name.html').readAsStringSync();

/// Everything a parsed entry shows, for checks that something is left out.
String everything(WordInfo i) => i.toJson().toString();

void main() {
  group('german edition', () {
    WordInfo de(String w) => parseGerman(fixture('de-wikt-$w'), 'u')!;

    test('Stadt: ipa, audio, noun gender, plural, numbered senses', () {
      final i = de('Stadt');
      expect(i.ipa.first, '[ʃtat]');
      expect(i.audio, endsWith('/De-Stadt.ogg/De-Stadt.ogg.mp3'));
      final b = i.blocks.first;
      expect(b.pos, 'substantiv');
      expect(b.gender, 'f');
      expect(b.forms, 'plural Städte');
      expect(b.senses.first.text, startsWith('meist größere'));
      expect(b.senses.first.examples.first.text, contains('Städte'));
      expect(b.senses[2].labels, ['umgangssprachlich']);
      expect(b.senses[2].text, startsWith('Verwaltung'));
      expect(b.senses[2].text, isNot(contains('[3]')));
      expect(i.etymology, startsWith('mittelhochdeutsch stat,'));
      expect(i.etymology, isNot(contains('gmh')));
      expect(i.synonyms, containsAll(['Stadtverwaltung', 'City']));
      expect(i.antonyms, containsAll(['Dorf', 'Land']));
    });

    test('leben: verb forms, label, examples follow their sense number', () {
      final i = de('leben');
      final v = i.blocks.first;
      expect(v.pos, 'verb');
      expect(v.gender, '');
      expect(v.forms, 'präteritum lebte, partizip ii gelebt');
      expect(v.senses.first.labels, ['biologie']);
      expect(v.senses[1].examples.first.text, 'Er lebt bescheiden.');
      expect(i.ipa.length, 2);
      expect(i.antonyms, ['sterben', 'umziehen']);
    });

    test('böse: adjective comparison; related words stand in for synonyms', () {
      final i = de('böse');
      expect(i.blocks.first.pos, 'adjektiv');
      expect(i.blocks.first.forms, 'komparativ böser, superlativ am bösesten');
      expect(i.synonyms, contains('bösartig'));
      expect(i.synonyms.length, lessThanOrEqualTo(8));
      expect(i.antonyms, contains('gut'));
    });

    test('the section stops at the next language heading', () {
      for (final w in ['Stadt', 'leben', 'böse']) {
        expect(everything(de(w)), isNot(contains('english section')));
      }
    });

    test('a page with no german section gives nothing', () {
      expect(
        parseGerman(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="x_(Englisch)">x (<span id="Englisch"></span>)</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  group('dutch edition', () {
    WordInfo nl(String w) => parseDutch(fixture('nl-wikt-$w'), 'u')!;

    test('water: ipa, audio, gender, plural, labels, examples', () {
      final i = nl('water');
      expect(i.ipa.first, '/ˈwatər/');
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      expect(i.audio, endsWith('.mp3'));
      final b = i.blocks.first;
      expect(b.pos, 'zelfstandig naamwoord');
      expect(b.gender, 'n');
      expect(b.forms, 'meervoud waters, wateren');
      expect(b.senses.first.examples.first.text, contains('water'));
      expect(b.senses[1].labels, ['drinken']);
      expect(b.senses[1].text, 'gebruikt als drank');
      expect(i.blocks[1].pos, 'werkwoord');
      expect(i.synonyms, containsAll(['regen', 'gemeentepils']));
      expect(i.etymology, contains('erfwoord'));
      expect(i.etymology, isNot(contains('[')));
    });

    test('maken: verb forms and the styled label', () {
      final i = nl('maken');
      final v = i.blocks.first;
      expect(v.forms, 'verleden tijd maakte, voltooid deelwoord gemaakt');
      expect(v.senses.first.labels, ['overgankelijk']);
      expect(i.synonyms, contains('construeren'));
    });

    test('groot: adjective comparison, antonyms, sense numbers dropped', () {
      final i = nl('groot');
      expect(i.blocks.first.forms, 'vergrotend groter, overtreffend grootst');
      expect(i.synonyms.first, 'groots');
      expect(i.antonyms, containsAll(['klein', 'nietig']));
      expect(i.blocks.last.gender, 'm');
    });

    test('the section stops at the next language heading', () {
      for (final w in ['water', 'maken', 'groot']) {
        expect(everything(nl(w)), isNot(contains('geurloze')));
      }
    });

    test('a page with no dutch section gives nothing', () {
      expect(
        parseDutch(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Engels">Engels</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  group('swedish edition', () {
    WordInfo sv(String w) => parseSwedish(fixture('sv-wikt-$w'), 'u')!;

    test('plats: gender, plural, senses, examples, synonym, etymology', () {
      final i = sv('plats');
      final b = i.blocks.first;
      expect(b.pos, 'substantiv');
      expect(b.gender, 'u');
      expect(b.forms, 'plural platser');
      expect(b.senses.first.text, 'avgränsat område; även mer abstrakt');
      expect(b.senses.first.examples.first.text, contains('plats'));
      expect(b.senses[2].labels, ['spelbar']);
      expect(i.synonyms, ['stad']);
      expect(i.etymology, startsWith('Av medellågtyska'));
      expect(i.etymology, isNot(contains('Etymologi:')));
    });

    test('hitta: ipa, verb forms, old quotes left out', () {
      final i = sv('hitta');
      expect(i.ipa, ['[ˈhɪtˌa]']);
      expect(i.blocks.first.forms, 'preteritum hittade, supinum hittat');
      expect(i.blocks.first.senses.first.labels, ['kunna']);
      expect(i.blocks.first.senses.first.examples.length, 2);
      expect(everything(i), isNot(contains('fynd')));
      expect(i.synonyms, ['finna']);
    });

    test('liten: recording, adjective forms, antonym, etymology section', () {
      final i = sv('liten');
      expect(i.audio, endsWith('/Sv-liten.ogg/Sv-liten.ogg.mp3'));
      expect(i.ipa.first, '[ˈliːˌtɛn]');
      expect(i.blocks.first.forms, 'neutrum litet, komparativ mindre');
      expect(i.blocks.first.senses[1].labels, ['musik']);
      expect(i.antonyms, ['stor']);
      expect(i.etymology, startsWith('Belagt i språket'));
      expect(i.etymology, isNot(contains('[1]')));
    });

    test('the section stops at the next language heading', () {
      expect(everything(sv('hitta')), isNot(contains('träffa , möta')));
      expect(everything(sv('plats')), isNot(contains('böjningsform av plat')));
      expect(everything(sv('plats')), isNot(contains('bred')));
    });

    test('a page with no swedish section gives nothing', () {
      expect(
        parseSwedish(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Franska">Franska</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });
}
