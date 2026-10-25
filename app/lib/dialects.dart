import 'dart:math';

import 'store.dart';

/// Languages that used to be offered once for each variant and are now one:
/// English (US and UK) is `en`, Portuguese (Brazil and Portugal) is `pt`. What
/// was kept under the old code (the statistics, the history, the daily calendar
/// and streak, the playstyle, the achievements) moves to the new one, here
/// when the app reads its storage and when it reads a backup.
const mergedLanguages = {'en-GB': 'en', 'pt-PT': 'pt'};

/// The code a language goes by now: [code] itself, or the language it was
/// merged into.
String languageCode(String code) => mergedLanguages[code] ?? code;

/// An achievement state with the languages it counted put under the codes they
/// have now: a player who had won in both English variants counted two
/// languages and now counts one, so [AchState.progress] drops by what merged.
/// A badge (see [Track.badges]) is earned once for each language, so it also
/// loses an earning, and the latest day, for each that merged away. States that
/// count nothing by language come back as they were.
AchState foldMergedLanguages(AchState s, {bool badges = false}) {
  final seen = {for (final x in s.seen) languageCode(x)};
  if (seen.length == s.seen.length && seen.containsAll(s.seen)) return s;
  final shrunk = s.seen.length - seen.length;
  final dates = List.of(s.dates);
  if (badges) {
    for (var i = 0; i < shrunk && dates.isNotEmpty; i++) {
      dates.removeLast();
    }
  }
  return AchState(
    times: badges ? max(0, s.times - shrunk) : s.times,
    dates: dates,
    progress: max(0, s.progress - shrunk),
    seen: seen,
  );
}

/// Two states of one achievement joined: it counts as earned as often as the
/// more often earned of the two (it is one language now, not two), on every day
/// either was earned, with the further progress and everything either counted.
AchState mergeAchState(AchState a, AchState b) => AchState(
  times: max(a.times, b.times),
  dates: ({...a.dates, ...b.dates}.toList()..sort()),
  progress: max(a.progress, b.progress),
  seen: {...a.seen, ...b.seen},
);

Map<String, AchState> mergeAchStates(
  Map<String, AchState> a,
  Map<String, AchState> b,
) {
  final out = Map<String, AchState>.of(a);
  for (final e in b.entries) {
    final mine = out[e.key];
    out[e.key] = mine == null ? e.value : mergeAchState(mine, e.value);
  }
  return out;
}

/// Two daily calendars joined: on a day both have, the better of the two
/// results (see [dailyMissed], [dailySolved], [dailyDouble]).
Map<String, int> mergeDailyLogs(Map<String, int> a, Map<String, int> b) {
  final out = Map<String, int>.of(a);
  for (final e in b.entries) {
    out[e.key] = max(out[e.key] ?? e.value, e.value);
  }
  return out;
}

/// What a backup held for two variants, joined as they are when read from
/// storage: the first one's playstyle when it has one, what was held by both,
/// the changes added up, the better calendar and best streak.
LanguageKept mergeKept(LanguageKept a, LanguageKept b) => LanguageKept(
  style: a.style ?? b.style,
  held: a.held == null && b.held == null ? null : {...?a.held, ...?b.held},
  changes: a.changes == null && b.changes == null
      ? null
      : (a.changes ?? 0) + (b.changes ?? 0),
  dailyLog: a.dailyLog == null && b.dailyLog == null
      ? null
      : mergeDailyLogs(a.dailyLog ?? const {}, b.dailyLog ?? const {}),
  dailyBest: a.dailyBest == null && b.dailyBest == null
      ? null
      : max(a.dailyBest ?? 0, b.dailyBest ?? 0),
  achievements: mergeAchStates(a.achievements, b.achievements),
);
