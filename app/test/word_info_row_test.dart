import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/word_info.dart';
import 'package:lexodle/wiktionary.dart';

void main() {
  testWidgets('the word leads its pronunciation row, the bookmark ends it', (
    tester,
  ) async {
    final noun = PosBlock('noun')..senses.add(Sense('a crowbar'));
    final info = WordInfo(
      url: 'https://en.wiktionary.org/wiki/jemmy',
      ipa: const ['-ɛmi'],
      audio: 'https://example.org/jemmy.ogg',
      blocks: [noun],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordInfoBody(
            info: info,
            word: 'jemmy',
            saved: const Icon(Icons.bookmark, key: ValueKey('mark')),
          ),
        ),
      ),
    );
    final word = tester.getTopLeft(find.text('jemmy')).dx;
    final ipa = tester.getTopLeft(find.text('-ɛmi')).dx;
    final listen = tester
        .getTopLeft(find.byKey(const ValueKey('word-listen')))
        .dx;
    final mark = tester.getTopLeft(find.byKey(const ValueKey('mark'))).dx;
    expect(word, lessThan(ipa));
    expect(ipa, lessThan(listen));
    expect(listen, lessThan(mark));
    // the bookmark is right aligned
    expect(
      tester.getTopRight(find.byKey(const ValueKey('mark'))).dx,
      greaterThan(tester.getSize(find.byType(Scaffold)).width - 40),
    );
    // on one row
    expect(
      (tester.getCenter(find.text('jemmy')).dy -
              tester.getCenter(find.byKey(const ValueKey('mark'))).dy)
          .abs(),
      lessThan(8),
    );
  });
}
