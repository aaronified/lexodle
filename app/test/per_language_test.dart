import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [n] classic games in [lang], played in the style of [early] and [end].
void play(
  AppState s,
  String lang,
  int n, {
  Behaviour early = Behaviour.maximiser,
  Behaviour end = Behaviour.prober,
}) {
  for (var i = 0; i < n; i++) {
    s.history.add(
      at: i,
      lang: lang,
      mode: GameMode.classic,
      length: 5,
      tries: 6,
      pool: 3000,
      answers: const ['slate'],
      won: true,
      guesses: [
        for (var k = 0; k < 4; k++)
          GuessRow(
            game: 0,
            n: k,
            word: 'crane',
            skill: 70,
            before: k < 2 ? 500 : 8,
            after: k < 2 ? 200 : 3,
            risk: k < 2 && early == Behaviour.gambler ? 90 : 10,
            rank: k < 2
                ? (early == Behaviour.maximiser ? 2 : 50)
                : (end == Behaviour.prober ? 3 : 60),
            fresh: k < 2 && early == Behaviour.eliminator ? 5 : 1,
            fits: k >= 2 && end == Behaviour.closer,
          ),
      ],
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('each language has its own playstyle', () async {
    final s = AppState();
    await s.load();
    play(s, 'en', 20);
    play(s, 'fr', 20, early: Behaviour.gambler);
    s.updateStyle(lang: 'en');
    s.updateStyle(lang: 'fr');
    expect(s.styleOf('en'), analyst);
    expect(s.styleOf('fr'), wildcard);
    expect(s.styleOf('de'), isNull);
    // the one in view follows the language being played
    s.lang = 'en';
    expect(s.style, analyst);
    s.lang = 'fr';
    expect(s.style, wildcard);
    expect(s.stylesHeldOf('en'), {'analyst'});
    expect(s.stylesHeldOf('fr'), {'wildcard'});
  });

  test('one language\'s games do not move another\'s style', () async {
    final s = AppState();
    await s.load();
    play(s, 'en', 20);
    s.updateStyle(lang: 'en');
    play(s, 'fr', 200, early: Behaviour.gambler);
    s.updateStyle(lang: 'en');
    expect(s.styleOf('en'), analyst, reason: 'the 100 are English ones');
    expect(s.styleChangesOf('en'), 0);
  });

  test('each language has its own daily streak and calendar', () async {
    final s = AppState();
    await s.load();
    final today = dailyDate();
    expect(s.recordDaily(today, dailySolved, lang: 'en'), 1);
    expect(s.recordDaily(today, dailyMissed, lang: 'fr'), 0);
    expect(s.dailyStreakFor('en'), 1);
    expect(s.dailyStreakFor('fr'), 0);
    expect(s.dailyBestOf('en'), 1);
    expect(s.dailyBestOf('fr'), 0);
    expect(s.dailyLogOf('en')[today], dailySolved);
    expect(s.dailyLogOf('fr')[today], dailyMissed);
    s.lang = 'fr';
    expect(s.dailyStreak, 0);
    s.lang = 'en';
    expect(s.dailyStreak, 1);
  });

  GameResult won(String lang) => GameResult(
    lang: lang,
    length: 5,
    tries: 6,
    pool: 3000,
    used: 3,
    won: true,
    skills: const [90, 90, 90],
  );

  test('achievements count in the language they were earned in', () async {
    final s = AppState();
    await s.load();
    for (var i = 0; i < 10; i++) {
      s.recordGame(won('en'));
    }
    s.recordGame(won('fr'));
    // ten wins in English earn "regular"; French has had one
    expect(s.achOf('en')['wins_10']!.times, 1);
    expect(s.achOf('fr')['wins_10']!.times, 0);
    expect(s.achOf('fr')['wins_10']!.progress, 1);
    expect(s.achOf('fr')['first_light']!.times, 1);
    // the ones that span languages are shared, and see both
    expect(s.achOf('en')['bilingual']!.times, 1);
    expect(s.achOf('fr')['bilingual']!.times, 1);
    expect(
      identical(s.achOf('en')['bilingual'], s.achOf('de')['bilingual']),
      isTrue,
    );
    // and which are shared is a property of the achievement
    expect(achievementById('bilingual')!.global, isTrue);
    expect(achievementById('mastery')!.global, isTrue);
    expect(achievementById('wins_10')!.global, isFalse);
  });

  test('all of it is saved, and read back, per language', () async {
    final s = AppState();
    await s.load();
    play(s, 'en', 20);
    s.updateStyle(lang: 'en');
    s.recordDaily(dailyDate(), dailyDouble, lang: 'fr');
    s.recordGame(won('de'));
    final again = AppState();
    await again.load();
    expect(again.styleOf('en'), analyst);
    expect(again.dailyStreakFor('fr'), 1);
    expect(again.dailyLogOf('fr')[dailyDate()], dailyDouble);
    expect(again.achOf('de')['first_light']!.times, 1);
    expect(again.achOf('en')['first_light']?.times ?? 0, 0);
  });

  test(
    'what was kept before each language had its own goes to the one in use',
    () async {
      SharedPreferences.setMockInitialValues({
        'lang': 'fr',
        'style': 'gambler',
        'stylesHeld': ['gambler', 'analyst'],
        'styleChanges': 2,
        'dailyLog': jsonEncode({'2026-10-23': dailySolved}),
        'dailyBest': 7,
        'ach': jsonEncode({
          'first_light': AchState(times: 1, dates: ['2026-10-01']).toJson(),
          'bilingual': AchState(times: 1, dates: ['2026-10-02']).toJson(),
        }),
      });
      final s = AppState();
      await s.load();
      expect(s.styleOf('fr'), gambler);
      expect(s.styleOf('en'), isNull);
      expect(s.stylesHeldOf('fr'), {'gambler', 'analyst'});
      expect(s.styleChangesOf('fr'), 2);
      expect(s.dailyLogOf('fr')['2026-10-23'], dailySolved);
      expect(s.dailyBestOf('fr'), 7);
      expect(s.dailyBestOf('en'), 0);
      expect(s.achOf('fr')['first_light']!.times, 1);
      expect(s.achOf('en')['first_light'], isNull);
      expect(s.achOf('en')['bilingual']!.times, 1, reason: 'a shared one');
    },
  );

  test(
    'a backup carries every language, and a restore brings each back',
    () async {
      final s = AppState();
      await s.load();
      play(s, 'en', 20);
      s.updateStyle(lang: 'en');
      s.recordDaily(dailyDate(), dailySolved, lang: 'fr');
      s.recordGame(won('de'));
      final b = parseBackup(backupToText(s));
      expect(b.languages!.keys, containsAll(['en', 'fr', 'de']));
      final other = AppState();
      await other.load();
      other.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
        history: b.history,
      );
      expect(other.styleOf('en'), analyst);
      expect(other.dailyStreakFor('fr'), 1);
      expect(other.achOf('de')['first_light']!.times, 1);
      expect(other.achOf('en')['first_light']?.times ?? 0, 0);
    },
  );

  test('a backup from before each language had its own is the language it was made in', () async {
    final s = AppState()..lang = 'fr';
    await s.load();
    s.lang = 'fr';
    s.recordGame(won('fr'));
    final j = jsonDecode(backupToText(s)) as Map<String, dynamic>;
    final fr = (j['languages'] as Map)['fr'] as Map;
    j
      ..remove('languages')
      ..['achievements'] = {
        ...(j['achievements'] as Map),
        ...(fr['achievements'] as Map),
      }
      ..['playstyle'] = fr['playstyle']
      ..['daily'] = fr['daily']
      ..['version'] = 1;
    final b = parseBackup(jsonEncode(j));
    expect(b.languages!.keys, ['fr']);
    expect(b.languages!['fr']!.achievements.containsKey('first_light'), isTrue);
    expect(b.achievements.containsKey('first_light'), isFalse);
  });
}
