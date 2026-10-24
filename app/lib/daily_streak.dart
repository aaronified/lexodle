import 'package:flutter/material.dart';

import 'daily.dart';
import 'main.dart';
import 'ui.dart';

/// The home page's daily streak: a fire with the days in a row, and this week
/// (Monday first) with a fire on each day the daily was solved, two when it was
/// a double fire. Unlit fires are days not solved; today has a border.
class DailyStreak extends StatelessWidget {
  const DailyStreak({super.key});

  static const _letters = ['m', 't', 'w', 't', 'f', 's', 's'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final today = dailyDate();
    final week = dailyWeek(today);
    final streak = appState.dailyStreak;
    final lit = c.tertiary;
    final unlit = c.outlineVariant;
    final solvedToday =
        (appState.dailyLog[today] ?? dailyMissed) >= dailySolved;

    Widget flames(String date, int tier) {
      final on = tier >= dailySolved;
      final color = on ? lit : unlit;
      if (tier < dailyDouble) {
        return TablerIcon(
          'flame',
          key: ValueKey('flame-$date-0'),
          size: 22,
          color: color,
        );
      }
      // a double fire: two flames, overlapping
      return SizedBox(
        width: 26,
        height: 22,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: TablerIcon(
                'flame',
                key: ValueKey('flame-$date-0'),
                size: 18,
                color: color,
              ),
            ),
            Positioned(
              right: 0,
              child: TablerIcon(
                'flame',
                key: ValueKey('flame-$date-1'),
                size: 18,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    String describe(String date, int? tier) => tier == null
        ? 'not played'
        : tier == dailyDouble
        ? 'double fire'
        : tier == dailySolved
        ? 'solved'
        : 'missed';

    Widget day(int i) {
      final date = week[i];
      final tier = appState.dailyLog[date];
      final isToday = date == today;
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: '$date: ${describe(date, tier)}',
        child: Container(
          key: ValueKey('daily-day-$date'),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday
                  ? c.onSurface.withValues(alpha: .5)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _letters[i],
                style: TextStyle(
                  fontSize: 11,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
              const SizedBox(height: 4),
              flames(date, tier ?? -1),
            ],
          ),
        ),
      );
    }

    // the streak on top and the week under it, each across the full width, so
    // seven days fit on the narrowest phone
    return Container(
      key: const ValueKey('daily-streak'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label: 'daily streak: $streak days, best ${appState.dailyBest}',
            child: Row(
              children: [
                TablerIcon(
                  'flame',
                  key: const ValueKey('streak-flame'),
                  size: 34,
                  color: solvedToday ? lit : unlit,
                ),
                const SizedBox(width: 6),
                Text(
                  '$streak',
                  key: const ValueKey('streak-count'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                const Caption('day streak'),
                const Spacer(),
                Text(
                  'best ${appState.dailyBest}',
                  key: const ValueKey('streak-best'),
                  style: TextStyle(
                    fontSize: 11,
                    color: c.onSurface.withValues(alpha: dimAlpha),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < week.length; i++) Expanded(child: day(i)),
            ],
          ),
        ],
      ),
    );
  }
}
