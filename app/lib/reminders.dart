import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_log.dart';
import 'daily.dart';
import 'main.dart';
import 'modes.dart';

/// One reminder: a time of day and the weekdays it comes on (1 is monday, 7 is
/// sunday, as in [DateTime.weekday]).
@immutable
class ReminderTime {
  const ReminderTime({this.minutes = defaultMinutes, this.days = allDays});

  static const defaultMinutes = 19 * 60 + 30;
  static const allDays = {1, 2, 3, 4, 5, 6, 7};

  /// The time of day, in minutes after midnight.
  final int minutes;
  final Set<int> days;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  ReminderTime copyWith({int? minutes, Set<int>? days}) =>
      ReminderTime(minutes: minutes ?? this.minutes, days: days ?? this.days);

  Map<String, Object> toJson() => {
    'minutes': minutes,
    'days': [...days]..sort(),
  };

  /// Reads what [toJson] wrote; anything unreadable keeps its default.
  static ReminderTime fromJson(Object? j) {
    if (j is! Map) return const ReminderTime();
    final m = j['minutes'];
    final d = j['days'];
    final days = d is List
        ? {
            for (final x in d)
              if (x is int && x >= 1 && x <= 7) x,
          }
        : <int>{};
    return ReminderTime(
      minutes: m is int && m >= 0 && m < 24 * 60 ? m : defaultMinutes,
      days: days.isEmpty ? allDays : days,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime &&
      other.minutes == minutes &&
      setEquals(other.days, days);

  @override
  int get hashCode => Object.hash(minutes, Object.hashAll([...days]..sort()));
}

/// What the player chose for the reminders: the master switch, up to
/// [maxReminders] reminders (each with its own time and weekdays), and the
/// "the dailies are open" notification with its own switch and morning time.
/// The dailies it is about are the ones chosen on Today (`appState.myDailies`).
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.on = false,
    this.reminders = const [ReminderTime()],
    this.available = false,
    this.availableMinutes = defaultAvailableMinutes,
  });

  static const maxReminders = 2;
  static const defaultAvailableMinutes = 8 * 60;

  final bool on;

  /// One or two reminders.
  final List<ReminderTime> reminders;

  /// Whether a notification says the dailies are open, every day.
  final bool available;
  final int availableMinutes;

  ReminderSettings copyWith({
    bool? on,
    List<ReminderTime>? reminders,
    bool? available,
    int? availableMinutes,
  }) => ReminderSettings(
    on: on ?? this.on,
    reminders: reminders ?? this.reminders,
    available: available ?? this.available,
    availableMinutes: availableMinutes ?? this.availableMinutes,
  );

  /// This settings with reminder [i] replaced.
  ReminderSettings withReminder(int i, ReminderTime r) => copyWith(
    reminders: [
      for (var k = 0; k < reminders.length; k++) k == i ? r : reminders[k],
    ],
  );

  Map<String, Object> toJson() => {
    'on': on,
    'reminders': [for (final r in reminders) r.toJson()],
    'available': available,
    'availableMinutes': availableMinutes,
  };

  /// Reads what [toJson] wrote. Settings saved before there were two reminders
  /// (one `minutes` and `days` at the top) become the first reminder; anything
  /// unreadable keeps its default.
  static ReminderSettings fromJson(Object? j) {
    if (j is! Map) return const ReminderSettings();
    final list = j['reminders'];
    var reminders = list is List
        ? [for (final r in list.take(maxReminders)) ReminderTime.fromJson(r)]
        : <ReminderTime>[];
    if (reminders.isEmpty) {
      reminders = [
        j.containsKey('minutes') || j.containsKey('days')
            ? ReminderTime.fromJson(j)
            : const ReminderTime(),
      ];
    }
    final a = j['availableMinutes'];
    return ReminderSettings(
      on: j['on'] == true,
      reminders: reminders,
      available: j['available'] == true,
      availableMinutes: a is int && a >= 0 && a < 24 * 60
          ? a
          : defaultAvailableMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.on == on &&
      other.available == available &&
      other.availableMinutes == availableMinutes &&
      listEquals(other.reminders, reminders);

  @override
  int get hashCode =>
      Object.hash(on, available, availableMinutes, Object.hashAll(reminders));
}

/// The lines a nudge says, picked in turn: a title and a body, with `{mode}`
/// and `{n}` (the streak) filled in.
const nudgeLines = <(String, String)>[
  (
    'your {n} day {mode} streak is looking at the door with a suitcase',
    'it would be a shame to leave it standing there',
  ),
  (
    '{mode} has been waiting for you since this morning',
    'it has started talking to the cushions',
  ),
  (
    'five letters. six tries. one very patient {mode} daily',
    'your {n} day streak says hi',
  ),
  (
    'the word of the day is not going to guess itself',
    'your {n} day {mode} streak is counting on you',
  ),
  (
    'quick, before the streak notices: {mode} is still open',
    '{n} days is a lot to lose over a cup of tea',
  ),
  (
    'your streak asked us to remind you, politely, once more',
    '{mode} · {n} days and counting',
  ),
];

/// The title and body of nudge number [k] (any integer: it wraps) for [mode]
/// with [streak] days, and [more] other dailies still waiting.
(String, String) nudgeText(int k, String mode, int streak, int more) {
  final line = nudgeLines[k % nudgeLines.length];
  String f(String t) =>
      t.replaceAll('{mode}', mode).replaceAll('{n}', '$streak');
  return (f(line.$1), f(line.$2) + (more > 0 ? ' · +$more more waiting' : ''));
}

/// A chosen daily as the plan sees it: its streak now and its log of days
/// (`2026-11-13` to how it went), where a day with an entry is finished.
class ReminderDaily {
  const ReminderDaily(this.mode, this.streak, this.log);
  final GameMode mode;
  final int streak;
  final Map<String, int> log;

  bool doneOn(String date) => log[date] != null;
}

/// One notification: it first shows at [first] (local time) and then every
/// week at the same time ([daily]: every day).
@immutable
class PlannedNudge {
  const PlannedNudge({
    required this.id,
    required this.first,
    required this.title,
    required this.body,
    required this.mode,
    this.daily = false,
  });
  final int id;
  final DateTime first;
  final String title;
  final String body;

  /// The daily the text names (the notification opens it).
  final GameMode mode;

  /// Whether it repeats every day, not every week.
  final bool daily;

  int get weekday => first.weekday;

  @override
  bool operator ==(Object other) =>
      other is PlannedNudge &&
      other.id == id &&
      other.first == first &&
      other.title == title &&
      other.body == body &&
      other.mode == mode &&
      other.daily == daily;

  @override
  int get hashCode => Object.hash(id, first, title, body, mode, daily);

  @override
  String toString() => '$id $first $daily $title | $body';
}

/// The notification id of reminder number [index] (0 or 1) on a weekday.
int reminderId(int weekday, [int index = 0]) => 9100 + index * 10 + weekday;

/// The id of the "the dailies are open" notification.
const availableId = 9200;

/// The notifications to schedule: for each reminder, one for each of its
/// weekdays, at its time; and the "open" notification when it is on. A phone
/// cannot run code when a notification is due, so what is known when a reminder
/// is planned decides: a day whose chosen dailies are all finished (the day
/// being the daily's own, see [dailyDate]) is left to the next week. The text
/// names the waiting daily with the longest streak (the first in the app's
/// order on a tie) and counts the others; [variant] turns the lines. The "open"
/// notification has no such check: it just fires.
List<PlannedNudge> planReminders({
  required ReminderSettings settings,
  required DateTime now,
  required List<ReminderDaily> dailies,
  int variant = 0,
}) {
  if (!settings.on || dailies.isEmpty) return const [];
  final plan = <PlannedNudge>[];
  for (var index = 0; index < settings.reminders.length; index++) {
    if (index >= ReminderSettings.maxReminders) break;
    final r = settings.reminders[index];
    for (final weekday in [...r.days]..sort()) {
      if (weekday < 1 || weekday > 7) continue;
      var first = DateTime(
        now.year,
        now.month,
        now.day + (weekday - now.weekday) % 7,
        r.hour,
        r.minute,
      );
      if (!first.isAfter(now)) first = _plusDays(first, 7);
      var waiting = [
        for (final d in dailies)
          if (!d.doneOn(dailyDate(first.toUtc()))) d,
      ];
      if (waiting.isEmpty) {
        // finished for that day: the first one is next week's
        first = _plusDays(first, 7);
        waiting = dailies;
      }
      var top = waiting.first;
      for (final d in waiting) {
        if (d.streak > top.streak) top = d;
      }
      final text = nudgeText(
        variant + weekday + index,
        top.mode.label.toLowerCase(),
        top.streak,
        waiting.length - 1,
      );
      plan.add(
        PlannedNudge(
          id: reminderId(weekday, index),
          first: first,
          title: text.$1,
          body: text.$2,
          mode: top.mode,
        ),
      );
    }
  }
  if (settings.available) {
    final m = settings.availableMinutes;
    var first = DateTime(now.year, now.month, now.day, m ~/ 60, m % 60);
    if (!first.isAfter(now)) first = _plusDays(first, 1);
    plan.add(
      PlannedNudge(
        id: availableId,
        first: first,
        title: 'your dailies are open',
        body: dailies.map((d) => d.mode.label.toLowerCase()).join(', '),
        mode: dailies.first.mode,
        daily: true,
      ),
    );
  }
  return plan;
}

DateTime _plusDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

/// Whether this platform can schedule the reminders: the phone app (Android).
/// The web and the desktop have no plugin support.
bool remindersSupported({bool? web, TargetPlatform? platform}) =>
    !(web ?? kIsWeb) &&
    (platform ?? defaultTargetPlatform) == TargetPlatform.android;

/// What the reminders need of the phone, so that tests can use a fake.
abstract class NotificationScheduler {
  /// False where there is nothing to schedule with (the web, the desktop).
  bool get supported;

  /// Asks for the permission to show notifications; true when it is given.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [plan] (none cancels them all).
  Future<void> replaceAll(List<PlannedNudge> plan);
}

/// The scheduler of the web and the desktop: it does nothing.
class NoopScheduler implements NotificationScheduler {
  const NoopScheduler();
  @override
  bool get supported => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceAll(List<PlannedNudge> plan) async {}
}

/// The scheduler of the phone app, on `flutter_local_notifications`. Every
/// call is guarded: a failure is logged by its type and the app goes on.
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  @override
  bool get supported => true;

  Future<bool> _init() => _ready ??= () async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) => Reminders.opened(r.payload),
      );
      return true;
    } catch (e) {
      appLog.w('reminders', 'could not start ${e.runtimeType}');
      return false;
    }
  }();

  @override
  Future<bool> requestPermission() async {
    try {
      if (!await _init()) return false;
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      appLog.w('reminders', 'permission failed ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedNudge> plan) async {
    try {
      if (!await _init()) return;
      await _plugin.cancelAllPendingNotifications();
      for (final n in plan) {
        final at = tz.TZDateTime.from(n.first, tz.local);
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: at,
          title: n.title,
          body: n.body,
          payload: n.mode.name,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminders',
              'reminders',
              channelDescription: 'a nudge when a daily you chose is waiting',
            ),
          ),
          // inexact: no exact-alarm permission is needed
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: n.daily
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      appLog.w('reminders', 'schedule failed ${e.runtimeType}');
    }
  }
}

