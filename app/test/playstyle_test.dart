import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rows of one game played in a style: two early guesses and two at the end.
List<GuessRow> rowsOf(Behaviour early, Behaviour end) => [
  for (var k = 0; k < 2; k++)
    GuessRow(
      game: 0,
      n: k,
      word: 'crane',
      skill: 70,
      before: 500,
      after: 200,
      risk: early == Behaviour.gambler ? 90 : 10,
      rank: early == Behaviour.maximiser ? 2 : 50,
      fresh: early == Behaviour.eliminator ? 5 : 1,
    ),
  for (var k = 2; k < 4; k++)
    GuessRow(
      game: 0,
      n: k,
      word: 'slate',
      skill: 70,
      before: 8,
      after: 3,
      risk: 0,
      rank: end == Behaviour.prober ? 3 : 60,
      fits: end == Behaviour.closer,
    ),
];

/// Adds [n] games played in the style of [early] and [end].
void addGames(
  History h,
  int n, {
  Behaviour early = Behaviour.maximiser,
  Behaviour end = Behaviour.prober,
  GameMode mode = GameMode.classic,
}) {
  for (var i = 0; i < n; i++) {
    h.add(
      at: i,
      lang: 'en',
      mode: mode,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: mode.multi ? ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'] : ['slate'],
      won: true,
      guesses: rowsOf(early, end),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the playstyles', () {
    test('there are six, each an early habit and an end habit', () {
      expect(playstyles.map((p) => p.id), [
        'analyst',
        'maverick',
        'detective',
        'sweeper',
        'wildcard',
        'gambler',
      ]);
      expect(playstyles.toSet().length, 6);
      for (final p in playstyles) {
        expect(p.early.phase, Phase.early);
        expect(p.end.phase, Phase.end);
        expect(styleOf(p.early, p.end), p);
      }
    });

    test('every icon is a Tabler filled glyph in the assets', () {
      final icons = [
        ...playstyles.map((p) => p.icon),
        ...Behaviour.values.map((b) => b.icon),
      ];
      for (final i in icons) {
        expect(File('assets/icons/$i.svg').existsSync(), isTrue, reason: i);
      }
    });

    test('a style is found by the id it was saved under', () {
      for (final p in playstyles) {
        expect(playstyleById(p.id), p);
      }
      expect(playstyleById('time-traveller'), isNull);
      expect(playstyleById(null), isNull);
    });
  });

  group('counting a guess', () {
    GuessRow row({
      int before = 500,
      int greens = 0,
      double? risk = 10,
      double? rank = 50,
      int fresh = 1,
      bool fits = false,
    }) => GuessRow(
      game: 0,
      n: 0,
      word: 'crane',
      before: before,
      greens: greens,
      risk: risk,
      rank: rank,
      fresh: fresh,
      fits: fits,
    );

    test('the phases follow the words left and the greens known', () {
      expect(phaseOf(1, 0), isNull);
      expect(phaseOf(64, 0), Phase.early);
      expect(phaseOf(63, 0), Phase.middle);
      expect(phaseOf(16, 0), Phase.end);
      expect(phaseOf(40, 3), Phase.end);
      expect(phaseOf(40, 2), Phase.middle);
    });

    test('early: a gamble first, then a best split, then fresh letters', () {
      expect(behaviourOf(row(risk: 80, rank: 1)), Behaviour.gambler);
      expect(behaviourOf(row(risk: 74, rank: 10)), Behaviour.maximiser);
      expect(behaviourOf(row(rank: 11, fresh: 4)), Behaviour.eliminator);
      expect(behaviourOf(row(rank: 11, fresh: 3)), isNull);
    });

    test('end: a guess that fits is a closer, else a prober', () {
      expect(behaviourOf(row(before: 8, fits: true)), Behaviour.closer);
      expect(behaviourOf(row(before: 8, rank: 5)), Behaviour.prober);
      expect(behaviourOf(row(before: 8, rank: 40)), isNull);
      expect(behaviourOf(row(before: 2, rank: 0)), isNull);
    });

    test('the middle game and a single word count as nothing', () {
      expect(behaviourOf(row(before: 30, rank: 0, fits: true)), isNull);
      expect(behaviourOf(row(before: 1, fits: true)), isNull);
    });
  });

  group('reading the habits', () {
    test('a habit needs 40% of the guesses of its phase', () {
      final h = History();
      addGames(h, 10);
      final habits = habitsOf(h);
      expect(habits.share(Behaviour.maximiser), 1);
      expect(habits.share(Behaviour.prober), 1);
      expect(habits.habit(Phase.early), Behaviour.maximiser);
      expect(habits.habit(Phase.end), Behaviour.prober);
      expect(habits.rated, isTrue);
    });

    test('rated takes enough games and enough guesses', () {
      final h = History();
      addGames(h, minRatedGames - 1);
      expect(habitsOf(h).rated, isFalse);
      addGames(h, 1);
      expect(habitsOf(h).rated, isTrue);
    });

    test('only the last 100 games are read', () {
      final h = History();
      addGames(h, 100, early: Behaviour.gambler, end: Behaviour.closer);
      addGames(h, 100);
      expect(habitsOf(h).habit(Phase.early), Behaviour.maximiser);
    });

    test('every style reads back as the one played', () {
      for (final p in playstyles) {
        final h = History();
        addGames(h, 12, early: p.early, end: p.end);
        expect(classify(habitsOf(h)), p, reason: p.id);
      }
    });

    test('a player not yet rated has no style', () {
      final h = History();
      addGames(h, 3);
      expect(classify(habitsOf(h)), isNull);
      expect(classify(null), isNull);
    });

    test('a habit within the margin of the top is kept', () {
      // 100 early guesses: 50 maximiser, 45 gambler, the rest nothing
      const counts = {
        Behaviour.gambler: 45,
        Behaviour.maximiser: 50,
        Behaviour.eliminator: 0,
        Behaviour.closer: 0,
        Behaviour.prober: 40,
      };
      const habits = Habits(
        50,
        counts,
        {Phase.early: 100, Phase.end: 60},
      );
      expect(classify(habits)!.early, Behaviour.maximiser);
      expect(classify(habits, current: gambler)!.early, Behaviour.gambler);
      expect(classify(habits, current: analyst)!.early, Behaviour.maximiser);
    });

    test('the traits are the means over the guesses that had a choice', () {
      final h = History();
      addGames(h, 2);
      final t = traitsOf(h)!;
      expect(t.skill, 70);
      expect(t.games, 2);
      expect(t.guesses, 8);
    });

    test('only classic games count, a daily among them', () {
      final h = History();
      addGames(h, 20, mode: GameMode.quartet);
      expect(habitsOf(h).games, 0);
      expect(traitsOf(h), isNull);
    });
  });

  group('shifting playstyle as games are played', () {
    test('it moves with the last 100 games, and records each change', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.style, isNull);
      var changes = 0;
      void play(int n, Behaviour early, Behaviour end) {
        for (var i = 0; i < n; i++) {
          addGames(s.history, 1, early: early, end: end);
          if (s.updateStyle().changed) changes++;
        }
      }

      play(minRatedGames - 1, Behaviour.maximiser, Behaviour.prober);
      expect(s.style, isNull);
      play(1, Behaviour.maximiser, Behaviour.prober);
      expect(s.style, analyst);
      expect(changes, 0, reason: 'being rated for the first time is no change');
      play(120, Behaviour.gambler, Behaviour.closer);
      expect(s.style, gambler, reason: 'the last 100 are all gambler');
      expect(s.stylesHeld, containsAll(['analyst', 'gambler']));
      expect(s.styleChanges, changes);
      expect(changes, greaterThanOrEqualTo(1));
    });

    test('a quartet does not move a classic player', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      addGames(s.history, 20);
      s.updateStyle();
      expect(s.style, analyst);
      addGames(s.history, 50, early: Behaviour.gambler, mode: GameMode.quartet);
      final u = s.updateStyle();
      expect(u.style, analyst);
      expect(u.changed, isFalse);
    });

    test('without enough history the style a player has is kept', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      addGames(s.history, 20);
      s.updateStyle();
      s.history = History();
      final u = s.updateStyle();
      expect(u.style, analyst);
      expect(u.changed, isFalse);
    });
  });

  group('kept by the app', () {
    test(
      'the style, those held and the changes come back after a restart',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = AppState();
        await s.load();
        addGames(s.history, 20);
        s.updateStyle();
        addGames(s.history, 200, early: Behaviour.gambler);
        for (var i = 0; i < 5; i++) {
          s.updateStyle();
        }
        expect(s.style, wildcard);

        final again = AppState();
        await again.load();
        expect(again.style, wildcard);
        expect(again.stylesHeld, s.stylesHeld);
        expect(again.styleChanges, s.styleChanges);
      },
    );

    test('a style this version does not know is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'style': 'time-traveller',
        'stylesHeld': ['analyst', 'time-traveller'],
        'styleChanges': -4,
      });
      final s = AppState();
      await s.load();
      expect(s.style, isNull);
      expect(s.stylesHeld, {'analyst'});
      expect(s.styleChanges, 0);
    });

    test(
      'the backup holds the playstyle, and a restore brings it back',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = AppState();
        await s.load();
        addGames(s.history, 20);
        s.updateStyle();
        final backup = parseBackup(backupToText(s));
        expect(backup.languages!['en']!.style, 'analyst');
        expect(backup.languages!['en']!.held, {'analyst'});

        final other = AppState();
        await other.load();
        other.restore(
          settings: backup.settings,
          stats: backup.stats,
          ach: backup.achievements,
          languages: backup.languages,
        );
        expect(other.style, analyst);
        expect(other.stylesHeld, {'analyst'});
      },
    );

    test(
      'a backup from before the playstyles leaves the style alone',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = AppState();
        await s.load();
        addGames(s.history, 20);
        s.updateStyle();
        final j = jsonDecode(backupToText(s)) as Map<String, dynamic>
          ..remove('languages');
        final old = parseBackup(jsonEncode(j));
        expect(old.languages, isNull);
        s.restore(
          settings: old.settings,
          stats: old.stats,
          ach: old.achievements,
          languages: old.languages,
        );
        expect(s.style, analyst);
      },
    );

    test(
      'a style the backup has that this version lacks is dropped, not refused',
      () {
        final j = jsonDecode(backupToText(AppState())) as Map<String, dynamic>
          ..remove('languages'); // the form before each language had its own
        j['playstyle'] = {
          'current': 'time-traveller',
          'held': ['maverick', 'time-traveller', 5],
          'changes': 2,
        };
        final b = parseBackup(jsonEncode(j));
        // a backup from before each language had its own is the language it
        // was made in
        expect(b.languages!['en']!.style, isNull);
        expect(b.languages!['en']!.held, {'maverick'});
        expect(b.languages!['en']!.changes, 2);
      },
    );

    test('a damaged playstyle in a backup is refused', () {
      for (final bad in [
        5,
        {'current': 5},
        {'held': 'analyst'},
        {'changes': -1},
        {'changes': 'many'},
      ]) {
        final j = jsonDecode(backupToText(AppState())) as Map<String, dynamic>;
        j['languages'] = {
          'en': {'playstyle': bad},
        };
        expect(
          () => parseBackup(jsonEncode(j)),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

}
