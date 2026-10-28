import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/medal.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/history.dart';
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
    test(
      'each achievement has levels, a glyph that exists, and a medal each',
      () {
        expect(
          achievements.map((a) => a.id).toSet().length,
          achievements.length,
        );
        var levels = 0;
        for (final a in achievements) {
          expect(a.track, Track.metric, reason: a.id);
          expect(a.count, 4, reason: a.id);
          levels += a.count;
          expect(
            a.levels.map((l) => l.medal).toList(),
            Medal.values,
            reason: '${a.id} climbs from bronze to platinum',
          );
          for (final i in [for (var i = 0; i < a.count; i++) i]) {
            final icon = a.atLevel(i).icon;
            final f = File('assets/icons/$icon.svg');
            expect(f.existsSync(), isTrue, reason: '${a.id}: $icon.svg');
            expect(
              f.readAsStringSync(),
              contains('icons-tabler-filled'),
              reason: '${a.id} must use a Tabler filled glyph',
            );
          }
        }
        expect(levelCount, levels);
      },
    );

    test(
      'a level asks for more of the same: targets climb (fastest falls)',
      () {
        for (final a in achievements) {
          for (var i = 1; i < a.count; i++) {
            if (a.smaller) {
              expect(a.levels[i].target, lessThan(a.levels[i - 1].target));
            } else {
              expect(a.levels[i].target, greaterThan(a.levels[i - 1].target));
            }
          }
        }
      },
    );

    test('only the streaks show a separate icon for each level', () {
      expect(
        achievements.where((a) => a.separate).map((a) => a.metric).toList(),
        ['streak', 'streakClassic', 'streakQuartet', 'streakRelay'],
      );
      final s = byId('daily_streak');
      expect(s.atLevel(0).icon, isNot(s.atLevel(3).icon));
      expect(byId('wins').atLevel(0).icon, byId('wins').atLevel(3).icon);
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

    test('a level says what it asks', () {
      expect(byId('wins').atLevel(0).description, 'win a game');
      expect(byId('wins').atLevel(2).description, 'win 100 games');
      expect(byId('quick').atLevel(3).description, 'win on the first guess');
      expect(byId('chameleon').atLevel(3).description, contains('all 6'));
    });

    test('the ones about the quartet or the relay carry the mode', () {
      expect(byId('quartet_streak').tag, GameMode.quartet);
      expect(byId('relay_wins').tag, GameMode.relay);
      expect(byId('wins').tag, isNull);
    });
  });

  group('counting', () {
    test('a game earns every level its number has reached, in order', () {
      final (st, earned) = play([game(used: 1)]);
      expect(
        st['quick']!.times,
        4,
        reason: 'a win in one guess is every level',
      );
      expect(earned[0].where((id) => id == 'quick'), hasLength(4));
      expect(st['wins']!.times, 1);
      expect(st['quick']!.dates, hasLength(4));
    });

    test('the earned level is the one the toast shows', () {
      final states = <String, AchState>{};
      final e = advanceAchievements(states, game(used: 5), 'a');
      expect(e.map((a) => a.id), contains('wins'));
      expect(e.firstWhere((a) => a.id == 'wins').medal, Medal.bronze);
      final more = [
        for (var i = 0; i < 24; i++)
          ...advanceAchievements(states, game(used: 5), 'b$i'),
      ];
      final silver = more.firstWhere((a) => a.id == 'wins');
      expect(silver.medal, Medal.silver);
      expect(silver.description, 'win 25 games');
    });

    test('wins and games played climb the medals', () {
      final (st, earned) = play([
        for (var i = 0; i < 25; i++) game(),
        for (var i = 0; i < 4; i++) game(won: false),
      ]);
      expect(earned[24], contains('wins'));
      expect(st['wins']!.times, 2);
      expect(st['wins']!.value, 25);
      expect(st['played']!.times, 1);
      expect(st['played']!.value, 29);
    });

    test('a win streak is the best run, and a loss starts the next one', () {
      final (st, _) = play([game(), game(), game(), game(won: false), game()]);
      expect(st['streak']!.times, 1);
      expect(st['streak']!.value, 3);
      expect(st['streak']!.progress, 1);
    });

    test('the fastest win: the smaller the better', () {
      final (st, _) = play([game(used: 5), game(used: 3), game(used: 6)]);
      expect(st['quick']!.times, 2);
      expect(st['quick']!.value, 3);
    });

    test('last try: a win on the very last of four or more tries', () {
      final (st, _) = play([
        game(used: 6),
        game(used: 3, tries: 3),
        game(used: 6),
      ]);
      expect(st['last_try']!.value, 2);
      expect(st['last_try']!.times, 1);
    });

    test('skill: the best average, and the lowest guess, of a win', () {
      final (st, _) = play([
        game(skills: [91, 95, 100]),
        game(skills: [50, 99, 99], won: false),
      ]);
      expect(st['skill_avg']!.times, 4, reason: '95.3 reaches 95');
      expect(st['skill_every']!.times, 3, reason: '91 is above 60, 75, 90');
      expect(st['skill_every']!.value, 91);
    });

    test('above means above: a lowest guess of exactly 60 is not a level', () {
      final (st, _) = play([
        game(skills: [60, 80, 90]),
      ]);
      expect(st['skill_every']!.times, 0);
      final (st2, _) = play([
        game(skills: [61, 80, 90]),
      ]);
      expect(st2['skill_every']!.times, 1);
    });

    test('luck, risk and bits: the best a game had', () {
      final (st, _) = play([
        game(luck: 45, risk: 30, maxBits: 7.2),
        game(luck: 10, risk: 60, maxBits: 3),
        game(luck: 90, risk: 99, maxBits: 12.5, won: false),
      ]);
      expect(st['luck']!.times, 2);
      expect(st['risk']!.times, 3);
      expect(st['bits']!.times, 4, reason: 'a lost game still gained bits');
    });

    test('word lengths: distinct lengths won', () {
      final (st, _) = play([
        game(length: 4),
        game(length: 8),
        game(length: 8),
        game(length: 6, won: false),
      ]);
      expect(st['lengths']!.value, 2);
      expect(st['lengths']!.times, 1);
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
          containsAll(['languages', 'language_mastery']),
        );
        expect(states['languages']!.times, 1);
        expect(states['languages']!.value, 2);
        earned = advanceAchievements(
          states,
          game(),
          'b',
          counts: {'langs': 17, 'mastered': 17, 'completed': 17},
          languages: 17,
        );
        expect(states['languages']!.times, 4);
        expect(states['language_mastery']!.times, 4);
        expect(states['completionist']!.times, 4);
      },
    );

    test('playstyles: rated one, a change, all six, in one achievement', () {
      GameResult styled(String style, int held, {bool changed = false}) =>
          GameResult(
            lang: 'en',
            length: 5,
            tries: 6,
            used: 4,
            won: true,
            style: style,
            styleChanged: changed,
            stylesHeld: held,
          );
      final (st, _) = play([
        styled('analyst', 1),
        styled('maverick', 2, changed: true),
      ]);
      expect(st['chameleon']!.times, 2);
      expect(st['chameleon']!.value, 2);
      final (all, _) = play([styled('gambler', 6)]);
      expect(all['chameleon']!.times, 4);
      expect(byId('chameleon').levels[3].medal, Medal.platinum);
    });
  });

  group('earned again', () {
    test('a game that does what a level asks counts again, from the first', () {
      final (st, _) = play([
        game(used: 3),
        game(used: 4),
        game(used: 3),
        game(used: 2),
      ]);
      // levels: 4 or fewer, 3 or fewer, 2, 1
      expect(st['quick']!.hits, [4, 3, 1, 0]);
    });

    test('best-of numbers count again, count-up ones do not', () {
      expect(byId('quick').hit, isNotNull);
      expect(byId('bits').hit, isNotNull);
      expect(byId('wins').hit, isNull);
      final (st, _) = play([
        game(maxBits: 6.5),
        game(maxBits: 7),
        game(maxBits: 5),
      ]);
      expect(st['bits']!.hits.first, 2);
    });

    test('the ones that count up start again, and count the rounds', () {
      expect(byId('wins').cycles, isTrue);
      expect(byId('quick').cycles, isFalse);
      final states = <String, AchState>{};
      final earned = <String>[];
      for (var i = 0; i < 520; i++) {
        earned.addAll([
          for (final a in advanceAchievements(states, game(), 'd$i')) a.id,
        ]);
      }
      final st = states['wins']!;
      // 500 wins finish a round: 1, 25, 100 and 500, then it starts again
      expect(st.rounds, 1);
      expect(st.times, 4, reason: 'the medal stays');
      expect(st.hits[3], 1);
      expect(st.hits[0], 2, reason: 'a win, and the first of the next round');
      expect(st.value, 20);
      expect(earned.where((id) => id == 'wins').length, 5);
    });

    test('the languages count again from those already won', () {
      final states = <String, AchState>{};
      advanceAchievements(
        states,
        game(),
        'a',
        counts: {'langs': 9, 'mastered': 0, 'completed': 0},
        languages: 17,
      );
      expect(states['languages']!.rounds, 1);
      expect(states['languages']!.times, 4);
      expect(states['languages']!.base, 9);
      advanceAchievements(
        states,
        game(),
        'b',
        counts: {'langs': 11, 'mastered': 0, 'completed': 0},
        languages: 17,
      );
      expect(states['languages']!.hits[0], 2, reason: '2 more languages');
      expect(states['languages']!.value, 2);
    });

    test('a streak counts the runs that get to each level', () {
      final (st, _) = play([
        game(),
        game(),
        game(),
        game(won: false),
        game(),
        game(),
        game(),
      ]);
      expect(st['streak']!.hits.first, 2);
    });

    test('the counts are kept', () {
      final s = AchState(times: 2, hits: [5, 2, 0, 0]);
      expect(AchState.fromJson(s.toJson()).hits, [5, 2, 0, 0]);
    });
  });

  group('daily', () {
    test('a daily is counted, and double fires climb their own ladder', () {
      final (st, _) = play([
        game(daily: true, dailyStreak: 1, used: 2),
        game(daily: true, dailyStreak: 2, used: 4, skills: [70, 70, 70, 70]),
        game(daily: false),
      ]);
      expect(st['dailies']!.value, 2);
      expect(st['double_fire']!.times, 1);
      expect(st['double_fire']!.value, 1);
    });

    test('each mode has its own streak', () {
      final (st, earned) = play([
        game(daily: true, dailyStreak: 3),
        multi(GameMode.quartet, daily: true, dailyStreak: 1),
        multi(GameMode.relay, daily: true, dailyStreak: 4),
      ]);
      expect(earned[0], contains('daily_streak'));
      expect(st['quartet_streak']!.times, 0, reason: 'the quartet streak is 1');
      expect(st['relay_streak']!.times, 1);
      expect(st['relay_streak']!.value, 4);
      expect(st['daily_streak']!.value, 3);
    });

    test('a classic game does not touch a quartet streak', () {
      final (st, _) = play([game(daily: true, dailyStreak: 50)]);
      expect(st['quartet_streak']!.value, 0);
      expect(st['relay_streak']!.value, 0);
    });
  });

  group('quartet and relay race', () {
    test('quartet metrics read quartets only, relay ones relays only', () {
      final (st, _) = play([
        game(),
        multi(GameMode.quartet),
        multi(GameMode.relay, freeRides: 1),
      ]);
      expect(st['quartet_wins']!.times, 1);
      expect(st['relay_wins']!.times, 1);
      expect(st['relay_free']!.times, 1);
      expect(st['quartet_wins']!.value, 1);
    });

    test('quartet: spare tries, last try and sharp skill', () {
      final (st, _) = play([
        multi(GameMode.quartet, used: 9, tries: 9),
        multi(GameMode.quartet, used: 6, tries: 9, skills: [85, 85, 85]),
      ]);
      expect(st['quartet_last']!.times, 1);
      expect(st['quartet_spare']!.times, 1);
      expect(
        st['quartet_skill']!.times,
        2,
        reason: '85 is above 70 and 80, not above 85',
      );
    });

    test('relay race: photo finish', () {
      final (st, _) = play([multi(GameMode.relay, used: 10, tries: 10)]);
      expect(st['relay_last']!.times, 1);
    });

    test('luckiest man alive: one guess per word, in either mode', () {
      for (final mode in [GameMode.quartet, GameMode.relay]) {
        final (st, earned) = play([multi(mode, used: 4)]);
        expect(earned[0], contains('one_each'), reason: mode.name);
        expect(st['one_each']!.times, 1);
      }
      final (st, _) = play([multi(GameMode.quartet, used: 5)]);
      expect(st['one_each']!.times, 0);
    });
  });

  group('worked out again from the games kept', () {
    void add(
      History h,
      int day, {
      bool won = true,
      int guesses = 3,
      String daily = '',
    }) => h.add(
      at: DateTime.utc(2026, 10, day, 12).millisecondsSinceEpoch,
      lang: 'en',
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: const ['slate'],
      won: won,
      daily: daily,
      guesses: [
        for (var i = 0; i < guesses; i++)
          GuessRow(
            game: 0,
            n: i,
            word: 'crane',
            skill: 90,
            luck: 10,
            before: 50,
            gain: 7,
          ),
      ],
    );

    test('once, when the flag is missing, from the games kept', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      for (var d = 1; d <= 3; d++) {
        add(a.history, d, daily: '2026-10-0$d');
      }
      add(a.history, 4, won: false, guesses: 6);
      a.rebuildAchievements();
      expect(a.ach['wins']!.times, 1);
      expect(a.ach['wins']!.value, 3);
      expect(a.ach['played']!.value, 4);
      expect(a.ach['quick']!.value, 3);
      expect(
        a.ach['quick']!.times,
        2,
        reason: '3 guesses: 4 or fewer, 3 or fewer',
      );
      expect(a.ach['bits']!.times, 1, reason: '7 bits: 6 or more, not 8');
      expect(a.ach['daily_streak']!.value, 3);
      expect(a.ach['daily_streak']!.times, 1);
      expect(a.ach['wins']!.dates, ['2026-10-01']);
    });

    test('the flag is kept, and a start without it works them out', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      add(a.history, 1);
      a.saveHistory();
      a.ach = {'wins': AchState(times: 4, value: 999)};
      // flagged: left as they are
      final b = AppState();
      await b.load();
      expect(b.history.games, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('achievementsVersion'), AppState.achievementsVersion);
      // without the flag: worked out again
      await prefs.remove('achievementsVersion');
      final c = AppState();
      await c.load();
      expect(c.ach['wins']!.value, 1);
      expect(c.ach['wins']!.times, 1);
      expect(prefs.getInt('achievementsVersion'), AppState.achievementsVersion);
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
      expect(b.ach['quick']!.times, 4);
      expect(b.ach['quick']!.dates, hasLength(4));
      expect(b.ach['wins']!.value, 3);
      expect(b.stats.wins, 3);
      expect(b.unlockedCount, a.unlockedCount);
    });
  });

  group('language mastery badges', () {
    test('a badge per language, collected and kept', () {
      final states = <String, AchState>{};
      var earned = advanceAchievements(states, game(), 'd1', mastered: {'en'});
      expect([for (final a in earned) a.id], contains('mastery_badges'));
      expect(states['mastery_badges']!.seen, {'en'});
      expect(states['mastery_badges']!.times, 1);
      // nothing new, nothing earned
      earned = advanceAchievements(states, game(), 'd2', mastered: {'en'});
      expect([for (final a in earned) a.id], isNot(contains('mastery_badges')));
      // a second language is a second badge
      earned = advanceAchievements(
        states,
        game(),
        'd3',
        mastered: {'en', 'fr'},
      );
      expect([for (final a in earned) a.id], contains('mastery_badges'));
      expect(states['mastery_badges']!.seen, {'en', 'fr'});
      expect(states['mastery_badges']!.times, 2);
      expect(states['mastery_badges']!.dates, ['d1', 'd3']);
      // badges are never taken away
      advanceAchievements(states, game(), 'd4', mastered: const {});
      expect(states['mastery_badges']!.seen, {'en', 'fr'});
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
      expect([for (final a in earned) a.id], contains('mastery_badges'));
      expect(state.masteredLanguages().map((l) => l.code), ['en']);
      expect(state.lastMastered.map((l) => l.code), ['en']);
      expect(state.ach['mastery_badges']!.seen, {'en'});
    });
  });
}
