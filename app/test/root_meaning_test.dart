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
