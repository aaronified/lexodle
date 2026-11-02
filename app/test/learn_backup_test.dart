import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearnEvent event(String language, {double skill = 80}) => LearnEvent(
  kind: LearnKind.choose,
  language: language,
  length: 5,
  date: '2026-11-01',
  questions: 10,
  right: 8,
  avgSkill: skill,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a recorded round is saved, and found again after a restart', () async {
    final s = AppState();
    await s.load();
    var told = 0;
    s.addListener(() => told++);
    s.recordLearn(event('fr'));
    expect(told, 1);
    expect(s.learnLog.events, hasLength(1));
    final again = AppState();
    await again.load();
    expect(again.learnLog.events, hasLength(1));
    expect(again.learnLog.events.single.language, 'fr');
    expect(again.learnLog.events.single.right, 8);
  });

  test('a damaged saved log is left out, not fatal', () async {
    SharedPreferences.setMockInitialValues({'learnLog': '{not json'});
    final s = AppState();
    await s.load();
    expect(s.learnLog.isEmpty, isTrue);
    expect(s.loaded, isTrue);
  });

  test('the backup carries the log, and a restore brings it back', () async {
    final source = AppState();
    await source.load();
    source.recordLearn(event('fr', skill: 71));
    source.recordLearn(event('de', skill: 93));
    final b = parseBackup(backupToText(source));
    expect(b.learn!.events, hasLength(2));

    final fresh = AppState();
    await fresh.load();
    fresh.recordLearn(event('es'));
    fresh.restore(
      settings: b.settings,
      stats: b.stats,
      ach: b.achievements,
      languages: b.languages,
      learn: b.learn,
    );
    expect([for (final e in fresh.learnLog.events) e.language], ['fr', 'de']);
    // and it was written to storage
    final again = AppState();
    await again.load();
    expect(again.learnLog.events, hasLength(2));
  });

  test('a backup from before learn mode leaves the log alone', () async {
    final source = AppState();
    await source.load();
    final raw = jsonDecode(backupToText(source)) as Map<String, dynamic>
      ..remove('learn');
    final b = parseBackup(jsonEncode(raw));
    expect(b.learn, isNull);
    final s = AppState();
    await s.load();
    s.recordLearn(event('fr'));
    s.restore(
      settings: b.settings,
      stats: b.stats,
      ach: b.achievements,
      languages: b.languages,
      learn: b.learn,
    );
    expect(s.learnLog.events, hasLength(1));
  });

  test('bad entries in the log of a backup are dropped, the file is kept', () {
    final raw = jsonDecode(backupToText(AppState())) as Map<String, dynamic>;
    raw['learn'] = [
      event('fr').toJson(),
      {'nonsense': true},
    ];
    final b = parseBackup(jsonEncode(raw));
    expect(b.learn!.events, hasLength(1));
  });
}
