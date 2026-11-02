import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearnEvent event(
  LearnKind kind, {
  String date = '2026-11-01',
  String language = 'fr',
  int length = 5,
  int? questions,
  int? right,
  double skill = 95,
  int hints = 0,
}) {
  final q =
      questions ??
      switch (kind) {
        LearnKind.free => 3,
        LearnKind.sequence => 1,
        _ => drillRoundLength,
      };
  return LearnEvent(
    kind: kind,
    language: language,
    length: length,
    date: date,
    questions: q,
    right: right ?? q,
    avgSkill: skill,
    hints: hints,
  );
}

Achievement byId(String id) => achievements.firstWhere((a) => a.id == id);

/// Plays [events] into fresh states and returns the states and what was earned.
(Map<String, AchState>, List<String>) play(List<LearnEvent> events) {
  final states = <String, AchState>{};
  final earned = <String>[];
  for (final e in events) {
    earned.addAll([
      for (final a in advanceLearnAchievements(states, e)) '${a.id}:${a.level}',
    ]);
  }
  return (states, earned);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what is a learn achievement', () {
    test('they are global, and not cut down to the number of languages', () {
      final learn = achievements.where((a) => a.learn).toList();
      expect(learn, hasLength(14));
      for (final a in learn) {
        expect(a.global, isTrue, reason: a.id);
        expect(a.count, 4, reason: a.id);
        expect(a.numbered, isTrue, reason: '${a.id} has a progress bar');
        expect(a.tagIcon, isNotNull);
        for (var i = 0; i < 4; i++) {
          expect(a.targetAt(i, languages: 3), a.levels[i].target, reason: a.id);
        }
      }
      expect(byId('wins').learn, isFalse);
    });

    test('completing a language does not ask for them', () async {
      final s = AppState();
      await s.load();
      final mine = s.achOf('fr');
      for (final a in achievements.where((a) => !a.global)) {
        mine[a.id] = AchState(times: a.count);
      }
      s.stats.langsWon.add('fr');
      expect(s.completedIn('fr'), isTrue);
    });

    test('every learn kind has something to earn', () {
      for (final k in LearnKind.values) {
        final (_, earned) = play([event(k)]);
        expect(earned, isNotEmpty, reason: k.name);
      }
    });
  });

  group('practice', () {
    test('a word counts when it was well played, not when it was typed in', () {
      final (s, earned) = play([
        event(LearnKind.free, questions: 1, skill: 100),
        event(LearnKind.free, skill: 79),
        event(LearnKind.free, skill: 80),
      ]);
      expect(s['learn_words']!.value, 1);
      expect(earned, contains('learn_words:0'));
    });

    test('flawless needs three guesses, all of them the best', () {
      final (s, _) = play([
        event(LearnKind.free, questions: 2, right: 2),
        event(LearnKind.free, questions: 4, right: 3),
        event(LearnKind.free, questions: 3, right: 3),
      ]);
      expect(s['learn_flawless']!.value, 1);
    });

    test('unaided needs no hint and a skill of 90', () {
      final (s, _) = play([
        event(LearnKind.free, hints: 1, skill: 99),
        event(LearnKind.free, skill: 89),
        event(LearnKind.free, skill: 90),
      ]);
      expect(s['learn_unaided']!.value, 1);
    });
  });

  group('the drills', () {
    test('a round counts when finished; a perfect one counts again', () {
      final (s, earned) = play([
        event(LearnKind.choose, right: 9),
        event(LearnKind.choose, right: 10),
      ]);
      expect(s['learn_rounds']!.value, 2);
      expect(s['learn_perfect']!.value, 1);
      expect(earned, containsAll(['learn_rounds:0', 'learn_perfect:0']));
    });

    test('closing has its own count and its own perfect round', () {
      final (s, _) = play([
        event(LearnKind.closing, right: 8),
        event(LearnKind.closing),
        event(LearnKind.choose),
      ]);
      expect(s['learn_closing']!.value, 2);
      expect(s['learn_closing_perfect']!.value, 1);
      expect(s['learn_rounds']!.value, 1, reason: 'the other drill apart');
    });

    test('a short round is not a perfect one', () {
      final (s, _) = play([
        event(LearnKind.choose, questions: 3, right: 3),
        event(LearnKind.closing, questions: 3, right: 3),
      ]);
      expect(s['learn_perfect']!.value, 0);
      expect(s['learn_closing_perfect']!.value, 0);
    });
  });

  group('three words', () {
    test('a set counts from skill 70, sharp from 90, the best from 99', () {
      final (s, earned) = play([
        event(LearnKind.sequence, skill: 69),
        event(LearnKind.sequence, skill: 70),
        event(LearnKind.sequence, skill: 90),
        event(LearnKind.sequence, skill: 99),
        event(LearnKind.sequence, skill: 100),
      ]);
      expect(s['learn_sequences']!.value, 4);
      expect(s['learn_sequence_sharp']!.value, 3);
      expect(s['learn_sequence_best']!.value, 2);
      expect(
        earned,
        containsAll([
          'learn_sequences:0',
          'learn_sequence_sharp:0',
          'learn_sequence_best:0',
        ]),
      );
    });

    test('the other modes do not feed them', () {
      final (s, _) = play([event(LearnKind.choose), event(LearnKind.free)]);
      expect(s['learn_sequences']!.value, 0);
    });
  });

  group('days, languages and lengths', () {
    test('the streak counts days in a row, and starts again after a gap', () {
      final (s, earned) = play([
        event(LearnKind.free, date: '2026-10-30'),
        event(LearnKind.choose, date: '2026-10-31'),
        event(LearnKind.closing, date: '2026-10-31'),
        event(LearnKind.free, date: '2026-11-01'),
        event(LearnKind.free, date: '2026-11-04'),
      ]);
      expect(s['learn_streak']!.value, 3, reason: 'the best run is kept');
      expect(s['learn_streak']!.progress, 1);
      expect(earned, contains('learn_streak:0'));
    });

    test('the streak crosses a month end', () {
      final (s, _) = play([
        event(LearnKind.free, date: '2026-10-30'),
        event(LearnKind.free, date: '2026-10-31'),
        event(LearnKind.free, date: '2026-11-01'),
      ]);
      expect(s['learn_streak']!.value, 3);
    });

    test('languages and lengths count the different ones', () {
      final (s, earned) = play([
        event(LearnKind.free, language: 'fr', length: 5),
        event(LearnKind.free, language: 'fr', length: 4),
        event(LearnKind.free, language: 'de', length: 5),
        event(LearnKind.free, language: 'de', length: 5),
      ]);
      expect(s['learn_languages']!.value, 2);
      expect(s['learn_lengths']!.value, 2);
      expect(earned, containsAll(['learn_languages:0', 'learn_lengths:0']));
    });

    test('a full lesson is every mode in one day, counted once a day', () {
      final (s, earned) = play([
        event(LearnKind.free, date: '2026-11-01'),
        event(LearnKind.choose, date: '2026-11-01'),
        event(LearnKind.sequence, date: '2026-11-01'),
        event(LearnKind.free, date: '2026-11-02'),
        event(LearnKind.closing, date: '2026-11-02'),
        event(LearnKind.choose, date: '2026-11-02'),
        event(LearnKind.sequence, date: '2026-11-02'),
        event(LearnKind.free, date: '2026-11-02'),
      ]);
      expect(s['learn_all_three']!.value, 1, reason: 'only the second day');
      expect(
        earned.where((e) => e.startsWith('learn_all_three')),
        hasLength(1),
      );
      final (t, _) = play([
        for (final d in ['2026-11-01', '2026-11-02'])
          for (final k in LearnKind.values) event(k, date: d),
      ]);
      expect(t['learn_all_three']!.value, 2);
    });
  });

  group('levels', () {
    test('each level is earned as its number is reached, and dated', () {
      final (s, earned) = play([
        for (var i = 0; i < 5; i++)
          event(LearnKind.choose, date: '2026-11-0${i + 1}'),
      ]);
      expect(s['learn_rounds']!.times, 2);
      expect(s['learn_rounds']!.dates, ['2026-11-01', '2026-11-05']);
      expect(earned.where((e) => e.startsWith('learn_rounds')), [
        'learn_rounds:0',
        'learn_rounds:1',
      ]);
    });

    test('the top level starts a new round, as the other counters do', () {
      final (s, earned) = play([
        for (var i = 0; i < 100; i++) event(LearnKind.closing),
      ]);
      final st = s['learn_closing']!;
      expect(st.times, 4);
      expect(st.rounds, 1);
      expect(st.value, 0);
      expect(earned.where((e) => e.startsWith('learn_closing:')), hasLength(4));
    });
  });

  group('in the app', () {
    test('recording a round earns, saves and tells the screens', () async {
      final s = AppState();
      await s.load();
      var told = 0;
      s.addListener(() => told++);
      final earned = s.recordLearn(event(LearnKind.choose));
      expect([for (final a in earned) a.id], contains('learn_rounds'));
      expect(told, 1);
      expect(
        s.achOf('de')['learn_rounds']!.times,
        1,
        reason: 'global: in view whatever the language',
      );
      final again = AppState();
      await again.load();
      expect(again.achOf('fr')['learn_rounds']!.times, 1);
      expect(again.learnLog.events, hasLength(1));
    });

    test('the achievements are worked out again from the log', () async {
      final s = AppState();
      await s.load();
      for (var i = 0; i < 5; i++) {
        s.recordLearn(event(LearnKind.choose, date: '2026-11-0${i + 1}'));
      }
      final before = s.achOf('')['learn_rounds']!.toJson();
      s.achOf('').remove('learn_rounds');
      s.rebuildAchievements();
      expect(s.achOf('')['learn_rounds']!.toJson(), before);
    });

    test('a backup carries them; one from before learn mode keeps them', () async {
      final source = AppState();
      await source.load();
      source.recordLearn(event(LearnKind.closing));
      final text = backupToText(source);
      final b = parseBackup(text);
      expect(b.achievements['learn_closing']!.times, 1);
      expect(b.earned, 2, reason: 'the round, and the perfect round');

      final fresh = AppState();
      await fresh.load();
      fresh.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
        learn: b.learn,
      );
      expect(fresh.achOf('')['learn_closing']!.times, 1);

      // an old backup has no learn log and no learn achievements: what is kept
      // here stays, and so do the levels it earned
      final raw = jsonDecode(text) as Map<String, dynamic>
        ..remove('learn')
        ..['achievements'] = <String, dynamic>{};
      final old = parseBackup(jsonEncode(raw));
      fresh.restore(
        settings: old.settings,
        stats: old.stats,
        ach: old.achievements,
        languages: old.languages,
        learn: old.learn,
      );
      expect(fresh.learnLog.events, hasLength(1));
      expect(fresh.achOf('')['learn_closing']!.times, 1);
    });
  });
}
