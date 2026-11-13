import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'reminders.dart';
import 'ui.dart';

/// Opens a time picker; tests replace it.
typedef TimePick = Future<TimeOfDay?> Function(BuildContext, TimeOfDay);

Future<TimeOfDay?> _nativePick(BuildContext context, TimeOfDay initial) =>
    showTimePicker(context: context, initialTime: initial);

/// The reminders: a switch, the time of day, and the weekdays. The dailies it is
/// about are the ones chosen on Today. On the web and the desktop there is
/// nothing to schedule with, and the page says so.
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, this.pickTime = _nativePick});
  final TimePick pickTime;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  var _denied = false;
  var _sample = 0;

  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Future<void> _switch(bool on) async {
    try {
      if (!on) {
        setState(() => _denied = false);
        appState.setReminders(appState.reminders.copyWith(on: false));
        return;
      }
      final ok = await Reminders.askPermission();
      if (!mounted) return;
      setState(() => _denied = !ok);
      appState.setReminders(appState.reminders.copyWith(on: ok));
    } catch (e) {
      appLog.w('reminders', 'switch failed ${e.runtimeType}');
    }
  }

  /// Picks a time; [i] is the reminder, or null for the "open" notification.
  Future<void> _time(int? i) async {
    try {
      final r = appState.reminders;
      final now = i == null ? r.availableMinutes : r.reminders[i].minutes;
      final t = await widget.pickTime(
        context,
        TimeOfDay(hour: now ~/ 60, minute: now % 60),
      );
      if (t == null) return;
      final m = t.hour * 60 + t.minute;
      appState.setReminders(
        i == null
            ? r.copyWith(availableMinutes: m)
            : r.withReminder(i, r.reminders[i].copyWith(minutes: m)),
      );
    } catch (e) {
      appLog.w('reminders', 'time failed ${e.runtimeType}');
    }
  }

  void _day(int i, int weekday) {
    try {
      final r = appState.reminders;
      final days = {...r.reminders[i].days};
      if (!days.remove(weekday)) {
        days.add(weekday);
      } else if (days.isEmpty) {
        return; // one day stays
      }
      appState.setReminders(
        r.withReminder(i, r.reminders[i].copyWith(days: days)),
      );
    } catch (e) {
      appLog.w('reminders', 'day failed ${e.runtimeType}');
    }
  }

  void _add() {
    try {
      final r = appState.reminders;
      if (r.reminders.length >= ReminderSettings.maxReminders) return;
      appState.setReminders(
        r.copyWith(
          reminders: [
            ...r.reminders,
            const ReminderTime(minutes: 12 * 60),
          ],
        ),
      );
    } catch (e) {
      appLog.w('reminders', 'add failed ${e.runtimeType}');
    }
  }

  void _remove(int i) {
    try {
      final r = appState.reminders;
      if (i == 0 || i >= r.reminders.length) return; // the first stays
      appState.setReminders(
        r.copyWith(
          reminders: [
            for (var k = 0; k < r.reminders.length; k++)
              if (k != i) r.reminders[k],
          ],
        ),
      );
    } catch (e) {
      appLog.w('reminders', 'remove failed ${e.runtimeType}');
    }
  }

  void _available(bool on) {
    try {
      appState.setReminders(appState.reminders.copyWith(available: on));
    } catch (e) {
      appLog.w('reminders', 'switch failed ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('reminders')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                if (!Reminders.supported) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(19, 16, 19, 32),
                    children: const [
                      Text(
                        'reminders work on the phone app',
                        key: ValueKey('reminders-unsupported'),
                      ),
                    ],
                  );
                }
                final r = appState.reminders;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
                  children: [
                    SwitchListTile(
                      key: const ValueKey('reminders-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('remind me'),
                      subtitle: const Text(
                        'when a daily you chose is still waiting',
                      ),
                      value: r.on,
                      onChanged: _switch,
                    ),
                    if (_denied)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'notifications are not allowed. turn them on in the '
                          'phone settings.',
                          key: const ValueKey('reminders-denied'),
                          style: TextStyle(color: c.error),
                        ),
                      ),
                    if (r.on) ..._controls(c, r),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(ColorScheme c, ReminderSettings r) {
    final names = [
      for (final m in appState.dailiesOf(appState.lang)) m.label.toLowerCase(),
    ];
    final top = appState.dailiesOf(appState.lang).first;
    final text = nudgeText(
      _sample,
      top.label.toLowerCase(),
      appState.dailyStreakFor(appState.lang, top),
      names.length - 1,
    );
    return [
      SwitchListTile(
        key: const ValueKey('reminders-available-switch'),
        contentPadding: EdgeInsets.zero,
        title: const Text('tell me when the dailies open'),
        subtitle: const Text('one notification a day, no matter what is done'),
        value: r.available,
        onChanged: _available,
      ),
      if (r.available)
        _card(
          c,
          Row(
            children: [
              Text(
                _hhmm(r.availableMinutes),
                key: const ValueKey('reminders-available-time'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _button(
                c,
                const ValueKey('reminders-available-change-time'),
                'change time',
                () => _time(null),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'reminding you about',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              names.join(', '),
              key: const ValueKey('reminders-dailies'),
              style: TextStyle(color: c.onSurface.withValues(alpha: dimAlpha)),
            ),
            const SizedBox(height: 4),
            Text(
              'the dailies you chose on today',
              style: TextStyle(
                fontSize: 12,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Caption('nudge me if one is still waiting · up to two a day'),
      for (var i = 0; i < r.reminders.length; i++) ...[
        const SizedBox(height: 8),
        _card(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text(
                    _hhmm(r.reminders[i].minutes),
                    key: ValueKey('reminders-time-$i'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _button(
                        c,
                        ValueKey('reminders-change-time-$i'),
                        'change time',
                        () => _time(i),
                      ),
                      if (i > 0) ...[
                        const SizedBox(width: 8),
                        _button(
                          c,
                          ValueKey('reminders-remove-$i'),
                          'remove',
                          () => _remove(i),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    if (d > 1) const SizedBox(width: 4),
                    Expanded(
                      child: _dayButton(
                        c,
                        i,
                        d,
                        r.reminders[i].days.contains(d),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
      if (r.reminders.length < ReminderSettings.maxReminders) ...[
        const SizedBox(height: 8),
        _button(
          c,
          const ValueKey('reminders-add'),
          'add a second reminder',
          _add,
        ),
      ],
      const SizedBox(height: 16),
      const Caption('what it might say'),
      const SizedBox(height: 8),
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.$1,
              key: const ValueKey('reminders-sample-title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              text.$2,
              style: TextStyle(color: c.onSurface.withValues(alpha: dimAlpha)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _button(
        c,
        const ValueKey('reminders-another'),
        'another',
        () => setState(() => _sample++),
      ),
      const SizedBox(height: 8),
      Text(
        '${nudgeLines.length} lines, turning each day. tapping the nudge opens '
        'the daily it names.',
        style: TextStyle(
          fontSize: 12,
          color: c.onSurface.withValues(alpha: dimAlpha),
        ),
      ),
    ];
  }

  String _hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Widget _card(ColorScheme c, Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );

  /// A control inside a card: one shade up.
  Widget _button(ColorScheme c, Key key, String label, VoidCallback onTap) =>
      Material(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label),
          ),
        ),
      );

  Widget _dayButton(ColorScheme c, int index, int weekday, bool on) =>
      Semantics(
        button: true,
        selected: on,
        label: _days[weekday - 1],
        excludeSemantics: true,
        child: Material(
          color: on ? c.secondaryContainer : c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            key: ValueKey('reminders-day-$index-$weekday'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => _day(index, weekday),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Text(
                _days[weekday - 1].substring(0, 3),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: on ? c.onSecondaryContainer : c.onSurface,
                  fontWeight: on ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        ),
      );
}
