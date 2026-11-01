import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_log.dart';

LearnEvent event({
  LearnKind kind = LearnKind.choose,
  String language = 'fr',
  int length = 5,
  String date = '2026-11-01',
  int questions = 10,
  int right = 7,
  double skill = 80,
  int hints = 0,
}) => LearnEvent(
  kind: kind,
  language: language,
  length: length,
  date: date,
  questions: questions,
  right: right,
  avgSkill: skill,
  hints: hints,
);

void main() {
  test('an event survives a round trip through json', () {
    final e = event(kind: LearnKind.free, hints: 2, skill: 63.25);
    final back = LearnEvent.fromJson(jsonDecode(jsonEncode(e.toJson())))!;
    expect(back.kind, LearnKind.free);
    expect(back.language, 'fr');
    expect(back.length, 5);
    expect(back.date, '2026-11-01');
    expect(back.questions, 10);
    expect(back.right, 7);
    expect(back.avgSkill, closeTo(63.3, 0.05));
    expect(back.hints, 2);
  });

  test('a damaged entry is dropped and the rest of the log is kept', () {
    final log = LearnLog.fromJson([
      event().toJson(),
      {'k': 9, 'l': 'fr', 'n': 5, 'd': '2026-11-01', 'q': 1, 'r': 1, 's': 1},
      {'k': 0, 'l': 'fr', 'n': 5, 'd': 'yesterday', 'q': 1, 'r': 1, 's': 1},
      'nonsense',
      event(language: 'de').toJson(),
    ]);
    expect([for (final e in log.events) e.language], ['fr', 'de']);
    expect(LearnLog.fromJson('not a list').isEmpty, isTrue);
  });

  test('right and skill are held to what they can be', () {
    final e = LearnEvent.fromJson({
      'k': 1,
      'l': 'fr',
      'n': 5,
      'd': '2026-11-01',
      'q': 10,
      'r': 40,
      's': 250,
    })!;
    expect(e.right, 10);
    expect(e.avgSkill, 100);
    expect(e.flawless, isTrue);
    expect(event(questions: 0, right: 0).flawless, isFalse);
  });

  test('the log keeps the newest events up to its limit', () {
    final log = LearnLog();
    for (var i = 0; i < learnLogLimit + 5; i++) {
      log.add(event(questions: i + 1, right: 0));
    }
    expect(log.events, hasLength(learnLogLimit));
    expect(log.events.first.questions, 6);
    expect(log.events.last.questions, learnLogLimit + 5);
  });

  test('events are picked by kind, language and length', () {
    final log = LearnLog([
      event(),
      event(kind: LearnKind.sequence),
      event(language: 'de'),
      event(length: 4),
    ]);
    expect(log.where(), hasLength(4));
    expect(log.where(kind: LearnKind.sequence), hasLength(1));
    expect(log.where(language: 'fr'), hasLength(3));
    expect(log.where(language: 'fr', length: 5), hasLength(2));
  });

  test('the trend is the last few skills, oldest first', () {
    final log = LearnLog([
      for (var i = 1; i <= 6; i++) event(skill: i * 10),
      event(language: 'de', skill: 99),
    ]);
    expect(log.recentSkill(4, language: 'fr'), [30, 40, 50, 60]);
    expect(log.recentSkill(10, language: 'fr'), hasLength(6));
    expect(log.recentSkill(3), [50, 60, 99]);
  });

  test('the streak counts days in a row, and survives a day not yet done', () {
    final log = LearnLog([
      event(date: '2026-10-28'),
      event(date: '2026-10-30'),
      event(date: '2026-10-31'),
      event(date: '2026-10-31'),
    ]);
    expect(log.streak('2026-10-31'), 2);
    // nothing yet today: yesterday's run still stands
    expect(log.streak('2026-11-01'), 2);
    // a missed day ends it
    expect(log.streak('2026-11-02'), 0);
    expect(LearnLog().streak('2026-11-01'), 0);
    // across a month end
    final m = LearnLog([event(date: '2026-10-31'), event(date: '2026-11-01')]);
    expect(m.streak('2026-11-01'), 2);
  });

  test('the sparkline has one block per number, low to high', () {
    expect(sparkline(const []), '');
    expect(sparkline(const [0, 100]), '▁█');
    expect(sparkline(const [50]), '▅');
    expect(sparkline(const [-5, 300]), '▁█');
  });
}
