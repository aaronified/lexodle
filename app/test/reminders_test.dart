import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeScheduler implements NotificationScheduler {
  FakeScheduler({this.allow = true});
  bool allow;
  var asked = 0;
  final plans = <List<PlannedNudge>>[];
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<PlannedNudge> plan) async => plans.add(plan);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // friday 13 november 2026, 10:00 local
  final now = DateTime(2026, 11, 13, 10);

  ReminderDaily daily(GameMode m, int streak, [Map<String, int>? log]) =>
      ReminderDaily(m, streak, log ?? {});

  group('settings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await appState.load();
    });

    test('default is off, 19:30, every day', () {
      expect(appState.reminders.on, isFalse);
      expect(appState.reminders.minutes, 19 * 60 + 30);
      expect(appState.reminders.days, ReminderSettings.allDays);
    });

    test('they are saved and read back', () async {
      appState.setReminders(
        const ReminderSettings(on: true, minutes: 8 * 60 + 5, days: {1, 3}),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reminders'), contains('"on":true'));
      await appState.load();
      expect(appState.reminders.on, isTrue);
      expect(appState.reminders.hour, 8);
      expect(appState.reminders.minute, 5);
      expect(appState.reminders.days, {1, 3});
    });

    test('bad stored values fall back', () {
      final r = ReminderSettings.fromJson({
        'on': true,
        'minutes': 99999,
        'days': [0, 9, 'x'],
      });
      expect(r.on, isTrue);
      expect(r.minutes, ReminderSettings.defaultMinutes);
      expect(r.days, ReminderSettings.allDays);
      expect(ReminderSettings.fromJson(null).on, isFalse);
    });

    test('a backup keeps them', () {
      appState.setReminders(
        const ReminderSettings(on: true, minutes: 7 * 60, days: {2, 4}),
      );
      final json = appState.settingsJson();
      expect(json['reminders'], isA<Map>());
      appState.setReminders(const ReminderSettings());
      expect(appState.reminders.on, isFalse);
      appState.restore(settings: json, stats: appState.stats, ach: const {});
      expect(appState.reminders.on, isTrue);
      expect(appState.reminders.minutes, 7 * 60);
      expect(appState.reminders.days, {2, 4});
    });
  });

  group('plan', () {
    test('one notification per selected weekday at the time', () {
      final plan = planReminders(
        settings: const ReminderSettings(on: true, days: {1, 5, 7}),
        now: now,
        dailies: [daily(GameMode.classic, 3)],
      );
      expect(plan.map((n) => n.weekday), [1, 5, 7]);
      expect(
        plan.every((n) => n.first.hour == 19 && n.first.minute == 30),
        isTrue,
      );
      // friday 19:30 is still ahead today; monday and sunday come next
      expect(plan[1].first, DateTime(2026, 11, 13, 19, 30));
      expect(plan[0].first, DateTime(2026, 11, 16, 19, 30));
      expect(plan[2].first, DateTime(2026, 11, 15, 19, 30));
      expect(plan.map((n) => n.id).toSet().length, 3);
    });

    test('a time that has passed today waits a week', () {
      final plan = planReminders(
        settings: const ReminderSettings(on: true, minutes: 9 * 60, days: {5}),
        now: now,
        dailies: [daily(GameMode.classic, 1)],
      );
      expect(plan.single.first, DateTime(2026, 11, 20, 9));
    });

    test('off or no dailies plans nothing', () {
      expect(
        planReminders(
          settings: const ReminderSettings(),
          now: now,
          dailies: [daily(GameMode.classic, 1)],
        ),
        isEmpty,
      );
      expect(
        planReminders(
          settings: const ReminderSettings(on: true),
          now: now,
          dailies: const [],
        ),
        isEmpty,
      );
    });

    test('finished dailies cancel today, not the other days', () {
      final today = dailyDate(DateTime(2026, 11, 13, 19, 30).toUtc());
      final plan = planReminders(
        settings: const ReminderSettings(on: true, days: {5, 6}),
        now: now,
        dailies: [
          daily(GameMode.classic, 2, {today: 1}),
          daily(GameMode.lockdown, 5, {today: 0}),
        ],
      );
      // friday is done: next friday; saturday is tomorrow
      expect(plan[0].first, DateTime(2026, 11, 20, 19, 30));
      expect(plan[1].first, DateTime(2026, 11, 14, 19, 30));
    });

    test('one chosen daily still waiting keeps today', () {
      final today = dailyDate(DateTime(2026, 11, 13, 19, 30).toUtc());
      final plan = planReminders(
        settings: const ReminderSettings(on: true, days: {5}),
        now: now,
        dailies: [
          daily(GameMode.classic, 9, {today: 1}),
          daily(GameMode.lockdown, 2),
        ],
      );
      expect(plan.single.first, DateTime(2026, 11, 13, 19, 30));
      expect(plan.single.mode, GameMode.lockdown);
      expect(plan.single.title + plan.single.body, contains('lockdown'));
      expect(plan.single.title + plan.single.body, isNot(contains('+')));
    });

    test('the longest streak is named and the rest counted', () {
      final plan = planReminders(
        settings: const ReminderSettings(on: true, days: {5}),
        now: now,
        dailies: [
          daily(GameMode.classic, 4),
          daily(GameMode.lockdown, 9),
          daily(GameMode.blind, 9),
        ],
        variant: 0,
      );
      final n = plan.single;
      expect(n.mode, GameMode.lockdown); // first of the tie
      expect(n.body, endsWith(' · +2 more waiting'));
      expect(n.title + n.body, contains('9'));
    });

    test('the lines turn with the variant and the weekday', () {
      String t(int v) => planReminders(
        settings: const ReminderSettings(on: true, days: {1}),
        now: now,
        dailies: [daily(GameMode.classic, 3)],
        variant: v,
      ).single.title;
      expect(t(0), isNot(t(1)));
      expect(t(0), t(nudgeLines.length));
      for (var i = 0; i < nudgeLines.length; i++) {
        final (a, b) = nudgeText(i, 'classic', 3, 0);
        expect('$a$b', equals('$a$b'.toLowerCase()));
        expect('$a$b', isNot(contains('{')));
      }
    });
  });

  group('service', () {
    late FakeScheduler fake;
    setUp(() async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await appState.load();
      fake = FakeScheduler();
      Reminders.scheduler = fake;
      Reminders.now = () => now;
      Reminders.stop();
    });
    tearDown(() {
      Reminders.stop();
      Reminders.scheduler = const NoopScheduler();
    });

    test(
      'schedules when on, only when the plan changes, cancels off',
      () async {
        appState.setReminders(const ReminderSettings(on: true, days: {4}));
        await Reminders.reschedule();
        expect(fake.plans.length, 1);
        expect(fake.plans.last.length, 1);
        await Reminders.reschedule();
        expect(fake.plans.length, 1);
        appState.setReminders(appState.reminders.copyWith(days: {4, 5}));
        await Reminders.reschedule();
        expect(fake.plans.last.length, 2);
        appState.setReminders(appState.reminders.copyWith(on: false));
        await Reminders.reschedule();
        expect(fake.plans.last, isEmpty);
      },
    );

    test('start follows changes in the app', () async {
      Reminders.start();
      await Reminders.reschedule();
      appState.setReminders(const ReminderSettings(on: true, days: {1}));
      await Reminders.reschedule();
      expect(fake.plans.last.single.weekday, 1);
    });

    test('a tap opens the daily it names', () {
      GameMode? opened;
      Reminders.onOpen = (m) => opened = m;
      Reminders.opened('lockdown');
      expect(opened, GameMode.lockdown);
      opened = null;
      Reminders.opened('nonsense');
      Reminders.opened(null);
      expect(opened, isNull);
    });
  });

  group('no plugin support', () {
    test('web and desktop are not supported', () {
      expect(
        remindersSupported(web: true, platform: TargetPlatform.android),
        isFalse,
      );
      expect(
        remindersSupported(web: false, platform: TargetPlatform.linux),
        isFalse,
      );
      expect(
        remindersSupported(web: false, platform: TargetPlatform.windows),
        isFalse,
      );
      expect(
        remindersSupported(web: false, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test('the no-op scheduler does nothing and says no', () async {
      const s = NoopScheduler();
      expect(s.supported, isFalse);
      expect(await s.requestPermission(), isFalse);
      await s.replaceAll([]);
    });

    test('the service does nothing without a supported scheduler', () async {
      Reminders.scheduler = const NoopScheduler();
      Reminders.stop();
      Reminders.start();
      await Reminders.reschedule();
      expect(Reminders.supported, isFalse);
    });
  });
}