/// The reminders service: keeps the phone's schedule in step with the
/// settings, the chosen dailies and what is finished.
class Reminders {
  const Reminders._();

  /// The scheduler in use; tests put a fake here.
  static NotificationScheduler scheduler = remindersSupported()
      ? LocalNotificationScheduler()
      : const NoopScheduler();

  /// The clock the plan goes by; tests replace it.
  static DateTime Function() now = DateTime.now;

  /// What a tap on a notification does with the daily it names: chooses its
  /// mode. Then [openDaily], when main sets it, opens the daily itself.
  static void Function(GameMode mode) onOpen = (m) => appState.setup(mode: m);

  /// Set by main: opens the daily of the mode (pushes the daily's page).
  static void Function(GameMode mode)? openDaily;

  static bool get supported => scheduler.supported;

  static String? _last;
  static var _started = false;
  static Future<void> _chain = Future.value();

  /// Plans, from what the app holds now.
  static List<PlannedNudge> plan() {
    final lang = appState.lang;
    final t = now();
    return planReminders(
      settings: appState.reminders,
      now: t,
      dailies: [
        for (final m in appState.dailiesOf(lang))
          ReminderDaily(
            m,
            appState.dailyStreakFor(lang, m),
            appState.dailyLogOf(lang, m),
          ),
      ],
      variant: t.difference(DateTime(2026)).inDays,
    );
  }

