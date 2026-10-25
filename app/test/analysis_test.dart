import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle.dart';

/// A time on a local day (noon, so it is the same day in every time zone).
int noon(String date) {
  final d = DateTime.parse(date);
  return DateTime(d.year, d.month, d.day, 12).toUtc().millisecondsSinceEpoch;
}

/// A game on [date] with [guesses] guesses each scored as given.
GameRow play(
  History h,
  String date, {
  bool won = true,
  GameMode mode = GameMode.classic,
  int guesses = 3,
  double skill = 70,
  double luck = 0,
  double? daring = 40,
  int before = 50,
  int version = metricsVersion,
}) {
  final row = h.add(
    at: noon(date),
    lang: 'en',
    mode: mode,
    length: 5,
    tries: 6,
    pool: 3000,
    answers: mode.multi ? ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'] : ['slate'],
    won: won,
    guesses: [
      for (var i = 0; i < guesses; i++)
        GuessRow(
          game: 0,
          n: i,
          word: 'crane',
          skill: skill,
          luck: luck,
          daring: mode.multi ? null : daring,
          before: mode.multi ? 0 : before,
        ),
    ],
  );
  if (version != metricsVersion) {
    h.games[h.games.indexWhere((g) => g.id == row.id)] = row.withVersion(
      version,
    );
  }
  return row;
}

