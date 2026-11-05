import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The word lists of the themed wordle (assets/themes, built by tools/build_themes.py).
void main() {
  final dir = Directory('assets/themes');
  final manifest = jsonDecode(
    File('${dir.path}/themes.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final themes = [for (final t in manifest['themes'] as List) t as Map];

  List<List<String>> rows(String id) => [
    for (final l in File('${dir.path}/$id.tsv').readAsLinesSync())
      if (l.isNotEmpty) l.split('\t'),
  ];

  test('there are the five themes of common words, each with an "all"', () {
    expect(
      {for (final t in themes) t['id']},
      {'living', 'food', 'minerals', 'anatomy', 'math'},
    );
    for (final t in themes) {
      final subs = [for (final s in t['subs'] as List) s['id']];
      expect(subs.first, 'all', reason: '${t['id']}');
      expect(subs.toSet().length, subs.length, reason: 'unique subthemes');
      for (final s in subs) {
        expect(s, matches(RegExp(r'^[a-z0-9_]+$')), reason: 'an id: $s');
      }
    }
  });

  for (final t in themes) {
    final id = t['id'] as String;
    group('the $id list', () {
      final r = rows(id);

      test('a word, its subthemes and its count, by count', () {
        final known = {for (final s in t['subs'] as List) s['id'] as String};
        final seen = <String>{};
        var last = 1 << 62;
        for (final f in r) {
          expect(f, hasLength(3), reason: f.join('|'));
          expect(f[0], matches(RegExp(r'^[a-z]{4,8}$')), reason: f[0]);
          expect(seen.add(f[0]), isTrue, reason: 'twice: ${f[0]}');
          // (a word of a hidden group is in the theme, in no subtheme)
          for (final s in f[1].isEmpty ? <String>[] : f[1].split(',')) {
            expect(known, contains(s), reason: '${f[0]}: $s');
          }
          final n = int.parse(f[2]);
          expect(n, greaterThan(0));
          expect(n, lessThanOrEqualTo(last), reason: 'sorted by count');
          last = n;
        }
      });

      test('the manifest counts what the file holds, by length', () {
        for (final s in t['subs'] as List) {
          final inSub = [
            for (final f in r)
              if (s['id'] == 'all' || f[1].split(',').contains(s['id'])) f[0],
          ];
          final by = <String, int>{};
          for (final w in inSub) {
            by['${w.length}'] = (by['${w.length}'] ?? 0) + 1;
          }
          expect(
            Map<String, int>.from(s['counts'] as Map),
            by,
            reason: '$id / ${s['id']}',
          );
        }
      });

      test('every length has enough words to guess in', () {
        final c = Map<String, int>.from(
          (t['subs'] as List).first['counts'] as Map,
        );
        for (var n = 4; n <= 8; n++) {
          expect(c['$n'] ?? 0, greaterThanOrEqualTo(20), reason: '$id of $n');
        }
      });

      test('nothing rude, and nothing on the deny list', () {
        const rude = {
          'fuck',
          'shit',
          'cunt',
          'slut',
          'whore',
          'bitch',
          'cock',
          'dick',
          'twat',
          'pussy',
          'nigger',
          'faggot',
          'bollocks',
          'wank',
        };
        final deny = {
          for (final l in File('tools/themes/deny.txt').readAsLinesSync())
            if (l.split('#').first.trim().isNotEmpty) l.split('#').first.trim(),
        };
        for (final f in r) {
          expect(rude, isNot(contains(f[0])));
          expect(deny, isNot(contains(f[0])), reason: f[0]);
        }
      });
    });
  }

  test('the credits are with the data', () {
    final n = File('${dir.path}/NOTICE.md').readAsStringSync();
    expect(n, contains('WordNet 3.0 Copyright 2006 by Princeton University'));
    expect(n, contains('Wiktionary'));
  });
}
