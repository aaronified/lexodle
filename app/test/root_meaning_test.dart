import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/word_info.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/root_meaning.dart';
import 'package:lexodle/wiktionary.dart';

WordInfo _info(List<(String, List<String>)> blocks) {
  final list = <PosBlock>[];
  for (final (pos, senses) in blocks) {
    final b = PosBlock(pos);
    for (final s in senses) {
      b.senses.add(Sense(s));
    }
    list.add(b);
  }
  return WordInfo(url: 'https://x', blocks: list);
}

void main() {
  keptRootsTests();
  test('the root is read from the sense of a form', () {
    expect(rootOfSense('plural of deke', 'dekes'), 'deke');
    expect(
      rootOfSense(
        'third-person singular simple present indicative of deke',
        'dekes',
      ),
      'deke',
    );
    expect(rootOfSense('plural of Deke', 'dekes'), 'Deke');
    expect(
      rootOfSense('simple past and past participle of tread', 'trod'),
      'tread',
    );
    expect(rootOfSense('comparative form of good.', 'better'), 'good');
  });

  test('a meaning that is not a form of a word has no root', () {
    expect(rootOfSense('a form of art practised in the north', 'x'), isNull);
    expect(rootOfSense('state of the art', 'x'), isNull);
    expect(rootOfSense('plural of trods', 'trods'), isNull);
  });

  testWidgets('under a form, the meaning of its root of the same kind', (
    tester,
  ) async {
    final root = _info([
      ('noun', ['a feint in sport', 'a trick']),
      ('verb', ['to feint']),
    ]);
    const lang = Language('en', 'English', 'English', [5]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordInfoBody(
            info: _info([
              ('noun', ['plural of deke']),
            ]),
            underSense: (b, s) => RootSenses(
              root: rootOfSense(s.text, 'dekes')!,
              pos: b.pos,
              language: lang,
              lookup: (_) async => root,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('plural of deke', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('a feint in sport', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('to feint', findRichText: true), findsNothing);
  });
}

void keptRootsTests() {
  const lang = Language('en', 'English', 'English', [5]);

  test('the roots a form names, once each', () {
    final info = _info([
      ('noun', ['plural of gove', 'plural of gove']),
      ('verb', ['third-person singular simple present indicative of gove']),
    ]);
    expect(rootsOf(info, 'goves'), ['gove']);
    expect(missingRoots(info, 'goves'), isTrue);
    expect(
      missingRoots(
        _info([
          ('noun', ['a hay stack']),
        ]),
        'x',
      ),
      isFalse,
    );
  });

  test(
    'the entries of the roots are kept with the entry, and read back',
    () async {
      final info = _info([
        ('noun', ['plural of gove']),
      ]);
      final looked = <String>[];
      final full = await withRoots(
        info,
        'goves',
        lang,
        lookup: (r) async {
          looked.add(r);
          return _info([
            ('noun', ['a hay stack']),
          ]);
        },
      );
      expect(looked, ['gove']);
      expect(missingRoots(full, 'goves'), isFalse);
      final back = WordInfo.fromJson(full.toJson());
      expect(
        back.roots['gove']!.blocks.single.senses.single.text,
        'a hay stack',
      );
      // nothing left to look up the second time
      final again = await withRoots(
        back,
        'goves',
        lang,
        lookup: (r) async => fail('looked up $r again'),
      );
      expect(identical(again, back), isTrue);
    },
  );

  test('a root that cannot be had is left out and the entry stays', () async {
    final info = _info([
      ('noun', ['plural of gove']),
    ]);
    final a = await withRoots(info, 'goves', lang, lookup: (r) async => null);
    expect(identical(a, info), isTrue);
    final b = await withRoots(
      info,
      'goves',
      lang,
      lookup: (r) async => throw StateError('offline'),
    );
    expect(identical(b, info), isTrue);
  });

  testWidgets('a kept root shows under its sense with no lookup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RootSenses(
            root: 'gove',
            pos: 'noun',
            known: _info([
              ('noun', ['a hay stack']),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('gove'), findsOneWidget);
    expect(find.textContaining('a hay stack'), findsOneWidget);
  });
}
