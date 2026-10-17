// Live smoke check of the Wiktionary client: dart run tools/live_check.dart
// ignore_for_file: avoid_print
import 'package:http/http.dart' as http;
import 'package:lexodle/wiktionary.dart';

Future<void> main() async {
  const cases = [
    ('house', 'en', 'English'),
    ('maison', 'fr', 'French'),
    ('haus', 'de', 'German'),
    ('kitap', 'tr', 'Turkish'),
    ('okno', 'pl', 'Polish'),
    ('rumah', 'id', 'Indonesian'),
    ('hus', 'nb', 'Norwegian Bokmål'),
    ('zzzzq', 'en', 'English'),
  ];
  final w = Wiktionary(client: _Polite());
  for (final (word, code, section) in cases) {
    try {
      final i = await w.lookup(word, code, section);
      if (i == null) {
        print('$code $word: no entry');
        continue;
      }
      print('$code $word: ipa=${i.ipa.take(1)} audio=${i.audio != null} '
          'pos=${i.blocks.map((b) => b.pos).toList()} '
          'def="${i.blocks.firstOrNull?.definitions.firstOrNull}" '
          'syn=${i.synonyms.length} ant=${i.antonyms.length}');
    } catch (e) {
      print('$code $word: ERROR $e');
    }
  }
}

/// Wikimedia asks API clients to identify themselves; browsers do this
/// themselves, the Dart VM does not. Also spaces requests out.
class _Polite extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    request.headers['User-Agent'] =
        'lexodle-live-check/0.1 (https://github.com/aaronified/lexodle)';
    return _inner.send(request);
  }
}
