import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/reminders.dart';
import 'package:lexodle/reminders_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeScheduler implements NotificationScheduler {
  FakeScheduler({this.allow = true, this.on = true});
  bool allow;
  final bool on;
  var asked = 0;
  final plans = <List<PlannedNudge>>[];
  @override
  bool get supported => on;
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
  });
  tearDown(() => Reminders.scheduler = const NoopScheduler());

  Future<void> show(WidgetTester tester, {TimePick? pick}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: pick == null
            ? const RemindersPage()
            : RemindersPage(pickTime: pick),
      ),
    );
    await tester.pump();
  }

  testWidgets('the switch asks for the permission and turns on', (
    tester,
  ) async {
    final fake = Reminders.scheduler = FakeScheduler();
    await show(tester);
    expect(find.byKey(const ValueKey('reminders-time-0')), findsNothing);
    expect(fake.asked, 0);
    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pump();
    expect(fake.asked, 1);
    expect(appState.reminders.on, isTrue);
    expect(find.text('19:30'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-dailies')), findsOneWidget);
    for (var d = 1; d <= 7; d++) {
      expect(find.byKey(ValueKey('reminders-day-0-$d')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pump();
    expect(appState.reminders.on, isFalse);
  });

  testWidgets('a denied permission puts the switch back off', (tester) async {
    Reminders.scheduler = FakeScheduler(allow: false);
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pump();
    expect(appState.reminders.on, isFalse);
    expect(find.byKey(const ValueKey('reminders-denied')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-time-0')), findsNothing);
  });

  testWidgets('the time is changed with the picker', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(
      tester,
      pick: (_, initial) async {
        expect(initial, const TimeOfDay(hour: 19, minute: 30));
        return const TimeOfDay(hour: 7, minute: 5);
      },
    );
    await tester.tap(find.byKey(const ValueKey('reminders-change-time-0')));
    await tester.pump();
    expect(appState.reminders.reminders.first.minutes, 7 * 60 + 5);
    expect(find.text('07:05'), findsOneWidget);
  });

  testWidgets('a cancelled picker changes nothing', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester, pick: (_, _) async => null);
    await tester.tap(find.byKey(const ValueKey('reminders-change-time-0')));
    await tester.pump();
    expect(
      appState.reminders.reminders.first.minutes,
      ReminderTime.defaultMinutes,
    );
  });

  testWidgets('weekdays toggle and one always stays', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('reminders-day-0-6')));
    await tester.pump();
    expect(appState.reminders.reminders.first.days, {1, 2, 3, 4, 5, 7});
    await tester.tap(find.byKey(const ValueKey('reminders-day-0-6')));
    await tester.pump();
    expect(appState.reminders.reminders.first.days.length, 7);
    for (var d = 1; d <= 6; d++) {
      await tester.tap(find.byKey(ValueKey('reminders-day-0-$d')));
      await tester.pump();
    }
    expect(appState.reminders.reminders.first.days, {7});
    await tester.tap(find.byKey(const ValueKey('reminders-day-0-7')));
    await tester.pump();
    expect(appState.reminders.reminders.first.days, {7});
  });

  testWidgets('a second reminder is added and removed', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester);
    expect(find.byKey(const ValueKey('reminders-remove-1')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('reminders-add')));
    await tester.tap(find.byKey(const ValueKey('reminders-add')));
    await tester.pump();
    expect(appState.reminders.reminders.length, 2);
    expect(find.byKey(const ValueKey('reminders-time-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-add')), findsNothing);
    // the second has its own weekdays
    await tester.ensureVisible(find.byKey(const ValueKey('reminders-day-1-3')));
    await tester.tap(find.byKey(const ValueKey('reminders-day-1-3')));
    await tester.pump();
    expect(appState.reminders.reminders[1].days, {1, 2, 4, 5, 6, 7});
    expect(appState.reminders.reminders[0].days.length, 7);
    await tester.ensureVisible(
      find.byKey(const ValueKey('reminders-remove-1')),
    );
    await tester.tap(find.byKey(const ValueKey('reminders-remove-1')));
    await tester.pump();
    expect(appState.reminders.reminders.length, 1);
    expect(find.byKey(const ValueKey('reminders-add')), findsOneWidget);
  });

  testWidgets('the second reminder has its own time', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(
      const ReminderSettings(
        on: true,
        reminders: [
          ReminderTime(),
          ReminderTime(minutes: 12 * 60),
        ],
      ),
    );
    await show(
      tester,
      pick: (_, _) async => const TimeOfDay(hour: 13, minute: 0),
    );
    await tester.tap(find.byKey(const ValueKey('reminders-change-time-1')));
    await tester.pump();
    expect(appState.reminders.reminders[1].minutes, 13 * 60);
    expect(
      appState.reminders.reminders[0].minutes,
      ReminderTime.defaultMinutes,
    );
  });

  testWidgets('the open notification has its own switch and time', (
    tester,
  ) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(
      tester,
      pick: (_, initial) async {
        expect(initial, const TimeOfDay(hour: 8, minute: 0));
        return const TimeOfDay(hour: 6, minute: 45);
      },
    );
    expect(find.text('tell me when the dailies open'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reminders-available-time')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('reminders-available-switch')));
    await tester.pump();
    expect(appState.reminders.available, isTrue);
    expect(find.text('08:00'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('reminders-available-change-time')),
    );
    await tester.pump();
    expect(appState.reminders.availableMinutes, 6 * 60 + 45);
    expect(find.text('06:45'), findsOneWidget);
    // the reminders are untouched
    expect(
      appState.reminders.reminders.single.minutes,
      ReminderTime.defaultMinutes,
    );
  });

  testWidgets('another turns the sample line', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester);
    String title() => tester
        .widget<Text>(find.byKey(const ValueKey('reminders-sample-title')))
        .data!;
    final first = title();
    await tester.tap(find.byKey(const ValueKey('reminders-another')));
    await tester.pump();
    expect(title(), isNot(first));
  });

  testWidgets('without plugin support the page says so', (tester) async {
    Reminders.scheduler = const NoopScheduler();
    await show(tester);
    expect(find.text('reminders work on the phone app'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-switch')), findsNothing);
  });
}
