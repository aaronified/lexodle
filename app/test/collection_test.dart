import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/collection.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

AchState? ach(AppState a, String id, [String lang = 'en']) => a.achOf(lang)[id];

void win(
  AppState a,
  List<String> answers, {
  String lang = 'en',
  GameMode mode = GameMode.classic,
  bool won = true,
}) {
  a.recordHistory(
    lang: lang,
    mode: mode,
    length: 5,
    tries: 6,
    pool: 0,
    answers: answers,
    won: won,
    guesses: [
      GuessRow(game: 0, n: 0, word: answers.first, skill: 100, luck: 0),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the collection', () {
    test('keeps a word once per language, newest first', () {
      final c = Collection()
        ..addWord('en', 'clubs')
        ..addWord('en', 'tours')
        ..addWord('fr', 'cloche');
      expect(c.addWord('en', 'clubs'), isFalse);
      expect(c.wordsOf('en'), ['tours', 'clubs']);
      expect(c.countOf('fr'), 1);
      expect(c.languages, ['en', 'fr']);
      expect(c.total, 3);
    });

    test('comes back from json, a bad entry left out', () {
      final c = Collection()
        ..addWord('en', 'clubs')
        ..addPlace('paris');
      final j = jsonDecode(jsonEncode(c.toJson())) as Map;
      (j['w'] as Map)['de'] = [1, 'haus'];
      (j['w'] as Map)['x'] = 'junk';
      final back = Collection.fromJson(j);
      expect(back.wordsOf('en'), ['clubs']);
      expect(back.wordsOf('de'), ['haus']);
      expect(back.places, ['paris']);
      expect(Collection.fromJson('junk').isEmpty, isTrue);
    });
  });

  group('the words collected in a game', () {
    test('a win collects its words, a loss nothing', () async {
      final a = AppState();
      await a.load();
      win(a, ['clubs']);
      win(a, ['tours'], won: false);
      expect(a.collection.wordsOf('en'), ['clubs']);
    });

    test(
      'a quartet collects all four, an equation none, geography a place',
      () async {
        final a = AppState();
        await a.load();
        win(a, ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'], mode: GameMode.quartet);
        win(a, ['12+3=15'], mode: GameMode.equations);
        win(a, ['paris'], mode: GameMode.themed);
        expect(a.collection.countOf('en'), 4);
        expect(a.collection.places, ['paris']);
      },
    );

    test('are kept between runs', () async {
      final a = AppState();
      await a.load();
      win(a, ['clubs']);
      final b = AppState();
      await b.load();
      expect(b.collection.contains('en', 'clubs'), isTrue);
    });

    test('rebuilding the achievements collects the won games again', () async {
      final a = AppState();
      await a.load();
      win(a, ['clubs']);
      win(a, ['cloche'], lang: 'fr');
      a.collection = Collection();
      a.rebuildAchievements();
      expect(a.collection.wordsOf('en'), ['clubs']);
      expect(a.collection.wordsOf('fr'), ['cloche']);
    });
  });

  group('the achievements around the dictionary', () {
    test('word collector counts the words of a language', () {
      final states = <String, AchState>{};
      var earned = advanceCounted(states, 'd', counts: {'collected': 9});
      expect(earned.where((a) => a.id == 'collected'), isEmpty);
      earned = advanceCounted(states, 'd', counts: {'collected': 10});
      expect(earned.where((a) => a.id == 'collected').single.level, 0);
      earned = advanceCounted(states, 'd', counts: {'collected': 250});
      expect(earned.where((a) => a.id == 'collected').map((a) => a.level), [
        1,
        2,
      ]);
    });

    test('its platinum is every word of the language', () {
      final states = <String, AchState>{};
      advanceCounted(states, 'd', counts: {'collected': 300}, words: 400);
      expect(states['collected']!.times, 3);
      final earned = advanceCounted(
        states,
        'd',
        counts: {'collected': 400},
        words: 400,
      );
      expect(earned.single.level, 3);
      final a = achievementById('collected')!;
      expect(a.targetAt(3, words: 400), 400);
      expect(a.atLevel(3).description, 'collect every word of the language');
    });

    test(
      'saving words and writing notes earn the keeper and the annotator',
      () async {
        final a = AppState();
        await a.load();
        var earned = <Achievement>[];
        for (var i = 0; i < 5; i++) {
          earned = a.saveWord('en', 'word$i', null, today: '2026-11-12');
        }
        expect(earned.map((x) => x.id), contains('saved_words'));
        expect(ach(a, 'saved_words')!.times, 1);
        final first = a.setWordNote('en', 'word0', 'a note');
        expect(first.map((x) => x.id), contains('noted_words'));
        // the same note edited again earns nothing more
        expect(a.setWordNote('en', 'word0', 'a note, longer'), isEmpty);
        // they are the player's own, in every language
        expect(a.achOf('fr')['saved_words']?.times, 1);
      },
    );

    test('the words collected earn in the language of the game', () async {
      final a = AppState();
      await a.load();
      for (var i = 0; i < 10; i++) {
        win(a, ['wd${String.fromCharCode(97 + i)}x']);
      }
      a.refreshCounted();
      expect(ach(a, 'collected', 'en')!.times, 1);
      expect(a.achOf('fr')['collected']?.times ?? 0, 0);
    });
  });

  group('the collection in a backup', () {
    test('goes in and comes back', () async {
      final a = AppState();
      await a.load();
      win(a, ['clubs']);
      win(a, ['paris'], mode: GameMode.themed);
      final p = parseBackup(backupToText(a));
      expect(p.collected!.wordsOf('en'), ['clubs']);
      final b = AppState();
      await b.load();
      b.restore(
        settings: p.settings,
        stats: p.stats,
        ach: p.achievements,
        languages: p.languages,
        history: p.history,
        learn: p.learn,
        words: p.words,
        collected: p.collected,
      );
      expect(b.collection.wordsOf('en'), ['clubs']);
      expect(b.collection.places, ['paris']);
    });

    test('from before it, is collected again from the games kept', () async {
      final a = AppState();
      await a.load();
      win(a, ['clubs']);
      final map = jsonDecode(backupToText(a)) as Map<String, dynamic>
        ..remove('collection');
      final p = parseBackup(jsonEncode(map));
      expect(p.collected, isNull);
      final b = AppState();
      await b.load();
      b.restore(
        settings: p.settings,
        stats: p.stats,
        ach: p.achievements,
        languages: p.languages,
        history: p.history,
        learn: p.learn,
        words: p.words,
        collected: p.collected,
      );
      expect(b.collection.wordsOf('en'), ['clubs']);
    });
  });
}
