import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each language keeps its own reminders', () async {
    SharedPreferences.setMockInitialValues({});
    await appState.load();
    appState.setRemindersOf(
      'en',
      const ReminderSettings(on: true, reminders: [ReminderTime(minutes: 600)]),
    );
    expect(appState.remindersOf('en').on, isTrue);
    expect(appState.remindersOf('fr').on, isFalse);
    appState.setRemindersOf(
      'fr',
      const ReminderSettings(on: true, reminders: [ReminderTime(minutes: 700)]),
    );
    await appState.load();
    expect(appState.remindersOf('en').reminders.single.minutes, 600);
    expect(appState.remindersOf('fr').reminders.single.minutes, 700);
  });

  test(
    'the setting saved before they were per language is the language in use',
    () async {
      SharedPreferences.setMockInitialValues({
        'lang': 'fr',
        'reminders': '{"on":true,"minutes":480,"days":[3]}',
      });
      await appState.load();
      expect(appState.remindersOf('fr').on, isTrue);
      expect(appState.remindersOf('fr').reminders.single.minutes, 480);
      expect(appState.remindersOf('en').on, isFalse);
    },
  );

  test('a language has its own notification ids', () {
    expect(languageSlot('en'), 0);
    expect(reminderId(3), 9103);
    expect(availableIdOf(0), availableId);
    final slots = {
      for (final c in [
        'en', 'es', 'fr', 'de', 'it', 'pt', 'nl', 'pl', 'sv', 'da', 'nb', 'tr',
        'ro', 'cs', 'id', 'hu', 'ca', //
      ])
        languageSlot(c),
    };
    expect(slots.length, 17);
    final ids = <int>{
      for (final s in slots) ...[
        for (var d = 1; d <= 7; d++) ...[
          reminderId(d, 0, s),
          reminderId(d, 1, s),
        ],
        availableIdOf(s),
      ],
    };
    // 17 languages x (14 reminders + the open one), no id twice
    expect(ids.length, 17 * 15);
  });

  test(
    'the plan names the dailies of each language that has them on',
    () async {
      SharedPreferences.setMockInitialValues({});
      await appState.load();
      appState.setRemindersOf(
        'fr',
        const ReminderSettings(
          on: true,
          reminders: [ReminderTime(minutes: 700)],
        ),
      );
      Reminders.now = () => DateTime(2026, 11, 2, 8);
      addTearDown(() => Reminders.now = DateTime.now);
      final plan = Reminders.plan();
      expect(plan, isNotEmpty);
      // none of English's: only the language that has them on
      expect(
        plan.every((n) => n.id >= 9100 + languageSlot('fr') * 100),
        isTrue,
      );
    },
  );
}
