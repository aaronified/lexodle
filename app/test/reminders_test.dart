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

ReminderSettings rs({
  bool on = true,
  int minutes = ReminderTime.defaultMinutes,
  Set<int> days = ReminderTime.allDays,
  bool available = false,
}) => ReminderSettings(
  on: on,
  reminders: [ReminderTime(minutes: minutes, days: days)],
  available: available,
);

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
      expect(appState.reminders.reminders.single.minutes, 19 * 60 + 30);
      expect(appState.reminders.reminders.single.days, ReminderTime.allDays);
      expect(appState.reminders.available, isFalse);
      expect(appState.reminders.availableMinutes, 8 * 60);
    });

    test('they are saved and read back', () async {
      appState.setReminders(rs(minutes: 8 * 60 + 5, days: {1, 3}));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reminders'), contains('"on":true'));
      await appState.load();
      expect(appState.reminders.on, isTrue);
      expect(appState.reminders.reminders.single.hour, 8);
      expect(appState.reminders.reminders.single.minute, 5);
      expect(appState.reminders.reminders.single.days, {1, 3});
    });

    test('settings saved with one time and days become the first reminder', () {
      final r = ReminderSettings.fromJson({
        'on': true,
        'minutes': 7 * 60,
        'days': [1, 2],
      });
      expect(r.reminders.length, 1);
      expect(r.reminders.first.minutes, 7 * 60);
      expect(r.reminders.first.days, {1, 2});
      expect(r.available, isFalse);
    });

    test(
      'two reminders and the open notification are saved and read back',
      () async {
        appState.setReminders(
          const ReminderSettings(
            on: true,
            reminders: [
              ReminderTime(minutes: 600, days: {1}),
              ReminderTime(minutes: 1200, days: {2, 3}),
              ReminderTime(minutes: 5),
            ],
            available: true,
            availableMinutes: 7 * 60 + 30,
          ),
        );
        await appState.load();
        final r = appState.reminders;
        // a third reminder is cut
        expect(r.reminders.length, 2);
        expect(r.reminders[1].minutes, 1200);
        expect(r.reminders[1].days, {2, 3});
        expect(r.available, isTrue);
        expect(r.availableMinutes, 7 * 60 + 30);
      },
    );

    test('bad stored values fall back', () {
      final r = ReminderSettings.fromJson({
        'on': true,
        'minutes': 99999,
        'days': [0, 9, 'x'],
      });
      expect(r.on, isTrue);
      expect(r.reminders.single.minutes, ReminderTime.defaultMinutes);
      expect(r.reminders.single.days, ReminderTime.allDays);
      expect(ReminderSettings.fromJson(null).on, isFalse);
    });

    test('a backup keeps them', () {
      appState.setReminders(rs(minutes: 7 * 60, days: {2, 4}));
      final json = appState.settingsJson();
      expect(json['reminders'], isA<Map>());
      appState.setReminders(const ReminderSettings());
      expect(appState.reminders.on, isFalse);
      appState.restore(settings: json, stats: appState.stats, ach: const {});
      expect(appState.reminders.on, isTrue);
      expect(appState.reminders.reminders.single.minutes, 7 * 60);
      expect(appState.reminders.reminders.single.days, {2, 4});
    });
  });

  group('plan', () {
    test('one notification per selected weekday at the time', () {
      final plan = planReminders(
        settings: rs(days: {1, 5, 7}),
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
        settings: rs(minutes: 9 * 60, days: {5}),
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
        planReminders(settings: rs(), now: now, dailies: const []),
        isEmpty,
      );
    });

    test('finished dailies cancel today, not the other days', () {
      final today = dailyDate(DateTime(2026, 11, 13, 19, 30).toUtc());
      final plan = planReminders(
        settings: rs(days: {5, 6}),
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
        settings: rs(days: {5}),
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
        settings: rs(days: {5}),
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
        settings: rs(days: {1}),
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

  group('two reminders and the open notification', () {
    test('both reminders are planned, with ids of their own', () {
      final plan = planReminders(
        settings: const ReminderSettings(
          on: true,
          reminders: [
            ReminderTime(minutes: 9 * 60, days: {1, 2}),
            ReminderTime(minutes: 21 * 60, days: {2}),
          ],
        ),
        now: now,
        dailies: [daily(GameMode.classic, 3)],
      );
      expect(plan.length, 3);
      expect(plan.map((n) => n.id).toSet().length, 3);
      expect(plan.where((n) => n.first.hour == 21).single.weekday, 2);
      expect(plan.where((n) => n.first.hour == 9).length, 2);
    });

    test('the done check applies to each reminder', () {
      final noon = dailyDate(DateTime(2026, 11, 13, 12).toUtc());
      final night = dailyDate(DateTime(2026, 11, 13, 21).toUtc());
      final plan = planReminders(
        settings: const ReminderSettings(
          on: true,
          reminders: [
            ReminderTime(minutes: 12 * 60, days: {5}),
            ReminderTime(minutes: 21 * 60, days: {5}),
          ],
        ),
        now: now,
        dailies: [
          daily(GameMode.classic, 3, {noon: 1, night: 1}),
        ],
      );
      expect(plan.map((n) => n.first.day), [20, 20]);
    });

    test('the open notification fires every day, whatever is done', () {
      final today = dailyDate(DateTime(2026, 11, 14, 8).toUtc());
      final plan = planReminders(
        settings: const ReminderSettings(on: true, available: true),
        now: now,
        dailies: [
          daily(GameMode.classic, 3, {today: 1}),
          daily(GameMode.lockdown, 1),
        ],
      );
      final open = plan.singleWhere((n) => n.id == availableId);
      expect(open.daily, isTrue);
      // 08:00 has passed today: tomorrow
      expect(open.first, DateTime(2026, 11, 14, 8));
      expect(open.title, 'your dailies are open');
      expect(
        open.title + open.body,
        equals((open.title + open.body).toLowerCase()),
      );
      expect(open.body, contains('lockdown'));
    });

    test('the open notification is not planned when its switch is off or the '
        'master is off', () {
      final d = [daily(GameMode.classic, 3)];
      expect(
        planReminders(
          settings: rs(),
          now: now,
          dailies: d,
        ).any((n) => n.id == availableId),
        isFalse,
      );
      expect(
        planReminders(
          settings: rs(on: false, available: true),
          now: now,
          dailies: d,
        ),
        isEmpty,
      );
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
        appState.setReminders(rs(days: {4}));
        await Reminders.reschedule();
        expect(fake.plans.length, 1);
        expect(fake.plans.last.length, 1);
        await Reminders.reschedule();
        expect(fake.plans.length, 1);
        appState.setReminders(
          appState.reminders.withReminder(0, const ReminderTime(days: {4, 5})),
        );
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
      appState.setReminders(rs(days: {1}));
      await Reminders.reschedule();
      expect(fake.plans.last.single.weekday, 1);
    });

    test('a tap opens the daily it names', () {
      GameMode? opened;
      Reminders.onOpen = (m) => opened = m;
      Reminders.opened('lockdown');
      expect(opened, GameMode.lockdown);
      opened = null;
      GameMode? dug;
      Reminders.openDaily = (m) => dug = m;
      Reminders.opened('blind');
      expect(opened, GameMode.blind);
      expect(dug, GameMode.blind);
      Reminders.openDaily = null;
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
