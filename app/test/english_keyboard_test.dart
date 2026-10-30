import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the English keyboard has a to z only, and accents are typed plain',
    () async {
      final langs = await WordBank.languages();
      final en = await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
      for (final n in [4, 5, 6, 7, 8]) {
        expect(
          en.letters(n).every((c) => RegExp('^[a-z]\$').hasMatch(c)),
          isTrue,
          reason: '$n letters',
        );
      }
      // an accented word whose plain spelling is not a word is typed plain
      expect(en.valid, contains('aperçu'));
      expect(en.valid, isNot(contains('apercu')));
      expect(en.resolve('apercu'), 'aperçu');
      // when the plain spelling is a word, that is what is typed
      expect(en.resolve('cafe'), 'cafe');
      expect(en.resolve('crane'), 'crane');
      expect(en.resolve('zzzzz'), 'zzzzz');
      // other languages keep their own letters
      final fr = await WordBank.load(langs.firstWhere((l) => l.code == 'fr'));
      expect(fr.letters(5).any((c) => !RegExp('^[a-z]\$').hasMatch(c)), isTrue);
      expect(fr.resolve('ecole'), 'ecole');
    },
  );
}