void main() {
  const today = '2026-10-24'; // a Saturday

  group('adding games up', () {
    test('wins, tries to win, and the means of skill, luck and daring', () {
      final h = History();
      play(h, today, skill: 60, luck: -20, daring: 10, guesses: 4);
      play(h, today, skill: 80, luck: 40, daring: 30, guesses: 2);
      play(h, today, won: false, skill: 70, luck: 0, daring: 20, guesses: 6);
      final s = summarise(h, h.games);
      expect(s.games, 3);
      expect(s.won, 2);
      expect(s.winRate, closeTo(66.67, .01));
      expect(s.classic, 3);
      expect(s.scored, 12);
      // each guess counts once, so a game of six weighs more than a game of two
      expect(s.skill, closeTo((4 * 60 + 2 * 80 + 6 * 70) / 12, 1e-9));
      expect(s.luck, closeTo((4 * -20 + 2 * 40 + 0) / 12, 1e-9));
      expect(s.daring, closeTo((4 * 10 + 2 * 30 + 6 * 20) / 12, 1e-9));
      expect(s.meanTries, 3, reason: 'the two wins took 4 and 2');
      expect(s.stale, 0);
    });

    test('nothing at all adds up to nothing, not to zeros that look real', () {
      final s = summarise(History(), const []);
      expect(s.isEmpty, isTrue);
      expect(s.games, 0);
      expect(s.winRate, 0);
      expect(s.daring, isNull);
      expect(s.meanTries, isNull);
      expect(PeriodSeries.skill.of(s), isNull);
      expect(PeriodSeries.luck.plot(s), isNull);
    });

    test(
      'a guess with one word left has nothing to choose, so it is left out',
      () {
        final h = History();
        play(h, today, skill: 50, daring: 30, before: 40);
        play(h, today, skill: 100, daring: 0, before: 1);
        final s = summarise(h, h.games);
        expect(s.scored, 3);
        expect(s.skill, 50);
        expect(s.daring, 30);
      },
    );

    test('a quartet counts every step, and has no daring', () {
      final h = History();
      play(h, today, mode: GameMode.quartet, skill: 60, luck: 10, guesses: 4);
      final s = summarise(h, h.games);
      expect(s.classic, 0);
      expect(s.scored, 4);
      expect(s.skill, 60);
      expect(s.luck, 10);
      expect(s.daring, isNull);
    });

    test(
      'a game scored with older maths counts as played, not in the means',
      () {
        final h = History();
        play(h, today, skill: 90, luck: 10, daring: 20, guesses: 2);
        play(
          h,
          today,
          skill: 10,
          luck: -90,
          daring: 90,
          guesses: 2,
          version: 0,
        );
        final s = summarise(h, h.games);
        expect(s.games, 2);
        expect(s.won, 2);
        expect(s.stale, 1);
        expect(s.scored, 2);
        expect(s.skill, 90);
        expect(s.luck, 10);
        expect(s.daring, 20);
      },
    );

    test(
      'only games scored with the current maths can be a period\'s style',
      () {
        final h = History();
        for (var i = 0; i < 12; i++) {
          play(
            h,
            today,
            skill: 95,
            daring: 10,
            version: i < 6 ? 0 : metricsVersion,
          );
        }
        // six are stale, six current: not enough to rate
        final last = weeklyPeriods(h, today).last;
        expect(last.stats.games, 12);
        expect(last.style, isNull);
      },
    );
  });

  group('the three lines', () {
    PlayStats stats({
      double skill = 70,
      double luck = 0,
      double? daring = 40,
    }) => PlayStats(
      games: 1,
      won: 1,
      classic: 1,
      scored: 3,
      skill: skill,
      luck: luck,
      daring: daring,
    );

    test('the expected guesses come from skill, luck and daring', () {
      final good = stats(skill: 95, luck: 0, daring: daringTypical);
      final bad = stats(skill: 40, luck: 0, daring: daringTypical);
      final b = guessBreakdown(good)!;
      // a typical daring adds nothing, and skill only takes guesses off
      expect(b.daring, closeTo(0, 1e-9));
      expect(b.skill, lessThan(0));
      expect(b.luck, closeTo(0, 1e-9));
      expect(b.total, closeTo(b.base + b.skill, 1e-9));
      expect(b.total, lessThan(guessBreakdown(bad)!.total));
      // luck takes guesses off when good and adds them when bad
      expect(guessBreakdown(stats(luck: 40))!.luck, lessThan(0));
      expect(guessBreakdown(stats(luck: -40))!.luck, greaterThan(0));
      // daring below the typical level adds, above takes off
      expect(guessBreakdown(stats(daring: 0))!.daring, greaterThan(0));
      expect(guessBreakdown(stats(daring: 30))!.daring, lessThan(0));
      // it stays within what a game can take, and is plotted 1 to 7
      expect(
        guessBreakdown(stats(skill: 100, luck: 100, daring: 100))!.total,
        1,
      );
      expect(
        PeriodSeries.guesses.plot(stats(skill: 0, luck: -100, daring: 0)),
        100,
      );
      expect(guessBreakdown(stats(daring: null)), isNull);
    });

    test('each has a name, and skill and daring are drawn as they are', () {
      expect(PeriodSeries.values.map((s) => s.label), [
        'skill',
        'luck',
        'daring',
        'guesses',
      ]);
      expect(PeriodSeries.skill.plot(stats(skill: 83)), 83);
      expect(PeriodSeries.daring.plot(stats(daring: 12)), 12);
    });

    test('luck is drawn about the middle, so that 50 is a luck of 0%', () {
      expect(PeriodSeries.luck.of(stats(luck: -40)), -40);
      expect(PeriodSeries.luck.plot(stats(luck: 0)), 50);
      expect(PeriodSeries.luck.plot(stats(luck: 100)), 100);
      expect(PeriodSeries.luck.plot(stats(luck: -100)), 0);
      expect(PeriodSeries.luck.plot(stats(luck: 40)), 70);
    });

    test('a line has no value where there is nothing to show', () {
      expect(PeriodSeries.daring.of(stats(daring: null)), isNull);
      const unscored = PlayStats(games: 2, won: 2);
      expect(PeriodSeries.skill.of(unscored), isNull);
      expect(PeriodSeries.luck.plot(unscored), isNull);
    });
  });

  group('the last 50 weeks', () {
    test('there are 50, oldest first, the last ending today', () {
      final w = weeklyPeriods(History(), today);
      expect(w.length, 50);
      expect(w.last.end, today);
      expect(w.last.start, '2026-10-18');
      expect(w.last.label, today);
      expect(w[48].end, '2026-10-17');
      expect(w[48].start, '2026-10-11');
      expect(w.first.end, dailyShift(today, -49 * 7));
      expect(w.first.start, dailyShift(today, -49 * 7 - 6));
      // seven days each, none overlapping, none missing
      for (var i = 1; i < w.length; i++) {
        expect(dailyShift(w[i - 1].end, 1), w[i].start, reason: 'week $i');
      }
      expect(w.every((p) => p.stats.isEmpty), isTrue);
    });

    test('a game goes in the week of its day', () {
      final h = History();
      play(h, today); // today: the last week
      play(h, '2026-10-18'); // six days ago: still the last
      play(h, '2026-10-17'); // seven days ago: the week before
      play(h, '2026-10-11'); // thirteen days ago: that week's first day
      play(h, '2026-10-10'); // fourteen days ago: the week before that
      final w = weeklyPeriods(h, today);
      expect(w.last.stats.games, 2);
      expect(w[48].stats.games, 2);
      expect(w[47].stats.games, 1);
      expect(w.fold<int>(0, (a, p) => a + p.stats.games), 5);
    });

    test('a week with no games is there, and empty', () {
      final h = History();
      play(h, today);
      play(h, '2026-09-26'); // four weeks back
      final w = weeklyPeriods(h, today);
      expect(w.length, 50);
      expect(w[49].stats.games, 1);
      for (var i = 46; i < 49; i++) {
        expect(w[i].stats.isEmpty, isTrue, reason: 'week $i');
      }
      expect(w[45].stats.games, 1);
    });

    test(
      'games older than 50 weeks are not in them, but are in the overall',
      () {
        final h = History();
        play(h, today);
        play(h, dailyShift(today, -49 * 7)); // the first week
        play(h, dailyShift(today, -50 * 7)); // just outside
        play(h, '2020-01-01');
        final w = weeklyPeriods(h, today);
        expect(w.first.stats.games, 1);
        expect(w.fold<int>(0, (a, p) => a + p.stats.games), 2);
        expect(summarise(h, h.games).games, 4);
      },
    );

    test('a game dated after today (a clock that was wrong) is counted in the last week', () {
      final h = History();
      play(h, '2026-10-30');
      expect(weeklyPeriods(h, today).last.stats.games, 1);
    });

    test('a week across the end of a month or a year is read the same', () {
      final h = History();
      play(h, '2027-01-02');
      play(h, '2026-12-30');
      final w = weeklyPeriods(h, '2027-01-03');
      expect(w.last.start, '2026-12-28');
      expect(w.last.stats.games, 2);
    });

    test('each week has the style that week alone would have', () {
      final h = History();
      // the last week: 12 sharp, careful games
      for (var i = 0; i < 12; i++) {
        play(h, today, skill: 95, daring: 1);
      }
      // the week before: 12 loose, bold ones
      for (var i = 0; i < 12; i++) {
        play(h, '2026-10-15', skill: 40, daring: 30);
      }
      // the one before that: too few to rate
      for (var i = 0; i < 3; i++) {
        play(h, '2026-10-08', skill: 70, daring: 70);
      }
      final w = weeklyPeriods(h, today);
      expect(w[49].style, analyst);
      expect(w[48].style, wildcard);
      expect(w[47].style, isNull);
      expect(w[46].style, isNull);
    });
  });

  group('the last 50 months', () {
    test('there are 50, oldest first, the last the month of today', () {
      final m = monthlyPeriods(History(), today);
      expect(m.length, 50);
      expect(m.last.label, '2026-10');
      expect(m.last.start, '2026-10-01');
      expect(m.last.end, '2026-10-31');
      expect(m[48].label, '2026-09');
      expect(m[48].end, '2026-09-30');
      // 50 months back from October 2026 is August 2022
      expect(m.first.label, '2022-09');
      for (var i = 1; i < m.length; i++) {
        expect(dailyShift(m[i - 1].end, 1), m[i].start, reason: 'month $i');
      }
    });

    test('a month is as long as it is', () {
      final feb = monthlyPeriods(History(), '2028-03-10');
      expect(feb[48].label, '2028-02');
      expect(feb[48].end, '2028-02-29');
      final plain = monthlyPeriods(History(), '2027-03-10');
      expect(plain[48].end, '2027-02-28');
    });

    test('a game goes in its calendar month', () {
      final h = History();
      play(h, today);
      play(h, '2026-10-01');
      play(h, '2026-09-30');
      play(h, '2026-09-01');
      play(h, '2026-08-15');
      final m = monthlyPeriods(h, today);
      expect(m.last.stats.games, 2);
      expect(m[48].stats.games, 2);
      expect(m[47].stats.games, 1);
      expect(m.fold<int>(0, (a, p) => a + p.stats.games), 5);
    });

    test('games older than 50 months are not in them', () {
      final h = History();
      play(h, today);
      play(h, '2022-09-05'); // the first month
      play(h, '2022-08-31'); // just outside
      final m = monthlyPeriods(h, today);
      expect(m.first.stats.games, 1);
      expect(m.fold<int>(0, (a, p) => a + p.stats.games), 2);
    });

    test('a month across a year end', () {
      final h = History();
      play(h, '2026-12-31');
      play(h, '2027-01-01');
      final m = monthlyPeriods(h, '2027-01-15');
      expect(m.last.label, '2027-01');
      expect(m.last.stats.games, 1);
      expect(m[48].label, '2026-12');
      expect(m[48].stats.games, 1);
    });

    test('a month has a style once it has the games to rate it', () {
      final h = History();
      for (var i = 0; i < 6; i++) {
        play(h, '2026-09-03', skill: 70, daring: 5);
        play(h, '2026-09-20', skill: 70, daring: 5);
      }
      final m = monthlyPeriods(h, today);
      expect(m[48].stats.games, 12);
      expect(m[48].style, steady);
      expect(m.last.style, isNull);
    });
  });

  test('working out the periods of thousands of games is quick', () {
    final h = History();
    for (var i = 0; i < 5000; i++) {
      play(h, dailyShift(today, -(i % 400)), skill: 60 + i % 30);
    }
    final started = Stopwatch()..start();
    final w = weeklyPeriods(h, today);
    final m = monthlyPeriods(h, today);
    final all = summarise(h, h.games);
    expect(started.elapsed, lessThan(const Duration(seconds: 5)));
    expect(all.games, 5000);
    expect(w.fold<int>(0, (a, p) => a + p.stats.games), lessThan(5000));
    expect(w.fold<int>(0, (a, p) => a + p.stats.games), greaterThan(4000));
    expect(m.fold<int>(0, (a, p) => a + p.stats.games), 5000);
  });
}
