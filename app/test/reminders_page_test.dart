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
    expect(find.byKey(const ValueKey('reminders-time')), findsNothing);
    expect(fake.asked, 0);
    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pump();
    expect(fake.asked, 1);
    expect(appState.reminders.on, isTrue);
    expect(find.text('19:30'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-dailies')), findsOneWidget);
    for (var d = 1; d <= 7; d++) {
      expect(find.byKey(ValueKey('reminders-day-$d')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('reminders-time')), findsNothing);
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
    await tester.tap(find.byKey(const ValueKey('reminders-change-time')));
    await tester.pump();
    expect(appState.reminders.minutes, 7 * 60 + 5);
    expect(find.text('07:05'), findsOneWidget);
  });

  testWidgets('a cancelled picker changes nothing', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester, pick: (_, _) async => null);
    await tester.tap(find.byKey(const ValueKey('reminders-change-time')));
    await tester.pump();
    expect(appState.reminders.minutes, ReminderSettings.defaultMinutes);
  });

  testWidgets('weekdays toggle and one always stays', (tester) async {
    Reminders.scheduler = FakeScheduler();
    appState.setReminders(const ReminderSettings(on: true));
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('reminders-day-6')));
    await tester.pump();
    expect(appState.reminders.days, {1, 2, 3, 4, 5, 7});
    await tester.tap(find.byKey(const ValueKey('reminders-day-6')));
    await tester.pump();
    expect(appState.reminders.days.length, 7);
    for (var d = 1; d <= 6; d++) {
      await tester.tap(find.byKey(ValueKey('reminders-day-$d')));
      await tester.pump();
    }
    expect(appState.reminders.days, {7});
    await tester.tap(find.byKey(const ValueKey('reminders-day-7')));
    await tester.pump();
    expect(appState.reminders.days, {7});
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
