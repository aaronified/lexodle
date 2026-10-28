import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/medal.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameResult multi(
  GameMode mode, {
  bool won = true,
  int used = 7,
  int tries = 9,
  int freeRides = 0,
  List<double> skills = const [85, 85, 85],
  bool daily = false,
  int dailyStreak = 0,
}) => GameResult(
  lang: 'en',
  length: 5,
  tries: tries,
  used: used,
  won: won,
  mode: mode,
  freeRides: freeRides,
  skills: skills,
  daily: daily,
  dailyStreak: dailyStreak,
);

GameResult game({
  bool won = true,
  int used = 3,
  int tries = 6,
  int length = 5,
  String lang = 'en',
  List<double> skills = const [80, 80, 80],
  double? luck,
  double? risk,
  double maxBits = 0,
  bool daily = false,
  int dailyStreak = 0,
}) => GameResult(
  lang: lang,
  length: length,
  tries: tries,
  used: used,
  won: won,
  skills: skills,
  luck: luck,
  risk: risk,
  maxBits: maxBits,
  daily: daily,
  dailyStreak: dailyStreak,
);

Achievement byId(String id) => achievements.firstWhere((a) => a.id == id);

/// Plays [games] in order against fresh state; returns the state and, per
/// game, the ids it earned.
(Map<String, AchState>, List<List<String>>) play(List<GameResult> games) {
  final states = <String, AchState>{};
  final earned = [
    for (var i = 0; i < games.length; i++)
      [for (final a in advanceAchievements(states, games[i], 'day-$i')) a.id],
  ];
  return (states, earned);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stats: a loss resets the streak, the best is kept', () {
    final s = Stats()
      ..record(game())
      ..record(game())
      ..record(game(won: false));
    expect(s.streak, 0);
    expect(s.bestStreak, 2);
  });

  group('the list', () {
    test('there are 97, each with a medal and a glyph that exists', () {
      expect(achievements.length, 97);
      expect(achievements.map((a) => a.id).toSet().length, 97);
      for (final a in achievements) {
        final f = File('assets/icons/${a.icon}.svg');
        expect(f.existsSync(), isTrue, reason: '${a.id}: ${a.icon}.svg');
        expect(
          f.readAsStringSync(),
          contains('icons-tabler-filled'),
          reason: '${a.id} must use a Tabler filled glyph',
        );
        expect(a.track, Track.metric, reason: a.id);
      }
    });

    test('every medal has some, and a family climbs from bronze', () {
      for (final m in Medal.values) {
        expect(achievements.where((a) => a.medal == m), isNotEmpty);
      }
      final byMetric = <String, List<Achievement>>{};
      for (final a in achievements) {
        (byMetric[a.metric] ??= []).add(a);
      }
      for (final e in byMetric.entries) {
        final rungs = [...e.value]
          ..sort(
            (x, y) => x.smaller
                ? y.target.compareTo(x.target)
                : x.target.compareTo(y.target),
          );
        for (var i = 1; i < rungs.length; i++) {
          expect(
            rungs[i].medal.index,
            greaterThanOrEqualTo(rungs[i - 1].medal.index),
            reason: '${e.key}: ${rungs[i].id}',
          );
        }
      }
    });

    test('every metric an achievement reads is kept, or counts languages', () {
      for (final a in achievements) {
        expect(
          metrics.containsKey(a.metric) ||
              const {'langs', 'mastered', 'completed'}.contains(a.metric),
          isTrue,
          reason: '${a.id}: ${a.metric}',
        );
      }
    });

    test('the ones about the quartet or the relay carry the mode', () {
      expect(byId('dq_3').tag, GameMode.quartet);
      expect(byId('relay_win').tag, GameMode.relay);
      expect(byId('wins_25').tag, isNull);
    });
  });

  group('counting', () {
    test('first light is earned once only', () {
      final (st, earned) = play([game(), game(), game()]);
      expect(earned[0], contains('first_light'));
      expect(earned[1], isNot(contains('first_light')));
      expect(st['first_light']!.times, 1);
    });

    test('wins and games played climb the medals', () {
      final (st, earned) = play([
        for (var i = 0; i < 25; i++) game(),
        for (var i = 0; i < 4; i++) game(won: false),
      ]);
      expect(earned[24], contains('wins_25'));
      expect(st['wins_25']!.times, 1);
      expect(st['wins_25']!.value, 25);
      expect(st['wins_100']!.value, 25);
      expect(st['played_10']!.times, 1);
      expect(st['played_50']!.times, 0);
      expect(st['played_50']!.value, 29);
    });

    test('a streak is the best run, and a loss starts the next one', () {
      final (st, _) = play([game(), game(), game(), game(won: false), game()]);
      expect(st['streak_3']!.times, 1);
      expect(st['streak_3']!.value, 3);
      expect(st['streak_3']!.progress, 1);
      expect(st['streak_7']!.times, 0);
    });

    test('the fastest win: the smaller the better, and a rung is earned', () {
      final (st, earned) = play([game(used: 5), game(used: 3), game(used: 6)]);
      expect(st['quick_4']!.times, 1);
      expect(st['quick_3']!.times, 1);
      expect(st['quick_2']!.times, 0);
      expect(earned[1], containsAll(['quick_4', 'quick_3']));
      expect(st['quick_3']!.value, 3);
    });

    test('a win that does it again is counted again, once earned', () {
      final (st, _) = play([game(used: 1), game(used: 4), game(used: 1)]);
      expect(st['one_shot']!.times, 2);
      expect(st['one_shot']!.dates, ['day-0', 'day-2']);
      expect(st['quick_4']!.times, 3, reason: 'a one shot is a win in 4 too');
      expect(st['quick_3']!.times, 2);
    });

    test('last try: a win on the very last of four or more tries', () {
      final (st, _) = play([
        game(used: 6),
        game(used: 3, tries: 3),
        game(used: 6),
      ]);
      expect(st['last_1']!.times, 2);
      expect(st['last_10']!.value, 2);
    });

    test('skill: the best average, and the lowest guess, of a win', () {
      final (st, _) = play([
        game(skills: [91, 95, 100]),
        game(skills: [50, 99, 99], won: false),
      ]);
      expect(st['skillavg_90']!.times, 1);
      expect(st['skillavg_95']!.times, 1);
      expect(st['every_75']!.times, 1);
      expect(st['every_90']!.times, 1);
      expect(st['every_90']!.value, 91, reason: 'the lost game does not count');
    });

    test(
      'above means above: a lowest guess of exactly 60 is not a no slip',
      () {
        final (st, _) = play([
          game(skills: [60, 80, 90]),
        ]);
        expect(st['every_60']!.times, 0);
        final (st2, _) = play([
          game(skills: [61, 80, 90]),
        ]);
        expect(st2['every_60']!.times, 1);
      },
    );

    test('skill issue: ten wins with every guess above 95', () {
      final (st, earned) = play([
        for (var i = 0; i < 10; i++) game(skills: [96, 97, 99]),
      ]);
      expect(earned[9], contains('skill_issue'));
      expect(st['skill_issue']!.times, 1);
    });

    test('luck, risk and bits: the best a game had', () {
      final (st, _) = play([
        game(luck: 45, risk: 30, maxBits: 7.2),
        game(luck: 10, risk: 60, maxBits: 3),
        game(luck: 90, risk: 99, maxBits: 12.5, won: false),
      ]);
      expect(st['luck_20']!.times, 1);
      expect(st['luck_40']!.times, 1);
      expect(st['luck_60']!.times, 0, reason: 'a lost game has no luck medal');
      expect(st['risk_55']!.times, 1);
      expect(st['risk_70']!.times, 0);
      expect(st['bits_6']!.times, 1);
      expect(st['bits_12']!.times, 1, reason: 'a lost game still gained bits');
    });

    test('lengths: distinct lengths won, and 4 and 8 on their own', () {
      final (st, _) = play([
        game(length: 4),
        game(length: 8),
        game(length: 8),
        game(length: 6, won: false),
      ]);
      expect(st['brevity']!.times, 1);
      expect(st['long_haul']!.times, 1);
      expect(st['full_range']!.value, 2);
      expect(st['full_range']!.times, 0);
    });

    test(
      'the languages are counted by the app, and "every" is all of them',
      () {
        final states = <String, AchState>{};
        var earned = advanceAchievements(
          states,
          game(),
          'a',
          counts: {'langs': 2, 'mastered': 1, 'completed': 0},
          languages: 17,
        );
        expect(
          earned.map((a) => a.id),
          containsAll(['bilingual', 'mastery_1']),
        );
        expect(states['polyglot_3']!.times, 0);
        expect(states['polyglot_3']!.value, 2);
        earned = advanceAchievements(
          states,
          game(),
          'b',
          counts: {'langs': 17, 'mastered': 17, 'completed': 17},
          languages: 17,
        );
        expect(
          earned.map((a) => a.id),
          containsAll(['polyglot_9', 'mastery_all', 'tower_of_babel']),
        );
      },
    );

    test('the playstyles: rated once each, a change, and all six', () {
      final (st, _) = play([
        GameResult(
          lang: 'en',
          length: 5,
          tries: 6,
          used: 4,
          won: true,
          style: 'analyst',
          stylesHeld: 1,
        ),
        GameResult(
          lang: 'en',
          length: 5,
          tries: 6,
          used: 4,
          won: true,
          style: 'maverick',
          styleChanged: true,
          stylesHeld: 2,
        ),
      ]);
      expect(st['style_analyst']!.times, 1);
      expect(st['style_maverick']!.times, 1);
      expect(st['style_gambler']!.times, 0);
      expect(st['chameleon']!.times, 1);
      expect(st['many_hats']!.value, 2);
      expect(st['many_hats']!.times, 0);
    });
  });

  group('daily', () {
    test('a daily is counted, and double fires by their own ladder', () {
      final (st, _) = play([
        game(daily: true, dailyStreak: 1, used: 2),
        game(daily: true, dailyStreak: 2, used: 4, skills: [70, 70, 70, 70]),
        game(daily: false),
      ]);
      expect(st['dailies_5']!.value, 2);
      expect(st['double_1']!.times, 1);
      expect(st['double_10']!.value, 1);
    });

    test('each mode has its own streak ladder', () {
      final (st, earned) = play([
        game(daily: true, dailyStreak: 3),
        multi(GameMode.quartet, daily: true, dailyStreak: 1),
        multi(GameMode.relay, daily: true, dailyStreak: 4),
      ]);
      expect(earned[0], contains('daily_3'));
      expect(st['dq_3']!.times, 0, reason: 'the quartet streak is 1');
      expect(st['dr_3']!.times, 1);
      expect(st['dr_3']!.value, 4);
      expect(st['daily_3']!.value, 3);
    });

    test('a classic game does not touch a quartet streak', () {
      final (st, _) = play([game(daily: true, dailyStreak: 50)]);
      expect(st['dq_3']!.value, 0);
      expect(st['dr_3']!.value, 0);
    });
  });

  group('quartet and relay race', () {
    test('quartet metrics read quartets only, relay ones relays only', () {
      final (st, _) = play([
        game(),
        multi(GameMode.quartet),
        multi(GameMode.relay, freeRides: 1),
      ]);
      expect(st['quartet_win']!.times, 1);
      expect(st['relay_win']!.times, 1);
      expect(st['relay_free']!.times, 1);
      expect(st['quartet_10']!.value, 1);
      expect(st['relay_10']!.value, 1);
    });

    test('quartet: spare tries, last try and sharp skill', () {
      final (st, _) = play([
        multi(GameMode.quartet, used: 9, tries: 9),
        multi(GameMode.quartet, used: 6, tries: 9, skills: [85, 85, 85]),
      ]);
      expect(st['quartet_last']!.times, 1);
      expect(st['quartet_spare']!.times, 1);
      expect(st['quartet_sharp']!.times, 1);
    });

    test('relay race: photo finish', () {
      final (st, _) = play([multi(GameMode.relay, used: 10, tries: 10)]);
      expect(st['relay_last']!.times, 1);
    });

    test('luckiest man alive: one guess per word, in either mode', () {
      for (final mode in [GameMode.quartet, GameMode.relay]) {
        final (st, earned) = play([multi(mode, used: 4)]);
        expect(earned[0], contains('luckiest'), reason: mode.name);
        expect(st['luckiest']!.times, 1);
      }
      final (st, _) = play([multi(GameMode.quartet, used: 5)]);
      expect(st['luckiest']!.times, 0);
    });
  });

  group('storage', () {
    test('everything survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      for (var i = 0; i < 3; i++) {
        a.recordGame(game(used: 1, skills: [98, 100]));
      }
      final b = AppState();
      await b.load();
      expect(b.ach['one_shot']!.times, 3);
      expect(b.ach['one_shot']!.dates, hasLength(3));
      expect(b.ach['wins_25']!.value, 3);
      expect(b.stats.wins, 3);
      expect(b.unlockedCount, a.unlockedCount);
    });

    test('achievements saved by the earlier version are kept', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked': '{"first_light":"2026-10-01","one_shot":"2026-10-02"}',
      });
      final a = AppState();
      await a.load();
      expect(a.ach['first_light']!.times, 1);
      expect(a.ach['first_light']!.dates, ['2026-10-01']);
      expect(a.ach['one_shot']!.latest, '2026-10-02');
      expect(a.unlockedCount, 2);
    });
  });

  group('language mastery badges', () {
    test('a badge per language, collected and kept', () {
      final states = <String, AchState>{};
      var earned = advanceAchievements(states, game(), 'd1', mastered: {'en'});
      expect([for (final a in earned) a.id], contains('mastery'));
      expect(states['mastery']!.seen, {'en'});
      expect(states['mastery']!.times, 1);
      // nothing new, nothing earned
      earned = advanceAchievements(states, game(), 'd2', mastered: {'en'});
      expect([for (final a in earned) a.id], isNot(contains('mastery')));
      // a second language is a second badge
      earned = advanceAchievements(
        states,
        game(),
        'd3',
        mastered: {'en', 'fr'},
      );
      expect([for (final a in earned) a.id], contains('mastery'));
      expect(states['mastery']!.seen, {'en', 'fr'});
      expect(states['mastery']!.times, 2);
      expect(states['mastery']!.dates, ['d1', 'd3']);
      // badges are never taken away
      advanceAchievements(states, game(), 'd4', mastered: const {});
      expect(states['mastery']!.seen, {'en', 'fr'});
    });

    test(
      'a win at a setting the language does not offer does not count',
      () async {
        final langs = await WordBank.languages();
        final id = langs.firstWhere((l) => l.code == 'id');
        expect(masteryWon(id, null), 0);
        final cells = {
          '5:6', // offered
          '5:3', // offered
          '9:6', // a length it does not have
          '5:2', // not a tries level
          'junk',
        };
        expect(masteryWon(id, cells), 2);
      },
    );

    test(
      'the target is every length at every tries level, nothing else',
      () async {
        final langs = await WordBank.languages();
        for (final l in langs) {
          expect(
            masteryTarget(l),
            l.lengths.length * triesLevels.length,
            reason: l.code,
          );
          // winning at every cell of the matrix is the whole target
          final all = {
            for (final len in l.lengths)
              for (final t in triesLevels) '$len:${t.$2}',
          };
          expect(masteryWon(l, all), masteryTarget(l), reason: l.code);
        }
      },
    );

    test('mastery has no progress bar of its own, it is a collection', () {
      expect(collectors.first.numbered, isFalse);
      expect(collectors.first.track, Track.badges);
    });

    test('the game that completes a language earns its badge', () async {
      SharedPreferences.setMockInitialValues({});
      final langs = await WordBank.languages();
      final en = langs.firstWhere((l) => l.code == 'en');
      final state = AppState();
      // every length at every tries level
      final cells = {
        for (final len in en.lengths)
          for (final t in triesLevels) '$len:${t.$2}',
      };
      expect(cells.length, masteryTarget(en));
      // every setting but the last one
      final last = cells.last;
      state.stats.mastery['en'] = cells.difference({last});
      expect(state.masteredLanguages(), isEmpty);
      final parts = last.split(':').map(int.parse).toList();
      // a quartet win at the same numbers does not count
      state.recordGame(
        GameResult(
          lang: 'en',
          length: parts[0],
          tries: parts[1],
          used: 3,
          won: true,
          mode: GameMode.quartet,
        ),
      );
      expect(state.stats.mastery['en']!.length, cells.length - 1);
      // the classic win does
      final earned = state.recordGame(
        GameResult(
          lang: 'en',
          length: parts[0],
          tries: parts[1],
          used: 3,
          won: true,
        ),
      );
      expect([for (final a in earned) a.id], contains('mastery'));
      expect(state.masteredLanguages().map((l) => l.code), ['en']);
      expect(state.lastMastered.map((l) => l.code), ['en']);
      expect(state.ach['mastery']!.seen, {'en'});
    });
  });
}
