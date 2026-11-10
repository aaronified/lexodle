import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:shared_preferences/shared_preferences.dart';

WordInfo entry() {
  final noun = PosBlock('noun', gender: 'm', forms: '(plural clubs)')
    ..senses.add(
      Sense(
        'a group of people',
        labels: ['informal'],
        examples: [const Example('a book club', 'un club de lecture')],
      ),
    )
    ..senses.add(Sense('a heavy stick'));
  return WordInfo(
    url: 'https://en.wiktionary.org/wiki/club',
    ipa: ['/klʌb/'],
    audio: 'https://example.org/club.ogg',
    blocks: [noun],
    synonyms: ['society'],
    antonyms: ['loner'],
    etymology: 'from old norse',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the wiktionary entry as it is kept', () {
    test('comes back from json as it went', () {
      final back = WordInfo.fromJson(
        jsonDecode(jsonEncode(entry().toJson())) as Map<String, dynamic>,
      );
      expect(back.url, entry().url);
      expect(back.ipa, ['/klʌb/']);
      expect(back.audio, 'https://example.org/club.ogg');
      expect(back.synonyms, ['society']);
      expect(back.antonyms, ['loner']);
      expect(back.etymology, 'from old norse');
      final b = back.blocks.single;
      expect(b.pos, 'noun');
      expect(b.gender, 'm');
      expect(b.forms, '(plural clubs)');
      expect(b.senses.map((s) => s.text), [
        'a group of people',
        'a heavy stick',
      ]);
      expect(b.senses.first.labels, ['informal']);
      expect(b.senses.first.examples.single.text, 'a book club');
      expect(b.senses.first.examples.single.translation, 'un club de lecture');
    });
  });

  group('the saved words', () {
    test('keep the newest first, and each word once per language', () {
      final w = SavedWords()
        ..add(SavedWord(lang: 'en', word: 'clubs', date: '2026-11-01'))
        ..add(SavedWord(lang: 'en', word: 'tours', date: '2026-11-02'))
        ..add(SavedWord(lang: 'fr', word: 'clubs', date: '2026-11-03'))
        ..add(SavedWord(lang: 'en', word: 'clubs', date: '2026-11-04'));
      expect(w.words.map((x) => x.key), ['fr|clubs', 'en|tours', 'en|clubs']);
      expect(w.find('en', 'clubs')!.date, '2026-11-01');
    });

    test('remove, and take a note', () {
      final w = SavedWords([SavedWord(lang: 'en', word: 'clubs', date: 'd')]);
      expect(w.setNote('en', 'clubs', 'suits'), isTrue);
      expect(w.setNote('en', 'nope', 'x'), isFalse);
      expect(w.find('en', 'clubs')!.note, 'suits');
      expect(w.remove('en', 'clubs'), isTrue);
      expect(w.remove('en', 'clubs'), isFalse);
      expect(w.isEmpty, isTrue);
    });

    test('the first meaning is the first sense of the first block', () {
      expect(
        SavedWord(
          lang: 'en',
          word: 'club',
          date: 'd',
          info: entry(),
        ).firstMeaning,
        'a group of people',
      );
      expect(SavedWord(lang: 'en', word: 'x', date: 'd').firstMeaning, '');
    });

    test('come back from json, a damaged entry left out', () {
      final w = SavedWords([
        SavedWord(
          lang: 'en',
          word: 'clubs',
          date: '2026-11-01',
          note: 'suits',
          info: entry(),
        ),
        SavedWord(lang: 'fr', word: 'cloche', date: '2026-11-02'),
      ]);
      final list = jsonDecode(jsonEncode(w.toJson())) as List;
      list.add({'l': 'en'});
      list.add('junk');
      final back = SavedWords.fromJson(list);
      expect(back.length, 2);
      final c = back.find('en', 'clubs')!;
      expect(c.note, 'suits');
      expect(c.info!.blocks.single.senses.length, 2);
      expect(back.find('fr', 'cloche')!.info, isNull);
    });
  });

  group('the saved words in the app', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('are kept between runs', () async {
      final a = AppState();
      await a.load();
      a.saveWord('en', 'clubs', entry(), today: '2026-11-12');
      a.setWordNote('en', 'clubs', 'suits');
      expect(a.isWordSaved('en', 'clubs'), isTrue);
      final b = AppState();
      await b.load();
      final w = b.savedWords.find('en', 'clubs')!;
      expect(w.date, '2026-11-12');
      expect(w.note, 'suits');
      expect(w.info!.ipa, ['/klʌb/']);
      b.unsaveWord('en', 'clubs');
      final c = AppState();
      await c.load();
      expect(c.savedWords.isEmpty, isTrue);
    });

    test('saving a word twice keeps the first', () async {
      final a = AppState();
      await a.load();
      a.saveWord('en', 'clubs', null, today: '2026-11-01');
      a.saveWord('en', 'clubs', entry(), today: '2026-11-09');
      expect(a.savedWords.length, 1);
      expect(a.savedWords.find('en', 'clubs')!.date, '2026-11-01');
    });

    test('go into a backup and come back from it', () async {
      final a = AppState();
      await a.load();
      a.saveWord('en', 'clubs', entry(), today: '2026-11-12');
      a.setWordNote('en', 'clubs', 'suits');
      final text = backupToText(a);
      final b = AppState();
      await b.load();
      final parsed = parseBackup(text);
      expect(parsed.words!.length, 1);
      b.restore(
        settings: parsed.settings,
        stats: parsed.stats,
        ach: parsed.achievements,
        languages: parsed.languages,
        history: parsed.history,
        learn: parsed.learn,
        words: parsed.words,
      );
      expect(b.savedWords.find('en', 'clubs')!.note, 'suits');
    });

    test('a backup from before them leaves the saved words alone', () async {
      final a = AppState();
      await a.load();
      a.saveWord('en', 'clubs', null, today: '2026-11-12');
      final map = jsonDecode(backupToText(a)) as Map<String, dynamic>
        ..remove('words');
      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.words, isNull);
      a.restore(
        settings: parsed.settings,
        stats: parsed.stats,
        ach: parsed.achievements,
        languages: parsed.languages,
        history: parsed.history,
        learn: parsed.learn,
        words: parsed.words,
      );
      expect(a.isWordSaved('en', 'clubs'), isTrue);
    });
  });
}
