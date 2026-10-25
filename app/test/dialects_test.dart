import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/dialects.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/store.dart';

/// English (US and UK) and Portuguese (Brazil and Portugal) are one language
/// each now. These are the pieces that read what was kept under the old codes.
void main() {
  group('languageCode', () {
    test('the variants go by the language they were merged into', () {
      expect(languageCode('en-GB'), 'en');
      expect(languageCode('pt-PT'), 'pt');
    });

    test('every other code, the new ones included, stays as it is', () {
      for (final c in ['en', 'pt', 'fr', 'de', 'es', 'nb', 'ca', 'xx', '']) {
        expect(languageCode(c), c);
      }
      // case matters: only the exact old codes are folded
      expect(languageCode('en-gb'), 'en-gb');
      expect(languageCode(languageCode('en-GB')), 'en', reason: 'idempotent');
    });

    test('the table says the same', () {
      expect(mergedLanguages, {'en-GB': 'en', 'pt-PT': 'pt'});
    });
  });

  group('Stats.fromJson', () {
    Map<String, dynamic> stats() => {
      'played': 30,
      'wins': 22,
      'streak': 2,
      'bestStreak': 6,
      'langsWon': ['en', 'en-GB', 'fr', 'pt-PT'],
      'lengthsWon': [5, 6],
      'mastery': {
        'en': ['5:6:3000', '4:6'],
        'en-GB': ['5:6:2900', '6:6:3000', '7:4'],
        'fr': ['5:6'],
        'pt-PT': ['5:6:100'],
      },
    };

    test('the mastery of both Englishes joins the cells under en', () {
      final s = Stats.fromJson(stats());
      expect(s.mastery.keys.toSet(), {'en', 'fr', 'pt'});
      // 5:6 is in both (the old third part dropped): one cell, not two
      expect(s.mastery['en'], {'5:6', '4:6', '6:6', '7:4'});
      expect(s.mastery['fr'], {'5:6'});
      expect(s.mastery['pt'], {'5:6'});
    });

    test('the language is in langsWon once, under the new code', () {
      final s = Stats.fromJson(stats());
      expect(s.langsWon, {'en', 'fr', 'pt'});
      expect(s.toJson()['langsWon'].where((l) => l == 'en'), hasLength(1));
      expect(s.toJson()['langsWon'], hasLength(3));
    });

    test('the numbers are not touched', () {
      final s = Stats.fromJson(stats());
      expect(s.played, 30);
      expect(s.wins, 22);
      expect(s.streak, 2);
      expect(s.bestStreak, 6);
      expect(s.lengthsWon, {5, 6});
    });

    test('what is written again names only the new codes', () {
      final text = Stats.fromJson(stats()).toJson().toString();
      expect(text, isNot(contains('en-GB')));
      expect(text, isNot(contains('pt-PT')));
    });

    test('statistics with only the old code are still read as the new', () {
      final s = Stats.fromJson({
        'langsWon': ['en-GB'],
        'mastery': {
          'en-GB': ['5:6'],
        },
      });
      expect(s.langsWon, {'en'});
      expect(s.mastery, {
        'en': {'5:6'},
      });
    });
  });

  group('GameRow', () {
    List<Object> compact(String lang, {int id = 7}) => [
      id,
      1792490400000,
      lang,
      0,
      5,
      6,
      3000,
      ['crane'],
      1,
      '',
      2,
    ];

    Map<String, dynamic> map(String lang) => {
      'id': 8,
      'at': 1792490400000,
      'lang': lang,
      'mode': 0,
      'length': 5,
      'tries': 6,
      'pool': 3000,
      'answers': ['crane'],
      'won': true,
      'v': 2,
    };

    setUp(() => GameRow.mergedLanguageRows = 0);

    test('a compact row of an old code is read under the new', () {
      expect(GameRow.fromAny(compact('en-GB')).lang, 'en');
      expect(GameRow.fromAny(compact('pt-PT')).lang, 'pt');
      expect(GameRow.mergedLanguageRows, 2);
    });

    test('a row of the map form is too', () {
      expect(GameRow.fromAny(map('en-GB')).lang, 'en');
      expect(GameRow.fromAny(map('pt-PT')).lang, 'pt');
      expect(GameRow.mergedLanguageRows, 2);
    });

    test('rows of the new or other codes are not counted as relabelled', () {
      for (final l in ['en', 'pt', 'fr']) {
        expect(GameRow.fromAny(compact(l)).lang, l);
        expect(GameRow.fromAny(map(l)).lang, l);
      }
      expect(GameRow.mergedLanguageRows, 0);
    });

    test('the rest of the row is kept as it was', () {
      final g = GameRow.fromAny(compact('en-GB', id: 41));
      expect(g.id, 41);
      expect(g.at, 1792490400000);
      expect(g.length, 5);
      expect(g.tries, 6);
      expect(g.pool, 3000);
      expect(g.answers, ['crane']);
      expect(g.won, isTrue);
      expect(g.version, 2);
      // written again, it names the new code
      expect(g.toRow()[2], 'en');
    });
  });

  group('the pieces that are joined', () {
    test('an achievement: earned as often as the more often, days joined', () {
      final a = AchState(
        times: 1,
        dates: ['2026-10-09', '2026-10-02'],
        progress: 4,
        seen: {'5'},
      );
      final b = AchState(
        times: 3,
        dates: ['2026-10-02', '2026-10-01'],
        progress: 2,
        seen: {'6'},
      );
      final m = mergeAchState(a, b);
      expect(m.times, 3);
      expect(m.dates, ['2026-10-01', '2026-10-02', '2026-10-09']);
      expect(m.progress, 4);
      expect(m.seen, {'5', '6'});
    });

    test('daily calendars: the better tier on a day both have', () {
      final m = mergeDailyLogs(
        {'2026-10-21': 1, '2026-10-22': 2, '2026-10-24': 0},
        {'2026-10-21': 2, '2026-10-22': 1, '2026-10-23': 1, '2026-10-24': 0},
      );
      expect(m, {
        '2026-10-21': 2,
        '2026-10-22': 2,
        '2026-10-23': 1,
        '2026-10-24': 0,
      });
    });

    test('what a backup held for two variants: first style, rest joined', () {
      const a = LanguageKept(
        style: 'steady',
        held: {'steady'},
        changes: 2,
        dailyLog: {'2026-10-21': 1},
        dailyBest: 3,
      );
      final b = LanguageKept(
        style: 'analyst',
        held: const {'analyst'},
        changes: 3,
        dailyLog: const {'2026-10-21': 2},
        dailyBest: 5,
        achievements: {'wins_10': AchState(times: 2)},
      );
      final m = mergeKept(a, b);
      expect(m.style, 'steady');
      expect(m.held, {'steady', 'analyst'});
      expect(m.changes, 5);
      expect(m.dailyLog, {'2026-10-21': 2});
      expect(m.dailyBest, 5);
      expect(m.achievements['wins_10']!.times, 2);
      // a style only the second has is not lost
      expect(mergeKept(const LanguageKept(), b).style, 'analyst');
      // nothing on either side stays nothing, not zero
      final none = mergeKept(const LanguageKept(), const LanguageKept());
      expect(none.style, isNull);
      expect(none.held, isNull);
      expect(none.changes, isNull);
      expect(none.dailyLog, isNull);
      expect(none.dailyBest, isNull);
    });
  });

  group('achievements that count languages', () {
    test('a player who won in both Englishes counts one language', () {
      final s = AchState(times: 1, progress: 2, seen: {'en', 'en-GB'});
      final f = foldMergedLanguages(s);
      expect(f.seen, {'en'});
      expect(f.progress, 1);
      expect(f.times, 1, reason: 'a track, not a badge: earnings are kept');
    });

    test('a badge loses the earning of a language that merged away', () {
      final s = AchState(
        times: 2,
        dates: ['2026-10-20', '2026-10-24'],
        progress: 2,
        seen: {'en', 'en-GB'},
      );
      final f = foldMergedLanguages(s, badges: true);
      expect(f.seen, {'en'});
      expect(f.times, 1);
      expect(f.dates, ['2026-10-20']);
      expect(f.progress, 1);
    });

    test('only the old code present just takes the new one', () {
      final f = foldMergedLanguages(AchState(progress: 1, seen: {'pt-PT'}));
      expect(f.seen, {'pt'});
      expect(f.progress, 1);
    });

    test('a state with nothing merged is the same state', () {
      final s = AchState(progress: 2, seen: {'en', 'fr'});
      expect(identical(foldMergedLanguages(s), s), isTrue);
      final lengths = AchState(progress: 2, seen: {'5', '6'});
      expect(identical(foldMergedLanguages(lengths), lengths), isTrue);
    });
  });
}
