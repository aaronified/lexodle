import 'package:flutter_test/flutter_test.dart';
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
}) => GameResult(
  lang: 'en',
  length: 5,
  tries: tries,
  used: used,
  won: won,
  mode: mode,
  freeRides: freeRides,
  skills: skills,
);

GameResult game({
  bool won = true,
  int used = 3,
  int tries = 6,
  int length = 5,
  String lang = 'en',
  int pool = 1500,
  List<double> skills = const [80, 80, 80],
}) => GameResult(
  lang: lang,
  length: length,
  tries: tries,
  used: used,
  won: won,
  pool: pool,
  skills: skills,
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

  group('events', () {
    test('first light is earned once only', () {
      final (st, earned) = play([game(), game(), game()]);
      expect(earned[0], contains('first_light'));
      expect(earned[1], isNot(contains('first_light')));
      expect(st['first_light']!.times, 1);
    });

    test('other events can be earned again, and every time is counted', () {
      final (st, _) = play([game(used: 1), game(used: 4), game(used: 1)]);
      expect(st['one_shot']!.times, 2);
      expect(st['one_shot']!.dates, ['day-0', 'day-2']);
      expect(st['one_shot']!.first, 'day-0');
      expect(st['one_shot']!.latest, 'day-2');
    });

    test('last breath needs a last-try win with 4+ tries', () {
      expect(byId('last_breath').qualifies(game(used: 3, tries: 3)), isFalse);
      expect(byId('last_breath').qualifies(game(used: 6, tries: 6)), isTrue);
    });
  });

  group('pure skill and skill issue', () {
    test('pure skill: every guess above 90, and the game won', () {
      final pure = byId('pure_skill');
      expect(pure.qualifies(game(skills: [96.9, 94.9, 100])), isTrue);
      expect(pure.qualifies(game(skills: [96, 89.9, 100])), isFalse);
      expect(pure.qualifies(game(skills: [90, 100])), isFalse); // above, not at
      expect(
        pure.qualifies(game(won: false, skills: [99, 99, 99])),
        isFalse,
        reason: 'a loss is not perfect play',
      );
      expect(pure.qualifies(game(skills: const [])), isFalse);
    });

    test(
      'skill issue: ten wins with every guess above 95, then again from 0',
      () {
        final good = game(skills: [97, 96, 100]);
        final nearly = game(skills: [97, 94.9, 100]); // one guess under 95
        final (st, earned) = play([
          for (var i = 0; i < 9; i++) good,
          nearly, // does not count
          good, // the tenth
          good, // the first of the next ten
        ]);
        expect(earned[8], isNot(contains('skill_issue')));
        expect(earned[9], isNot(contains('skill_issue')));
        expect(earned[10], contains('skill_issue'));
        expect(st['skill_issue']!.times, 1);
        expect(st['skill_issue']!.progress, 1); // restarted from 0, one in
      },
    );
  });

  group('numbered achievements restart from 0 once earned', () {
    test('regular: 10 wins, then 10 more for the second time', () {
      final (st, earned) = play([for (var i = 0; i < 20; i++) game()]);
      expect(
        [for (var i = 0; i < 20; i++) earned[i].contains('wins_10')],
        [for (var i = 0; i < 20; i++) i == 9 || i == 19],
      );
      expect(st['wins_10']!.times, 2);
      expect(st['wins_10']!.progress, 0);
      expect(st['wins_10']!.dates, ['day-9', 'day-19']);
    });

    test('persistent counts losses too', () {
      final (st, _) = play([for (var i = 0; i < 24; i++) game(won: i.isEven)]);
      expect(st['played_25']!.progress, 24);
      expect(st['played_25']!.times, 0);
    });

    test('three in a row: a loss starts the count again', () {
      final (st, earned) = play([
        game(), game(), game(won: false), game(), game(), // 2, loss, 2
        game(), // the third in a row since the loss
      ]);
      expect(earned[4], isNot(contains('streak_3')));
      expect(earned[5], contains('streak_3'));
      expect(st['streak_3']!.progress, 0);
      expect(st['streak_7']!.progress, 3);
    });

    test('polyglot: distinct languages won in, then the set is cleared', () {
      final (st, earned) = play([
        game(lang: 'en'),
        game(lang: 'en'), // same language: no progress
        game(lang: 'fr'),
        game(lang: 'de'),
        game(lang: 'en'), // starts the next round
      ]);
      expect(earned[3], contains('polyglot_3'));
      expect(st['polyglot_3']!.times, 1);
      expect(st['polyglot_3']!.progress, 1);
      expect(st['polyglot_3']!.seen, {'en'});
    });

    test('bilingual: two languages', () {
      final (_, earned) = play([
        game(lang: 'en'),
        game(lang: 'en'),
        game(lang: 'fr'),
      ]);
      expect(earned[1], isNot(contains('bilingual')));
      expect(earned[2], contains('bilingual'));
    });

    test(
      'mastery counts each length, tries level and pool once, wins only',
      () {
        final s = Stats()
          ..record(game())
          ..record(game()) // the same setting again
          ..record(game(length: 6))
          ..record(game(tries: 3, pool: 500))
          ..record(game(won: false, length: 7))
          ..record(game(tries: 5)) // not a level of the matrix
          ..record(game(pool: 1234)) // nor is this pool
          ..record(game(lang: 'fr'));
        expect(s.mastery['en'], {'5:6:1500', '6:6:1500', '5:3:500'});
        expect(s.mastery['fr'], {'5:6:1500'});
        expect(
          Stats.fromJson(s.toJson()).mastery['en'],
          s.mastery['en'],
          reason: 'mastery survives a restart',
        );
      },
    );

    test('full range: lengths 4 to 8', () {
      final (st, earned) = play([
        for (final n in [4, 5, 6, 7, 8]) game(length: n),
      ]);
      expect(earned.last, contains('full_range'));
      expect(st['full_range']!.progress, 0);
    });

    test('a loss does not count towards languages or lengths', () {
      final (st, _) = play([game(won: false, lang: 'fr', length: 7)]);
      expect(st['polyglot_3']!.progress, 0);
      expect(st['full_range']!.progress, 0);
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
      expect(b.ach['wins_10']!.progress, 3);
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

  group('quartet and relay race', () {
    test('each mode has its own achievements; classic ones ignore them', () {
      final (_, earned) = play([multi(GameMode.quartet)]);
      expect(earned.single, contains('quartet_win'));
      expect(earned.single, isNot(contains('relay_win')));
      // a single-word achievement does not count a quartet win
      expect(earned.single, isNot(contains('one_shot')));
      expect(earned.single, isNot(contains('pure_skill')));
      // but a general one does: a win is a win
      expect(earned.single, contains('first_light'));
    });

    test('quartet: spare tries, last try and sharp skill', () {
      final (_, e1) = play([multi(GameMode.quartet, used: 6, tries: 9)]);
      expect(e1.single, contains('quartet_spare'));
      final (_, e2) = play([multi(GameMode.quartet, used: 9, tries: 9)]);
      expect(e2.single, contains('quartet_last'));
      expect(e2.single, isNot(contains('quartet_spare')));
      final (_, e3) = play([
        multi(GameMode.quartet, skills: [70, 80]),
      ]);
      expect(e3.single, isNot(contains('quartet_sharp')), reason: 'avg 75');
      final (_, e4) = play([
        multi(GameMode.quartet, skills: [90, 85]),
      ]);
      expect(e4.single, contains('quartet_sharp'));
    });

    test('relay race: free ride, photo finish, and ten wins', () {
      final (_, e1) = play([multi(GameMode.relay, freeRides: 1)]);
      expect(e1.single, contains('relay_free'));
      final (_, e2) = play([multi(GameMode.relay, used: 10, tries: 10)]);
      expect(e2.single, contains('relay_last'));
      final (st, earned) = play([
        for (var i = 0; i < 10; i++) multi(GameMode.relay),
      ]);
      expect(earned.last, contains('relay_10'));
      expect(st['quartet_10']!.progress, 0, reason: 'other mode untouched');
    });

    test(
      'a loss does not count, and a quartet leaves relay counters alone',
      () {
        final (st, _) = play([
          multi(GameMode.quartet, won: false),
          multi(GameMode.quartet),
        ]);
        expect(st['quartet_10']!.progress, 1);
        expect(st['relay_10']!.progress, 0);
      },
    );

    test('a game of another mode neither counts nor breaks a streak', () {
      // wins 3 in a row across modes: streaks are general
      final (_, earned) = play([
        game(),
        multi(GameMode.quartet),
        multi(GameMode.relay),
      ]);
      expect(earned.last, contains('streak_3'));
    });

    test('luckiest man alive: one guess per word, in either mode', () {
      // a quartet takes at least 4 guesses; 5 is not enough
      final (_, e0) = play([multi(GameMode.quartet, used: 5)]);
      expect(e0.single, isNot(contains('luckiest')));
      // 4 in a quartet is the least it can take: that is the achievement
      final (_, e1) = play([multi(GameMode.quartet, used: 4)]);
      expect(e1.single, contains('luckiest'));
      // a relay race in 4 or fewer is too (a free ride can save a guess)
      final (_, e2) = play([multi(GameMode.relay, used: 4)]);
      expect(e2.single, contains('luckiest'));
      final (_, e3) = play([multi(GameMode.relay, used: 3)]);
      expect(e3.single, contains('luckiest'));
      // a relay race in 5 is not
      final (_, e4) = play([multi(GameMode.relay, used: 5)]);
      expect(e4.single, isNot(contains('luckiest')));
      // it has to be won
      final (_, e5) = play([multi(GameMode.quartet, used: 4, won: false)]);
      expect(e5.single, isNot(contains('luckiest')));
      // a classic game is no part of it, even a first-guess win
      final (_, e6) = play([game(used: 1)]);
      expect(e6.single, isNot(contains('luckiest')));
      // and it can be earned again
      final (st, _) = play([
        multi(GameMode.quartet, used: 4),
        multi(GameMode.relay, used: 4),
      ]);
      expect(st['luckiest']!.times, 2);
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

    test('mastery has no progress bar of its own, it is a collection', () {
      expect(byId('mastery').numbered, isFalse);
      expect(byId('mastery').track, Track.badges);
    });

    test('the game that completes a language earns its badge', () async {
      SharedPreferences.setMockInitialValues({});
      final langs = await WordBank.languages();
      final en = langs.firstWhere((l) => l.code == 'en');
      final state = AppState();
      final cells = {
        for (final len in en.lengths)
          for (final t in triesLevels)
            for (final p in poolSizes) '$len:${t.$2}:$p',
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
          pool: parts[2],
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
          pool: parts[2],
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
