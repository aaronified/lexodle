import 'package:flutter_test/flutter_test.dart';
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
  test('the root is read from the forms of a word', () {
    final info = _info([
      ('noun', ['plural of deke']),
      ('verb', ['third-person singular simple present indicative of deke']),
      ('noun', ['plural of Deke']),
    ]);
    expect(rootsOf(info, 'dekes'), ['deke']);
  });

  test('several roots, each once, in order; verb forms and comparatives', () {
    final info = _info([
      ('verb', ['simple past and past participle of tread']),
      ('noun', ['plural of trode']),
      ('adjective', ['comparative form of good.']),
    ]);
    expect(rootsOf(info, 'trod'), ['tread', 'trode', 'good']);
  });

  test('a meaning that is not a form of a word has no root', () {
    final info = _info([
      ('noun', ['a form of art practised in the north', 'state of the art']),
      ('noun', ['plural of trods']),
    ]);
    expect(rootsOf(info, 'trods'), isEmpty);
  });
}
