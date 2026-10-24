import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adds [n] games of [guesses] guesses each, every guess scored [skill] and
/// [daring] with [before] words possible.
void addGames(
  History h,
  int n, {
  double skill = 70,
  double? daring = 50,
  int guesses = 4,
  int before = 50,
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
      guesses: [
        for (var k = 0; k < guesses; k++)
          GuessRow(
            game: 0,
            n: k,
            word: 'crane',
            skill: skill,
            luck: 0,
            daring: daring,
            before: before,
            after: before ~/ 2,
          ),
      ],
    );
  }
}

Traits t(double skill, double daring, {int games = 20, int guesses = 80}) =>
    Traits(skill: skill, daring: daring, games: games, guesses: guesses);

GameResult styled({
  String? style,
  bool changed = false,
  int held = 0,
  bool won = true,
}) => GameResult(
  lang: 'en',
  length: 5,
  tries: 6,
  used: 4,
  won: won,
  pool: 3000,
  skills: const [70, 70, 70, 70],
  style: style,
  styleChanged: changed,
  stylesHeld: held,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the playstyles', () {
    test('there are six, with their own ids, names and icons', () {
      expect(playstyles.length, 6);
      expect({for (final p in playstyles) p.id}.length, 6);
      expect({for (final p in playstyles) p.name}.length, 6);
      expect({for (final p in playstyles) p.icon}.length, 6);
      // two halves of each of the three skill tiers
      for (var tier = 0; tier < 3; tier++) {
        for (final bold in [false, true]) {
          expect(
            playstyles.where((p) => p.sharpness == tier && p.bold == bold),
            hasLength(1),
            reason: 'tier $tier bold $bold',
          );
        }
      }
    });

    test('every icon is a Tabler filled glyph in the assets', () {
      for (final p in playstyles) {
        final f = File('assets/icons/${p.icon}.svg');
        expect(f.existsSync(), isTrue, reason: p.id);
        expect(f.readAsStringSync(), contains('icons-tabler-filled'));
      }
      // and the placeholder for a player who is not rated yet
      expect(File('assets/icons/puzzle.svg').existsSync(), isTrue);
    });

    test('a style is found by the id it was saved under', () {
      for (final p in playstyles) {
        expect(playstyleById(p.id), same(p));
      }
      expect(playstyleById('nope'), isNull);
      expect(playstyleById(null), isNull);
    });
  });

  group('reading the traits', () {
    test('they are the means over every guess that had a choice', () {
      final h = History();
      addGames(h, 5, skill: 60, daring: 20);
      addGames(h, 5, skill: 80, daring: 40);
      final x = traitsOf(h)!;
      expect(x.skill, 70);
      expect(x.daring, 30);
      expect(x.games, 10);
      expect(x.guesses, 40);
    });

    test(
      'a guess with one word left has nothing to choose, so it is left out',
      () {
        final h = History();
        addGames(h, 5, skill: 50, daring: 30);
        addGames(
          h,
          5,
          skill: 100,
          daring: 0,
          before: 1,
        ); // the last, sure guess
        final x = traitsOf(h)!;
        expect(x.skill, 50);
        expect(x.daring, 30);
        expect(x.guesses, 20);
      },
    );

    test('a guess without a daring still counts for skill, not for daring', () {
      final h = History();
      addGames(h, 5, skill: 60, daring: 20);
      addGames(h, 5, skill: 80, daring: null);
      final x = traitsOf(h)!;
      expect(x.skill, 70);
      expect(x.daring, 20);
      expect(x.guesses, 20, reason: 'only those with a daring');
    });

    test('only the last 100 games are read', () {
      final h = History();
      addGames(h, 60, skill: 20, daring: 90); // pushed out
      addGames(h, 100, skill: 90, daring: 10);
      final x = traitsOf(h)!;
      expect(x.games, 100);
      expect(x.skill, 90);
      expect(x.daring, 10);
    });

    test('only classic games count, a daily among them', () {
      final h = History();
      addGames(h, 10, skill: 90, daring: 10);
      addGames(h, 30, skill: 10, daring: 90, mode: GameMode.quartet);
      addGames(h, 30, skill: 10, daring: 90, mode: GameMode.relay);
      final x = traitsOf(h)!;
      expect(x.games, 10);
      expect(x.skill, 90);
      h.add(
        at: 1,
        lang: 'en',
        mode: GameMode.classic,
        length: 5,
        tries: 6,
        pool: 3000,
        answers: ['slate'],
        won: true,
        daily: '2026-10-24',
        guesses: const [
          GuessRow(
            game: 0,
            n: 0,
            word: 'crane',
            skill: 90,
            daring: 10,
            before: 50,
          ),
        ],
      );
      expect(traitsOf(h)!.games, 11);
    });

    test('with no daring anywhere there is nothing to read', () {
      expect(traitsOf(History()), isNull);
      final h = History();
      addGames(h, 20, daring: null);
      expect(traitsOf(h), isNull);
      addGames(History(), 3, before: 1);
    });

    test('rated takes enough games and enough guesses', () {
      expect(t(90, 10, games: minRatedGames - 1).rated, isFalse);
      expect(t(90, 10, games: minRatedGames).rated, isTrue);
      expect(t(90, 10, guesses: minRatedGuesses - 1).rated, isFalse);
      expect(t(90, 10, guesses: minRatedGuesses).rated, isTrue);
    });
  });

  group('the six cells', () {
    Playstyle? at(double skill, double daring) => classify(t(skill, daring));

    test('each skill tier splits into careful and bold', () {
      expect(at(95, 10), analyst);
      expect(at(95, 60), maverick);
      expect(at(70, 30), steady);
      expect(at(70, 80), gambler);
      expect(at(40, 20), wanderer);
      expect(at(40, 80), wildcard);
    });

    test('the lines between the tiers', () {
      expect(at(sharpFrom, 0), analyst, reason: 'on the line is the higher');
      expect(at(sharpFrom - .01, 0), steady);
      expect(at(looseBelow, 0), steady, reason: 'on the line is the higher');
      expect(at(looseBelow - .01, 0), wanderer);
      expect(at(100, 0), analyst);
      expect(at(0, 0), wanderer);
    });

    test('the daring split is a little different in each tier', () {
      // sharp: 40, solid: 65, loose: 52
      expect(at(90, 39.99), analyst);
      expect(at(90, 40), maverick);
      expect(at(70, 64.99), steady);
      expect(at(70, 65), gambler);
      expect(at(40, 51.99), wanderer);
      expect(at(40, 52), wildcard);
      expect(at(90, 100), maverick);
      expect(at(40, 100), wildcard);
    });

    test('a player who is not rated has no style', () {
      expect(classify(null), isNull);
      expect(classify(t(90, 10, games: 3)), isNull);
      expect(classify(t(90, 10, guesses: 5)), isNull);
    });

    test('simulated players land where the calibration says they do', () {
      // the means of tools/calibrate_styles.dart over many games (see
      // docs/paper/experiments/results/daring_calibration.txt)
      final bots = <String, (double, double, Playstyle)>{
        'best, English': (100, 0, analyst),
        'near-best, English': (99, 12, analyst),
        'near-best, French': (98.9, 28.5, analyst),
        'near-best, German': (97.9, 33.5, analyst),
        'sharp but safe': (96.4, 0, analyst),
        'sharp but bold, English': (94.1, 47.9, maverick),
        'sharp but bold, French': (93.2, 83.4, maverick),
        'sharp but bold, German': (90.1, 78.2, maverick),
        'commonest word, English': (67.9, 63.3, steady),
        'any word that fits, English': (69.9, 62.8, steady),
        'any word that fits, French': (68.1, 63.6, steady),
        'any word that fits, German': (64.7, 60.8, steady),
        'commonest word, German': (62.8, 69.9, gambler),
        'ignores the clues, English': (47.4, 48.1, wanderer),
        'ignores the clues, French': (44.1, 42.1, wanderer),
        'rare words, ignoring the clues': (47.1, 46.7, wanderer),
      };
      for (final e in bots.entries) {
        final (skill, daring, want) = e.value;
        expect(at(skill, daring), want, reason: e.key);
      }
    });
  });

  group('staying put near a line', () {
    Playstyle? from(Playstyle current, double skill, double daring) =>
        classify(t(skill, daring), current: current);

    test(
      'a style is kept while the skill is within the margin of its edge',
      () {
        // analyst is sharp: 85 and up; it holds down to 85 - margin
        expect(from(analyst, 85 - skillMargin + .5, 0), analyst);
        expect(from(analyst, 85 - skillMargin - .5, 0), steady);
        // steady is solid: it holds up to 85 + margin, and down to 58 - margin
        expect(from(steady, 85 + skillMargin - .5, 0), steady);
        expect(from(steady, 85 + skillMargin + .5, 0), analyst);
        expect(from(steady, 58 - skillMargin + .5, 0), steady);
        expect(from(steady, 58 - skillMargin - .5, 0), wanderer);
        // wanderer is loose: it holds up to 58 + margin
        expect(from(wanderer, 58 + skillMargin - .5, 0), wanderer);
        expect(from(wanderer, 58 + skillMargin + .5, 0), steady);
      },
    );

    test('and the same for daring', () {
      expect(from(analyst, 90, 40 + daringMargin - .5), analyst);
      expect(from(analyst, 90, 40 + daringMargin + .5), maverick);
      expect(from(maverick, 90, 40 - daringMargin + .5), maverick);
      expect(from(maverick, 90, 40 - daringMargin - .5), analyst);
      expect(from(steady, 70, 65 + daringMargin - .5), steady);
      expect(from(gambler, 70, 65 - daringMargin + .5), gambler);
      expect(from(gambler, 70, 65 - daringMargin - .5), steady);
    });

    test('a player far from their style is moved at once', () {
      expect(from(analyst, 40, 90), wildcard);
      expect(from(wildcard, 95, 5), analyst);
    });

    test('with no style yet the lines are exact', () {
      expect(classify(t(84.9, 0)), steady);
      expect(classify(t(85, 0)), analyst);
    });

    test('the margins are small next to the tiers', () {
      expect(skillMargin, lessThan((sharpFrom - looseBelow) / 4));
      expect(daringMargin, lessThan(10));
    });
  });

  group('shifting playstyle as games are played', () {
    test('it moves with the last 100 games, and records each change', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.style, isNull);
      final seen = <String>[];
      var changes = 0;

      void play(int n, {required double skill, required double daring}) {
        for (var i = 0; i < n; i++) {
          addGames(s.history, 1, skill: skill, daring: daring);
          final u = s.updateStyle();
          if (u.changed) changes++;
          final id = u.style?.id;
          if (id != null && (seen.isEmpty || seen.last != id)) seen.add(id);
        }
      }

      // not rated until there are games enough
      play(minRatedGames - 1, skill: 95, daring: 10);
      expect(s.style, isNull);
      expect(s.stylesHeld, isEmpty);
      play(1, skill: 95, daring: 10);
      expect(s.style, analyst);
      expect(changes, 0, reason: 'being rated for the first time is no change');

      // 100 games at the top, then a long run of bold, middling play
      play(90, skill: 95, daring: 10);
      expect(s.style, analyst);
      play(120, skill: 70, daring: 80);
      expect(s.style, gambler, reason: 'the last 100 are all gambler');

      expect(seen.first, 'analyst');
      expect(seen.last, 'gambler');
      expect(s.stylesHeld, containsAll(['analyst', 'gambler']));
      expect(s.styleChanges, changes);
      expect(changes, greaterThanOrEqualTo(1));
      // the margins stop it flapping between neighbours on the way
      expect(changes, lessThanOrEqualTo(4), reason: '$seen');
    });

    test('a player can go back to a style they have had', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      void play(int n, double skill, double daring) {
        for (var i = 0; i < n; i++) {
          addGames(s.history, 1, skill: skill, daring: daring);
          s.updateStyle();
        }
      }

      play(100, 95, 10);
      expect(s.style, analyst);
      play(100, 40, 90);
      expect(s.style, wildcard);
      play(100, 95, 10);
      expect(s.style, analyst);
      expect(s.stylesHeld, {'analyst', 'wildcard', ...s.stylesHeld});
      expect(s.styleChanges, greaterThanOrEqualTo(2));
    });

    test('a quartet does not move a classic player', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      addGames(s.history, 20, skill: 95, daring: 10);
      s.updateStyle();
      expect(s.style, analyst);
      addGames(s.history, 50, skill: 10, daring: 90, mode: GameMode.quartet);
      final u = s.updateStyle();
      expect(u.style, analyst);
      expect(u.changed, isFalse);
    });

    test('without enough history the style a player has is kept', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      addGames(s.history, 20, skill: 95, daring: 10);
      s.updateStyle();
      // the history is lost (a damaged save is dropped)
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
        addGames(s.history, 20, skill: 95, daring: 10);
        s.updateStyle();
        addGames(s.history, 200, skill: 40, daring: 90);
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
        addGames(s.history, 20, skill: 95, daring: 10);
        s.updateStyle();
        final backup = parseBackup(backupToText(s));
        expect(backup.playstyle!.style, 'analyst');
        expect(backup.playstyle!.held, {'analyst'});

        final other = AppState();
        await other.load();
        other.restore(
          settings: backup.settings,
          stats: backup.stats,
          ach: backup.achievements,
          playstyle: backup.playstyle,
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
        addGames(s.history, 20, skill: 95, daring: 10);
        s.updateStyle();
        final j = jsonDecode(backupToText(s)) as Map<String, dynamic>
          ..remove('playstyle');
        final old = parseBackup(jsonEncode(j));
        expect(old.playstyle, isNull);
        s.restore(
          settings: old.settings,
          stats: old.stats,
          ach: old.achievements,
          playstyle: old.playstyle,
        );
        expect(s.style, analyst);
      },
    );

    test(
      'a style the backup has that this version lacks is dropped, not refused',
      () {
        final j = jsonDecode(backupToText(AppState())) as Map<String, dynamic>;
        j['playstyle'] = {
          'current': 'time-traveller',
          'held': ['maverick', 'time-traveller', 5],
          'changes': 2,
        };
        final b = parseBackup(jsonEncode(j));
        expect(b.playstyle!.style, isNull);
        expect(b.playstyle!.held, {'maverick'});
        expect(b.playstyle!.changes, 2);
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
        j['playstyle'] = bad;
        expect(
          () => parseBackup(jsonEncode(j)),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('the achievements', () {
    Achievement byId(String id) => achievements.firstWhere((a) => a.id == id);

    test('there is one for each playstyle, one for changing, one for all', () {
      for (final p in playstyles) {
        final a = byId('style_${p.id}');
        expect(a.icon, p.icon);
        expect(a.title, p.name);
        expect(a.repeat, isFalse);
      }
      expect(byId('chameleon').icon, 'butterfly');
      expect(byId('many_hats').icon, 'rosette');
    });

    test(
      'a playstyle is earned the first game that leaves the player in it',
      () {
        final states = <String, AchState>{};
        var earned = advanceAchievements(states, styled(), 'd0');
        expect(earned.map((a) => a.id), isNot(contains('style_analyst')));
        earned = advanceAchievements(
          states,
          styled(style: 'analyst', held: 1),
          'd1',
        );
        expect(earned.map((a) => a.id), contains('style_analyst'));
        expect(earned.map((a) => a.id), isNot(contains('style_maverick')));
        earned = advanceAchievements(
          states,
          styled(style: 'analyst', held: 1),
          'd2',
        );
        expect(earned.map((a) => a.id), isNot(contains('style_analyst')));
        expect(states['style_analyst']!.times, 1);
      },
    );

    test('changing playstyle is earned once, on the first change', () {
      final states = <String, AchState>{};
      var earned = advanceAchievements(
        states,
        styled(style: 'analyst', held: 1),
        'd1',
      );
      expect(earned.map((a) => a.id), isNot(contains('chameleon')));
      earned = advanceAchievements(
        states,
        styled(style: 'maverick', changed: true, held: 2),
        'd2',
      );
      expect(earned.map((a) => a.id), contains('chameleon'));
      earned = advanceAchievements(
        states,
        styled(style: 'analyst', changed: true, held: 2),
        'd3',
      );
      expect(earned.map((a) => a.id), isNot(contains('chameleon')));
      expect(states['chameleon']!.times, 1);
    });

    test('having been every playstyle is earned at the sixth', () {
      final states = <String, AchState>{};
      for (var held = 1; held < playstyles.length; held++) {
        final earned = advanceAchievements(
          states,
          styled(style: playstyles[held - 1].id, held: held),
          'd$held',
        );
        expect(earned.map((a) => a.id), isNot(contains('many_hats')));
      }
      final earned = advanceAchievements(
        states,
        styled(style: playstyles.last.id, held: playstyles.length),
        'done',
      );
      expect(earned.map((a) => a.id), contains('many_hats'));
    });

    test('a quartet, which has no style to give, earns none of them', () {
      final states = <String, AchState>{};
      final r = GameResult(
        lang: 'en',
        length: 5,
        tries: 9,
        used: 5,
        won: true,
        mode: GameMode.quartet,
        skills: const [90],
      );
      final earned = advanceAchievements(states, r, 'q');
      expect(
        earned.where((a) => a.id.startsWith('style_') || a.id == 'chameleon'),
        isEmpty,
      );
    });
  });

  group('on the home page', () {
    /// Opens the home page with [style] as the player's. (Settings are loaded
    /// first: loading would otherwise wipe a style set before it.)
    Future<void> home(
      WidgetTester tester, {
      Size size = const Size(420, 1700),
      String? style,
    }) async {
      await tester.binding.setSurfaceSize(size);
      await appState.load();
      appState.history = History();
      appState.styleId = style;
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
    }

    testWidgets('a player not yet rated sees how many games to go', (
      tester,
    ) async {
      await home(tester);
      expect(find.byKey(const ValueKey('style-icon-unrated')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('style-label'))).data,
        '0/$minRatedGames',
      );
      addGames(appState.history, 4);
      appState.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('style-label'))).data,
        '4/$minRatedGames',
      );
      // enough games but nothing to read a daring from
      addGames(appState.history, 20, daring: null);
      appState.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('style-label'))).data,
        'unrated',
      );
    });

    testWidgets('a rated player sees the icon and name of their style', (
      tester,
    ) async {
      for (final p in playstyles) {
        await home(tester, style: p.id);
        expect(
          find.byKey(ValueKey('style-icon-${p.id}')),
          findsOneWidget,
          reason: p.id,
        );
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('style-label'))).data,
          p.name,
        );
        expect(find.byKey(const ValueKey('style-icon-unrated')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the tooltip says what the style means', (tester) async {
      await home(tester, style: 'maverick');
      final tip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('style-chip')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tip.message, contains('maverick'));
      expect(tip.message, contains(maverick.blurb));
    });

    testWidgets('it fits beside the name on the narrowest phone', (
      tester,
    ) async {
      await home(tester, size: const Size(320, 1700), style: 'wanderer');
      // (the text of the error, so a failure says which widget overflowed)
      expect(tester.takeException()?.toString(), isNull);
      final title = tester.getRect(find.text('lexodle'));
      final chip = tester.getRect(find.byKey(const ValueKey('style-chip')));
      expect(title.right, lessThanOrEqualTo(chip.left));
      expect(chip.right, lessThanOrEqualTo(320));
    });
  });
}
