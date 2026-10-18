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
        final early = w.lookup('maisonA', 'fr', 'French'); // during the game
        final late = w.lookup('maisonA', 'fr', 'French'); // the end screen
        expect(identical(early, late), isTrue);
        final info = await late;
        expect(info, isNotNull);
        expect(info!.blocks.first.pos, 'noun');
        final requests = log.length;
        await w.lookup('maisonA', 'fr', 'French');
        expect(log.length, requests, reason: 'nothing more was asked');
      },
    );

    test('lookups of different words never overlap', () async {
      final (w, _, peak) = fake();
      await Future.wait([
        w.lookup('maisonB', 'fr', 'French'),
        w.lookup('maisonC', 'fr', 'French'),
        w.lookup('maisonD', 'fr', 'French'),
      ]);
      expect(peak(), 1, reason: 'one request at a time');
    });

    test('a failure is not remembered: asking again tries again', () async {
      final (w, _, _) = fake(failFirst: true);
      await expectLater(w.lookup('maisonE', 'fr', 'French'), throwsA(anything));
      final again = await w.lookup('maisonE', 'fr', 'French');
      expect(again, isNotNull);
    });

    test('prefetch never throws, and its result is there for later', () async {
      final (w, log, _) = fake(failFirst: true);
      w.prefetch('maisonF', 'fr', 'French'); // fails quietly
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(log, isNotEmpty);
      final info = await w.lookup(
        'maisonF',
        'fr',
        'French',
      ); // second try works
      expect(info, isNotNull);
    });
  });
}
