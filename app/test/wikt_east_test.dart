import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/cs.dart';
import 'package:lexodle/wikt/hu.dart';
import 'package:lexodle/wikt/id.dart';
import 'package:lexodle/wikt/pl.dart';
import 'package:lexodle/wikt/tr.dart';
import 'package:lexodle/wiktionary.dart';

String _read(String code, String w) =>
    File('test/fixtures/$code-wikt-$w.html').readAsStringSync();

WordInfo _pl(String w) => parsePolish(_read('pl', w), 'u')!;
WordInfo _cs(String w) => parseCzech(_read('cs', w), 'u')!;
WordInfo _hu(String w) => parseHungarian(_read('hu', w), 'u')!;
WordInfo _tr(String w) => parseTurkish(_read('tr', w), 'u')!;
WordInfo _id(String w) => parseIndonesian(_read('id', w), 'u')!;

/// A page that has headings of other languages only.
String _other(String h2) =>
    '<div class="mw-parser-output"><div class="mw-heading mw-heading2">$h2</div>'
    '<p>x</p></div>';

void main() {
  group('polish edition', () {
    test(
      'droga: ipa, audio, noun, gender, senses, examples, nyms, etymology',
      () {
        final i = _pl('droga');
        expect(i.ipa, ['[ˈdrɔɡa]']);
        expect(i.audio, startsWith('https://upload.wikimedia.org/'));
        expect(i.audio, endsWith('.mp3'));
        final b = i.blocks.first;
        expect(b.pos, 'rzeczownik');
        expect(b.gender, 'f');
        expect(b.senses.length, 4);
        expect(b.senses.first.text, startsWith('każdy wytyczony'));
        expect(b.senses.first.examples.first.text, startsWith('Na drodze'));
        expect(b.senses.first.examples.length, 2);
        expect(b.senses[3].labels, ['fizyka']);
        expect(i.synonyms, ['marszruta', 'tor']);
        expect(i.antonyms, ['bezdroże']);
        expect(i.etymology, startsWith('prasł. *dorga'));
        expect(i.etymology, isNot(contains('[')));
      },
    );

    test('droga: an inflected form keeps its grammar, not as a label', () {
      final b = _pl('droga').blocks[1];
      expect(b.pos, 'przymiotnik');
      expect(b.forms, 'forma fleksyjna');
      expect(b.senses.first.labels, isEmpty);
      expect(b.senses.first.text, contains('od: drogi'));
    });

    test('droga: the other languages after it are left out', () {
      final i = _pl('droga');
      expect(i.blocks.length, 2);
      for (final b in i.blocks) {
        for (final s in b.senses) {
          expect(s.text, isNot(contains('narkotyk')));
        }
      }
    });

    test('robić: verb, aspect in forms, labels, three blocks', () {
      final i = _pl('robić');
      expect(i.ipa.first, '[ˈrɔbʲit͡ɕ]');
      expect(i.blocks.length, 3);
      final v = i.blocks.first;
      expect(v.pos, 'czasownik');
      expect(v.gender, '');
      expect(v.forms, 'przechodni niedokonany (dk. zrobić)');
      expect(i.blocks[1].senses.first.labels, ['potocznie']);
      expect(i.blocks[1].senses[1].labels, ['eufemistycznie']);
      expect(i.antonyms, ['lenić się']);
      expect(i.synonyms, containsAll(['fabrykować', 'produkować']));
    });

    test('dobry: adjective, noun with gender, interjection', () {
      final i = _pl('dobry');
      expect(i.blocks.first.pos, 'przymiotnik');
      expect(i.blocks.first.senses.first.text, startsWith('miły'));
      expect(i.blocks[1].pos, 'rzeczownik');
      expect(i.blocks[1].gender, 'm');
      expect(i.blocks[2].pos, 'wykrzyknik');
      expect(i.antonyms, contains('zły'));
    });

    test('a page with no polish section gives nothing', () {
      expect(
        parsePolish(
          _other(
            '<h2 id="x_(język_hiszpański)"><span class="lang-code lang-code-es" id="es">język hiszpański</span></h2>',
          ),
          'u',
        ),
        isNull,
      );
    });

    test('sense numbers: ranges and lists', () {
      expect(plSenseKeys('1.1-3'), {'1.1', '1.2', '1.3'});
      expect(plSenseKeys('1.1-2, 2.1'), {'1.1', '1.2', '2.1'});
      expect(plSenseKeys('x'), isEmpty);
    });
  });

  group('czech edition', () {
    test('město: ipa, audio, gender, senses, examples, nyms, etymology', () {
      final i = _cs('město');
      expect(i.ipa, ['[ˈmɲɛstɔ]']);
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      final b = i.blocks.first;
      expect(b.pos, 'podstatné jméno');
      expect(b.gender, 'n');
      expect(b.senses.length, 3);
      expect(b.senses.first.text, startsWith('organizované soustředění'));
      expect(b.senses.first.examples.first.text, 'Město je větší než vesnice.');
      expect(i.synonyms, ['obyvatelstvo', 'centrum']);
      expect(i.antonyms, ['venkov', 'předměstí', 'periferie']);
      expect(i.etymology, startsWith('Z praslovanského *mě̀sto'));
    });

    test('město: the sorbian section after it is left out', () {
      expect(_cs('město').blocks.length, 1);
    });

    test('dělat: verb group in forms, no gender, labels', () {
      final v = _cs('dělat').blocks.first;
      expect(v.pos, 'sloveso');
      expect(v.gender, '');
      expect(v.forms, 'nedokonavé přechodné i nepřechodné');
      expect(v.senses[1].examples.length, 2);
      expect(_cs('dělat').synonyms, containsAll(['činit', 'makat']));
    });

    test('velký: adjective, antonyms', () {
      final i = _cs('velký');
      expect(i.blocks.first.pos, 'přídavné jméno');
      expect(i.antonyms.first, 'malý');
      expect(i.etymology, startsWith('Z praslovanské'));
    });

    test('kniha: feminine', () {
      expect(_cs('kniha').blocks.first.gender, 'f');
    });

    test('a page with no czech section gives nothing', () {
      expect(
        parseCzech(_other('<h2 id="slovenština">slovenština</h2>'), 'u'),
        isNull,
      );
    });
  });

  group('hungarian edition', () {
    test('ember: ipa without the stray space, senses, nyms, etymology', () {
      final i = _hu('ember');
      expect(i.ipa, ['[ˈɛmbɛr]']);
      expect(i.blocks.length, 1);
      expect(i.blocks.first.pos, 'főnév');
      expect(i.blocks.first.senses.map((s) => s.text), [
        'nő és férfi',
        'akárki, valaki',
      ]);
      expect(i.synonyms, containsAll(['egyén', 'személy']));
      expect(i.etymology, startsWith('Elhomályosult összetétel'));
    });

    test('kicsi: forms of the headword line and an inline antonym', () {
      final i = _hu('kicsi');
      expect(i.blocks.first.pos, 'melléknév');
      expect(i.blocks.first.forms, 'középfok kisebb, felsőfok legkisebb');
      expect(i.antonyms, ['nagy']);
    });

    test('város: one long sense, etymology, no source section as a block', () {
      final i = _hu('város');
      expect(i.blocks.length, 1);
      expect(i.blocks.first.senses.first.text, startsWith('A falunál'));
      expect(i.etymology, 'A vár szóból.');
    });

    test('menni: a stub with no sense keeps only the ipa', () {
      final i = _hu('menni');
      expect(i.ipa, ['[ˈmɛnːi]']);
      expect(i.blocks, isEmpty);
    });

    test('a page with no hungarian section gives nothing', () {
      expect(parseHungarian(_other('<h2 id="Angol">Angol</h2>'), 'u'), isNull);
    });
  });

  group('turkish edition', () {
    test('kalem: ipa, audio, forms, label, examples, etymology', () {
      final i = _tr('kalem');
      expect(i.ipa, ['[kaˈlem]']);
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      expect(i.audio, endsWith('.mp3'));
      final b = i.blocks.first;
      expect(b.pos, 'ad');
      expect(b.forms, 'belirtme hâli kalemi, çoğulu kalemler');
      expect(b.senses.first.labels, ['yazma aletleri']);
      expect(b.senses.first.text, startsWith('Yazma, çizme'));
      expect(b.senses.first.examples.first.text, contains('mürekkep'));
      expect(b.senses[2].examples.length, 2);
      expect(i.blocks[1].pos, 'ön ad');
      expect(i.etymology, startsWith('Osmanlı Türkçesi'));
      expect(i.etymology, isNot(contains('‎')));
      expect(i.etymology, isNot(contains('قلم')));
    });

    test('güzel: three parts of speech and the antonym', () {
      final i = _tr('güzel');
      expect(i.blocks.map((b) => b.pos), ['ad', 'belirteç', 'ön ad']);
      expect(i.antonyms, ['çirkin']);
    });

    test('kitap: a synonym written as a note is not an example', () {
      final i = _tr('kitap');
      expect(i.synonyms, ['betik']);
      for (final s in i.blocks.first.senses) {
        for (final e in s.examples) {
          expect(e.text, isNot(startsWith('eş anlamlısı')));
        }
      }
      expect(i.blocks.first.senses[2].labels, ['din']);
    });

    test('kitap: the other turkic languages after it are left out', () {
      expect(_tr('kitap').blocks.length, 1);
    });

    test('a page with no turkish section gives nothing', () {
      expect(
        parseTurkish(_other('<h2 id="Azerice">Azerice</h2>'), 'u'),
        isNull,
      );
    });
  });

  group('indonesian edition', () {
    test('rumah: audio, no ipa, noun, quotation as example', () {
      final i = _id('rumah');
      expect(i.ipa, isEmpty);
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      final b = i.blocks.first;
      expect(b.pos, 'nomina');
      expect(b.senses.first.text, 'tempat atau bangunan untuk hunian');
      expect(b.senses.first.examples.first.text, contains('rumah Dr. Wahidin'));
    });

    test('makan: two parts of speech, label, etymology, no placeholder', () {
      final i = _id('makan');
      expect(i.blocks.map((b) => b.pos), ['verba', 'nomina']);
      expect(
        i.blocks.first.senses.first.text,
        'memasukkan makanan pokok ke dalam mulut serta mengunyah dan menelannya',
      );
      expect(
        i.blocks.first.senses[1].examples.first.text,
        'Ia sedang makan pisang',
      );
      expect(i.blocks[1].senses.first.labels, ['kiasan']);
      expect(i.blocks[1].senses.first.text, 'rezeki');
      expect(i.etymology, startsWith('Diwariskan dari bahasa Melayu'));
    });

    test('besar: synonyms and antonyms', () {
      final i = _id('besar');
      expect(i.blocks.first.pos, 'adjektiva');
      expect(i.synonyms, ['akbar', 'kolosal', 'raksasa', 'dahsyat', 'hebat']);
      expect(i.antonyms.first, 'kecil');
      expect(
        i.blocks.first.senses.first.examples.first.text,
        contains('Batang kayu'),
      );
    });

    test('a page with no indonesian section gives nothing', () {
      expect(
        parseIndonesian(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Bahasa_Banjar">Bahasa Banjar</h2></div></div>',
          'u',
        ),
        isNull,
      );
    });
  });

  test('limits: blocks, senses, nyms and examples can be capped', () {
    final i = parsePolish(
      _read('pl', 'robić'),
      'u',
      maxBlocks: 1,
      maxDefs: 2,
      maxNyms: 3,
    )!;
    expect(i.blocks.length, 1);
    expect(i.blocks.first.senses.length, 2);
    expect(i.synonyms.length, 3);
  });

  test('entries survive a round trip through json', () {
    for (final i in [_pl('robić'), _cs('dělat'), _tr('kalem'), _id('makan')]) {
      expect(WordInfo.fromJson(i.toJson()).toJson(), i.toJson());
    }
  });
}