  /// Follows the app: call once at start. It schedules now and again whenever
  /// the settings, the chosen dailies or a finished daily change the plan.
  static void start() {
    if (_started || !supported) return;
    _started = true;
    appState.addListener(reschedule);
    reschedule();
  }

  /// Stops following (tests).
  static void stop() {
    if (_started) appState.removeListener(reschedule);
    _started = false;
    _last = null;
  }

  /// Puts the plan on the phone when it differs from what is there.
  static Future<void> reschedule() {
    if (!supported) return Future.value();
    return _chain = _chain.then((_) async {
      try {
        final p = appState.reminders.on ? plan() : const <PlannedNudge>[];
        final sig = p.join('\n');
        if (sig == _last) return;
        await scheduler.replaceAll(p);
        _last = sig;
      } catch (e) {
        appLog.w('reminders', 'reschedule failed ${e.runtimeType}');
      }
    });
  }

  /// Asks for the permission, as the player turns reminders on.
  static Future<bool> askPermission() async {
    try {
      return await scheduler.requestPermission();
    } catch (e) {
      appLog.w('reminders', 'permission failed ${e.runtimeType}');
      return false;
    }
  }

  /// A tap on a notification: [payload] is the mode it names.
  static void opened(String? payload) {
    try {
      final m = GameMode.values.where((m) => m.name == payload).firstOrNull;
      if (m == null) return;
      onOpen(m);
      openDaily?.call(m);
    } catch (e) {
      appLog.w('reminders', 'open failed ${e.runtimeType}');
    }
  }
}
