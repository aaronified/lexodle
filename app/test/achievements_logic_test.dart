import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameResult game({
  bool won = true,
  int used = 3,
  int tries = 6,
  int length = 5,
  String lang = 'en',
  List<double> skills = const [80, 80, 80],
}) => GameResult(
  lang: lang,
  length: length,
  tries: tries,
  used: used,
  won: won,
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
}
