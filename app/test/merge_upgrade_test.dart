import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A player of an earlier release, who played English as `en-GB` and some as
/// `en`, and Portuguese as `pt-PT` and `pt`: what the release before the
/// merge saved must come out as one language each, losing nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const day = 86400000;
  const start = 1792490400000; // 2026-10-20, in UTC

  // six games: (id, language, word, won, form)
  final games = <(int, String, String, bool, bool)>[
    (0, 'en', 'crane', true, true),
    (1, 'en', 'slate', false, true),
    (2, 'en-GB', 'metre', true, true),
    (3, 'en-GB', 'tower', true, false), // the map form
    (4, 'pt-PT', 'tempo', true, true),
    (5, 'pt', 'prato', false, true),
  ];

  String month(Map<String, Object?> chunk) => jsonEncode(chunk);

  Map<String, Object?> chunk() => {
    'games': [
      for (final (id, lang, word, won, compact) in games)
        compact
            ? [
                id,
                start + id * day,
                lang,
                0,
                5,
                6,
                3000,
                [word],
                won ? 1 : 0,
                '',
                2,
              ]
            : {
                'id': id,
                'at': start + id * day,
                'lang': lang,
                'mode': 0,
                'length': 5,
                'tries': 6,
                'pool': 3000,
                'answers': [word],
                'won': won,
                'v': 2,
              },
    ],
    'guesses': [
      for (final (id, _, word, _, _) in games)
        [id, 0, word, 70.0, 0.0, null, 0.0, 0, 0],
    ],
  };

  Map<String, Object> state() => {
    'lang': 'en-GB',
    'length': 5,
    'tries': 6,
    'seenHowTo': true,
    'stats': jsonEncode({
      'played': 6,
      'wins': 4,
      'streak': 1,
      'bestStreak': 3,
      'langsWon': ['en', 'en-GB', 'pt-PT'],
      'lengthsWon': [5],
      'mastery': {
        'en': ['5:6:3000'],
        'en-GB': ['5:6:2900', '6:6:3000'],
        'pt-PT': ['5:6:100'],
      },
    }),
    'ach': jsonEncode({
      'bilingual': {
        'times': 0,
        'dates': [],
        'progress': 2,
        'seen': ['en', 'pt-PT'],
      },
    }),
    'achLang': jsonEncode({
      'en': {
        'wins_10': {
          'times': 1,
          'dates': ['2026-10-02'],
          'progress': 5,
          'seen': [],
        },
        'one_shot': {
          'times': 1,
          'dates': ['2026-10-05'],
          'progress': 0,
          'seen': [],
        },
        'full_range': {
          'times': 0,
          'dates': [],
          'progress': 1,
          'seen': ['5'],
        },
      },
      'en-GB': {
        'wins_10': {
          'times': 3,
          'dates': ['2026-10-09', '2026-10-01', '2026-10-02'],
          'progress': 9,
          'seen': [],
        },
        'daily_3': {
          'times': 1,
          'dates': ['2026-10-12'],
          'progress': 0,
          'seen': [],
        },
        'full_range': {
          'times': 0,
          'dates': [],
          'progress': 2,
          'seen': ['6', '7'],
        },
      },
      'pt-PT': {
        'wins_10': {
          'times': 1,
          'dates': ['2026-10-03'],
          'progress': 1,
          'seen': [],
        },
      },
    }),
    'styles': jsonEncode({
      'en': 'steady',
      'en-GB': 'analyst',
      'pt-PT': 'maverick',
      'fr': 'gambler',
    }),
    'stylesHeldBy': jsonEncode({
      'en': ['steady'],
      'en-GB': ['analyst', 'steady'],
      'pt-PT': ['maverick'],
      'fr': ['gambler'],
    }),
    'styleChangesBy': jsonEncode({'en': 2, 'en-GB': 3, 'pt-PT': 1, 'fr': 4}),
    'dailyLogs': jsonEncode({
      'en': {'2026-10-21': 1, '2026-10-22': 2},
      'en-GB': {'2026-10-21': 2, '2026-10-22': 1, '2026-10-23': 0},
      'pt-PT': {'2026-10-23': 1},
      'fr': {'2026-10-23': 2},
    }),
    'dailyBests': jsonEncode({'en': 3, 'en-GB': 5, 'pt-PT': 2, 'fr': 1}),
    'daily': jsonEncode({
      'en-GB|2026-10-24': {
        'g': ['slate'],
        'w': 1,
      },
      'pt-PT|2026-10-24': {
        'g': ['tempo'],
      },
      'en|2026-10-25': {
        'g': ['crane'],
      },
      'fr|2026-10-24': {
        'g': ['peste'],
        'w': 0,
      },
    }),
    'history:months': ['2026-10'],
    'history:2026-10': month(chunk()),
  };

  Future<AppState> load() async {
    final s = AppState();
    await s.load();
    return s;
  }

  // the writes of a load are not awaited by it
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  String ach(AppState s, String lang, String id) =>
      jsonEncode(s.achOf(lang)[id]?.toJson());

  setUp(() => SharedPreferences.setMockInitialValues(state()));

  group('the first start after the merge', () {
    late AppState s;
    setUp(() async => s = await load());

    test('the language in use is English', () {
      expect(s.lang, 'en');
    });

    test('the statistics are under the new codes only', () {
      expect(s.stats.mastery.keys.toSet(), {'en', 'pt'});
      expect(s.stats.mastery['en'], {'5:6', '6:6'});
      expect(s.stats.mastery['pt'], {'5:6'});
      expect(s.stats.langsWon, {'en', 'pt'});
    });

    test('every game of the history is in the new language', () {
      expect(s.history.games, hasLength(6));
      expect(s.history.games.map((g) => g.lang).toSet(), {'en', 'pt'});
      expect(s.history.games.where((g) => g.lang == 'en'), hasLength(4));
      expect(s.history.games.where((g) => g.lang == 'pt'), hasLength(2));
      expect(s.skippedRows, 0);
    });

    test(
      'the playstyle of the language itself wins; the others are joined',
      () {
        expect(s.styleIdOf('en'), 'steady');
        expect(
          s.styleIdOf('pt'),
          'maverick',
          reason: 'only the old code had one',
        );
        expect(s.styleIdOf('fr'), 'gambler', reason: 'other languages stay');
        expect(s.styleIdOf('en-GB'), isNull);
        expect(s.stylesHeldOf('en'), {'steady', 'analyst'});
        expect(s.stylesHeldOf('pt'), {'maverick'});
        expect(s.styleChangesOf('en'), 5);
        expect(s.styleChangesOf('pt'), 1);
        expect(s.styleChangesOf('fr'), 4);
      },
    );

    test('the daily calendar takes the better tier of each day', () {
      expect(s.dailyLogOf('en'), {
        '2026-10-21': 2,
        '2026-10-22': 2,
        '2026-10-23': 0,
      });
      expect(s.dailyLogOf('pt'), {'2026-10-23': 1});
      expect(s.dailyLogOf('fr'), {'2026-10-23': 2});
      expect(s.dailyLogOf('en-GB'), isEmpty);
      expect(s.dailyBestOf('en'), 5);
      expect(s.dailyBestOf('pt'), 2);
      expect(s.dailyBestOf('fr'), 1);
      expect(s.dailyBestOf('en-GB'), 0);
    });

    test('the achievements are merged', () {
      final wins = s.achOf('en')['wins_10']!;
      expect(wins.times, 3);
      expect(wins.dates, ['2026-10-01', '2026-10-02', '2026-10-09']);
      expect(wins.progress, 9);
      expect(s.achOf('en')['one_shot']!.times, 1, reason: 'only en had it');
      expect(s.achOf('en')['daily_3']!.times, 1, reason: 'only en-GB had it');
      expect(s.achOf('en')['daily_3']!.dates, ['2026-10-12']);
      final range = s.achOf('en')['full_range']!;
      expect(range.seen, {'5', '6', '7'});
      expect(range.progress, 2);
      expect(s.achOf('pt')['wins_10']!.times, 1);
      expect(s.achLanguages.toSet(), {'en', 'pt'});
      expect(s.playedLanguages, containsAll(['en', 'pt']));
      expect(s.playedLanguages, isNot(contains('en-GB')));
      expect(s.playedLanguages, isNot(contains('pt-PT')));
    });

    test('a daily in progress under an old code is dropped, the rest kept', () {
      expect(s.daily.keys.toSet(), {'en|2026-10-25', 'fr|2026-10-24'});
      expect(s.daily['fr|2026-10-24']!.won, isFalse);
    });

    test(
      'nothing is lost: games played and won, and the rest of the stats',
      () {
        expect(s.stats.played, 6);
        expect(s.stats.wins, 4);
        expect(s.stats.streak, 1);
        expect(s.stats.bestStreak, 3);
        expect(s.stats.lengthsWon, {5});
        expect(s.history.games.where((g) => g.won), hasLength(4));
        expect(s.seenHowTo, isTrue);
        expect(s.length, 5);
        expect(s.tries, 6);
        // the global achievements are not touched
        expect(s.achOf('')['bilingual']!.progress, 2);
      },
    );
  });

  test(
    'the achievements that count languages count a merged one once',
    () async {
      // bilingual, polyglot and the others keep the languages counted, as codes
      // in `seen`, and their progress is how many: en and en-GB are one now
      final prefs = state();
      prefs['ach'] = jsonEncode({
        'bilingual': {
          'times': 0,
          'dates': <String>[],
          'progress': 3,
          'seen': ['en', 'en-GB', 'pt-PT'],
        },
      });
      SharedPreferences.setMockInitialValues(prefs);
      final s = await load();
      final b = s.achOf('')['bilingual']!;
      expect(b.seen, {'en', 'pt'});
      expect(b.progress, 2);
      await settle();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('ach'), isNot(contains('-GB')));
      expect(p.getString('ach'), isNot(contains('pt-PT')));
    },
  );

  test('the old code is gone from every stored string', () async {
    await load();
    await settle();
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys()) {
      if (k == 'ach') continue; // the global ones: see the test on them
      final v = p.get(k);
      final text = v is List ? v.join('\n') : '$v';
      expect(k, isNot(contains('en-GB')), reason: 'key $k');
      expect(text, isNot(contains('en-GB')), reason: k);
      expect(text, isNot(contains('pt-PT')), reason: k);
    }
    expect(p.getString('lang'), 'en');
    // the history was written again with the new codes
    final saved = jsonDecode(p.getString('history:2026-10')!) as Map;
    expect((saved['games'] as List).map((g) => (g as List)[2]).toSet(), {
      'en',
      'pt',
    });
  });

  test(
    'a second start reads the same, and has nothing left to merge',
    () async {
      final first = await load();
      await settle();

      GameRow.mergedLanguageRows = 0;
      final second = await load();
      expect(
        GameRow.mergedLanguageRows,
        0,
        reason: 'no row is named with an old code any more',
      );

      Map<String, Object?> snap(AppState s) => {
        'lang': s.lang,
        'played': s.stats.played,
        'wins': s.stats.wins,
        'langsWon': s.stats.langsWon.toList()..sort(),
        'mastery': {
          for (final e in s.stats.mastery.entries)
            e.key: e.value.toList()..sort(),
        },
        'games': [
          for (final g in s.history.games) [g.id, g.lang, g.won, g.answers],
        ],
        'styles': {
          for (final l in ['en', 'pt', 'fr']) l: s.styleIdOf(l),
        },
        'held': {
          for (final l in ['en', 'pt', 'fr'])
            l: s.stylesHeldOf(l).toList()..sort(),
        },
        'changes': {
          for (final l in ['en', 'pt', 'fr']) l: s.styleChangesOf(l),
        },
        'logs': {
          for (final l in ['en', 'pt', 'fr']) l: s.dailyLogOf(l),
        },
        'bests': {
          for (final l in ['en', 'pt', 'fr']) l: s.dailyBestOf(l),
        },
        'ach': {
          for (final l in ['en', 'pt'])
            l: [
              for (final id in ['wins_10', 'one_shot', 'daily_3', 'full_range'])
                ach(s, l, id),
            ],
        },
        'daily': s.daily.keys.toList()..sort(),
      };

      expect(jsonEncode(snap(second)), jsonEncode(snap(first)));
      expect(second.history.games, hasLength(6));
      expect(second.stats.played, 6);
      expect(second.stats.wins, 4);

      // and it did not write the old codes back
      await settle();
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys()) {
        if (k == 'ach') continue; // the global ones: see the test on them
        final v = p.get(k);
        final text = v is List ? v.join('\n') : '$v';
        expect(text, isNot(contains('en-GB')), reason: k);
        expect(text, isNot(contains('pt-PT')), reason: k);
      }
    },
  );

  test('storage that is already merged is left as it is', () async {
    SharedPreferences.setMockInitialValues({
      'lang': 'pt',
      'stats': jsonEncode({
        'played': 2,
        'wins': 1,
        'langsWon': ['pt'],
        'mastery': {
          'pt': ['5:6'],
        },
      }),
      'styles': jsonEncode({'pt': 'steady'}),
      'dailyLogs': jsonEncode({
        'pt': {'2026-10-21': 1},
      }),
    });
    final s = await load();
    expect(s.lang, 'pt');
    expect(s.styleIdOf('pt'), 'steady');
    expect(s.dailyLogOf('pt'), {'2026-10-21': 1});
    expect(s.stats.mastery['pt'], {'5:6'});
  });

  group('a backup made before the merge', () {
    Map<String, Object?> kept(
      String style,
      List<String> held,
      int changes,
      Map<String, int> log,
      int best,
      Map<String, Object?> ach,
    ) => {
      'playstyle': {'current': style, 'held': held, 'changes': changes},
      'daily': {'log': log, 'best': best},
      'achievements': ach,
    };

    Map<String, Object?> wins(int times, List<String> dates, int progress) => {
      'wins_10': {
        'times': times,
        'dates': dates,
        'progress': progress,
        'seen': <String>[],
      },
    };

    String backup({bool oldFirst = false}) {
      final en = kept(
        'steady',
        ['steady'],
        2,
        {'2026-10-21': 1, '2026-10-22': 2},
        3,
        wins(1, ['2026-10-02'], 5),
      );
      final gb = kept(
        'analyst',
        ['analyst', 'steady'],
        3,
        {'2026-10-21': 2, '2026-10-22': 1, '2026-10-23': 0},
        5,
        wins(3, ['2026-10-09', '2026-10-01'], 9),
      );
      final pt = kept('maverick', ['maverick'], 1, {'2026-10-23': 1}, 2, {});
      return const JsonEncoder.withIndent('  ').convert({
        'app': 'lexodle',
        'version': 2,
        'exported': '2026-10-24T10:00:00.000Z',
        'settings': {'lang': 'en-GB', 'length': 5, 'tries': 6},
        'stats': {
          'played': 6,
          'wins': 4,
          'streak': 1,
          'bestStreak': 3,
          'langsWon': ['en', 'en-GB', 'pt-PT'],
          'lengthsWon': [5],
          'mastery': {
            'en': ['5:6:3000'],
            'en-GB': ['6:6:3000'],
            'pt-PT': ['5:6'],
          },
        },
        'achievements': {
          'bilingual': {
            'times': 0,
            'dates': <String>[],
            'progress': 2,
            'seen': ['en', 'pt'],
          },
        },
        'languages': oldFirst
            ? {'en-GB': gb, 'en': en, 'pt-PT': pt}
            : {'en': en, 'en-GB': gb, 'pt-PT': pt},
        'history': jsonEncode(chunk()),
      });
    }

    void checkMerged(Backup b) {
      expect(b.settings['lang'], 'en');
      expect(b.languages!.keys.toSet(), {'en', 'pt'});
      final en = b.languages!['en']!;
      expect(en.style, 'steady', reason: 'the language\'s own style wins');
      expect(en.held, {'steady', 'analyst'});
      expect(en.changes, 5);
      expect(en.dailyLog, {'2026-10-21': 2, '2026-10-22': 2, '2026-10-23': 0});
      expect(en.dailyBest, 5);
      final w = en.achievements['wins_10']!;
      expect(w.times, 3);
      expect(w.dates, ['2026-10-01', '2026-10-02', '2026-10-09']);
      expect(w.progress, 9);
      final pt = b.languages!['pt']!;
      expect(pt.style, 'maverick');
      expect(pt.changes, 1);
      expect(pt.dailyLog, {'2026-10-23': 1});
      expect(b.stats.mastery.keys.toSet(), {'en', 'pt'});
      expect(b.stats.mastery['en'], {'5:6', '6:6'});
      expect(b.stats.langsWon, {'en', 'pt'});
      expect(b.stats.played, 6);
      expect(b.stats.wins, 4);
      expect(b.history!.games, hasLength(6));
      expect(b.history!.games.map((g) => g.lang).toSet(), {'en', 'pt'});
    }

    test('is read as one language each', () {
      checkMerged(parseBackup(backup()));
    });

    test('the same whichever section comes first', () {
      checkMerged(parseBackup(backup(oldFirst: true)));
    });

    test('a language with only the old code is the new one', () {
      final raw = jsonDecode(backup()) as Map<String, dynamic>;
      final langs = raw['languages'] as Map;
      langs.remove('en');
      final b = parseBackup(jsonEncode(raw));
      expect(b.languages!.keys.toSet(), {'en', 'pt'});
      expect(b.languages!['en']!.style, 'analyst');
      expect(b.languages!['en']!.dailyBest, 5);
    });

    test('a backup from before each language had its own goes to en', () {
      final raw = jsonDecode(backup()) as Map<String, dynamic>;
      raw
        ..remove('languages')
        ..['playstyle'] = {
          'current': 'analyst',
          'held': ['analyst'],
        }
        ..['daily'] = {
          'log': {'2026-10-21': 1},
          'best': 1,
        };
      final b = parseBackup(jsonEncode(raw));
      expect(b.settings['lang'], 'en');
      expect(b.languages!.keys.toList(), ['en']);
      expect(b.languages!['en']!.style, 'analyst');
    });

    test(
      'restoring it works, and what is stored is one language each',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = await load();
        final b = parseBackup(backup());
        s.restore(
          settings: b.settings,
          stats: b.stats,
          ach: b.achievements,
          languages: b.languages,
          history: b.history,
        );
        await settle();

        void check(AppState s) {
          expect(s.lang, 'en');
          expect(s.stats.played, 6);
          expect(s.stats.wins, 4);
          expect(s.stats.mastery.keys.toSet(), {'en', 'pt'});
          expect(s.history.games, hasLength(6));
          expect(s.history.games.map((g) => g.lang).toSet(), {'en', 'pt'});
          expect(s.styleIdOf('en'), 'steady');
          expect(s.stylesHeldOf('en'), {'steady', 'analyst'});
          expect(s.styleChangesOf('en'), 5);
          expect(s.styleIdOf('pt'), 'maverick');
          expect(s.dailyBestOf('en'), 5);
          expect(s.dailyLogOf('en')['2026-10-22'], 2);
          expect(s.achOf('en')['wins_10']!.times, 3);
          expect(s.achOf('')['bilingual']!.progress, 2);
          expect(s.achLanguages.toSet(), {'en', 'pt'});
        }

        check(s);

        // and read from storage by the next start, with nothing to merge
        GameRow.mergedLanguageRows = 0;
        check(await load());
        expect(GameRow.mergedLanguageRows, 0);
        final p = await SharedPreferences.getInstance();
        for (final k in p.getKeys()) {
          final v = p.get(k);
          final text = v is List ? v.join('\n') : '$v';
          expect(text, isNot(contains('en-GB')), reason: k);
          expect(text, isNot(contains('pt-PT')), reason: k);
        }
      },
    );

    test('and a backup made now reads back the same', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await load();
      final b = parseBackup(backup());
      s.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
        history: b.history,
      );
      final text = backupToText(s);
      expect(text, isNot(contains('en-GB')));
      expect(text, isNot(contains('pt-PT')));
      final again = parseBackup(text);
      expect(again.languages!.keys.toSet(), containsAll(['en', 'pt']));
      expect(again.stats.played, 6);
      expect(again.history!.games, hasLength(6));
    });
  });
}
