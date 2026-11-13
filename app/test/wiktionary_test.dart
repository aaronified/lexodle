import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('french edition', () {
    WordInfo fr(String w) => parseFrench(
      File('test/fixtures/fr-wikt-$w.html').readAsStringSync(),
      'u',
    )!;

    test('cloche: ipa, audio, pos, gender, forms, sense, example, labels', () {
      final i = fr('cloche');
      expect(i.ipa.first, r'\klɔʃ\');
      expect(i.audio, startsWith('https://upload.wikimedia.org/'));
      final b = i.blocks.first;
      expect(b.pos, 'nom commun');
      expect(b.gender, 'f');
      expect(b.forms, 'pluriel cloches');
      expect(b.senses.first.text, startsWith('Instrument fait de métal'));
      expect(b.senses.first.examples.first.text, contains('cloches'));
      expect(b.senses[1].labels, ['par analogie']);
      expect(b.senses[2].labels, ['cuisine']);
      expect(b.senses[2].text, isNot(contains('(Cuisine)')));
      expect(i.blocks.length, 3);
      expect(i.blocks.last.gender, 'm');
      expect(i.etymology, startsWith('Du moyen français cloche'));
      expect(i.etymology, isNot(contains('Nom commun 1')));
    });

    test('mot: synonyms and antonyms, other languages left out', () {
      final i = fr('mot');
      expect(i.blocks.first.gender, 'm');
      expect(i.synonyms, containsAll(['écrit', 'parole']));
      expect(i.antonyms, ['borborygme']);
    });

    test('manger: verb group, no gender, intransitive label', () {
      final i = fr('manger');
      final v = i.blocks.first;
      expect(v.pos, 'verbe');
      expect(v.gender, '');
      expect(v.forms, '1er groupe');
      expect(v.senses[1].labels, contains('intransitif'));
      expect(i.antonyms, contains('jeûner'));
      expect(i.etymology, isNot(contains('référence nécessaire')));
    });

    test('a page with no french section gives nothing', () {
      expect(
        parseFrench(
          '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Anglais"><span class="sectionlangue" id="en">Anglais</span></h2></div></div>',
          'u',
        ),
        isNull,
      );
    });

    test('link labels follow the edition', () {
      expect(
        linkLabelFor('https://fr.wiktionary.org/wiki/mot#fr'),
        'wiktionnaire ↗',
      );
      expect(
        linkLabelFor('https://en.wiktionary.org/wiki/mot#French'),
        'wiktionary ↗',
      );
      expect(editionOf('fr').host, 'fr.wiktionary.org');
      expect(editionOf('de').host, 'de.wiktionary.org');
      expect(editionOf('nb').host, 'no.wiktionary.org');
      // a language with no edition of its own keeps the English one
      expect(editionOf('xx').host, 'en.wiktionary.org');
      expect(editionOf('en').host, 'en.wiktionary.org');
    });

    test('en goes to en.wiktionary.org, fr to fr.wiktionary.org', () async {
      Wiktionary.reset();
      final hosts = <String>[];
      final frHtml = File('test/fixtures/fr-wikt-mot.html').readAsStringSync();
      final enHtml = File('test/fixtures/en-about.html').readAsStringSync();
      final w = Wiktionary(
        client: MockClient((req) async {
          hosts.add(req.url.host);
          if (req.url.host == 'fr.wiktionary.org') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'parse': {'text': frHtml},
                }),
              ),
              200,
            );
          }
          if (req.url.queryParameters['prop'] == 'sections') {
            return http.Response(
              jsonEncode({
                'parse': {
                  'sections': [
                    {'line': 'English', 'toclevel': 1, 'index': '1'},
                  ],
                },
              }),
              200,
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'parse': {'text': enHtml},
              }),
            ),
            200,
          );
        }),
      );
      final f = await w.lookup('mot', 'fr', 'French');
      final e = await w.lookup('mot', 'en', 'English');
      expect(f!.url, 'https://fr.wiktionary.org/wiki/mot#fr');
      expect(f.blocks.first.pos, 'nom commun');
      expect(e!.url, startsWith('https://en.wiktionary.org/wiki/mot'));
      expect(e.blocks.first.pos, isNot('nom commun'));
      expect(hosts.where((h) => h == 'fr.wiktionary.org'), isNotEmpty);
      expect(hosts.where((h) => h == 'en.wiktionary.org'), isNotEmpty);
      Wiktionary.reset();
    });
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

  group('lookups while the game is played', () {
    final html = File('test/fixtures/fr-maison.html').readAsStringSync();

    /// A fake Wiktionary: every page has a French section; counts requests and
    /// how many were in flight at once.
    (Wiktionary, List<String>, int Function()) fake({bool failFirst = false}) {
      final log = <String>[];
      var inFlight = 0, peak = 0, failed = !failFirst;
      final client = MockClient((req) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        final q = req.url.queryParameters;
        log.add('${q['page']}:${q['prop']}');
        if (!failed) {
          failed = true;
          return http.Response('nope', 500);
        }
        if (q['page']!.startsWith(RegExp('[A-Z]'))) {
          return http.Response('{"error":{"code":"missingtitle"}}', 200);
        }
        return http.Response(
          q['prop'] == 'sections'
              ? '{"parse":{"sections":[{"line":"French","toclevel":1,'
                    '"index":"1"}]}}'
              : '{"parse":{"text":${jsonEncode(html)}}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      return (Wiktionary(client: client), log, () => peak);
    }

    test(
      'asking again, even while it is under way, shares one lookup',
      () async {
        final (w, log, _) = fake();
        final early = w.lookup('maisonA', 'en', 'French'); // during the game
        final late = w.lookup('maisonA', 'en', 'French'); // the end screen
        expect(identical(early, late), isTrue);
        final info = await late;
        expect(info, isNotNull);
        expect(info!.blocks.first.pos, 'noun');
        final requests = log.length;
        await w.lookup('maisonA', 'en', 'French');
        expect(log.length, requests, reason: 'nothing more was asked');
      },
    );

    test('lookups of different words never overlap', () async {
      final (w, _, peak) = fake();
      await Future.wait([
        w.lookup('maisonB', 'en', 'French'),
        w.lookup('maisonC', 'en', 'French'),
        w.lookup('maisonD', 'en', 'French'),
      ]);
      expect(peak(), 1, reason: 'one request at a time');
    });

    test('a failure is not remembered: asking again tries again', () async {
      final (w, _, _) = fake(failFirst: true);
      await expectLater(w.lookup('maisonE', 'en', 'French'), throwsA(anything));
      final again = await w.lookup('maisonE', 'en', 'French');
      expect(again, isNotNull);
    });

    test('prefetch never throws, and its result is there for later', () async {
      final (w, log, _) = fake(failFirst: true);
      w.prefetch('maisonF', 'en', 'French'); // fails quietly
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(log, isNotEmpty);
      final info = await w.lookup(
        'maisonF',
        'en',
        'French',
      ); // second try works
      expect(info, isNotNull);
    });
  });
}
