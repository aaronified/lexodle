import 'package:flutter/material.dart';

import 'app_log.dart';
import 'daily.dart';
import 'main.dart';
import 'mode_strip.dart';
import 'modes.dart';
import 'ui.dart';

/// How a day of a daily log looks in the streak week and its month.
enum _Mark { solved, double, ongoing, lost, none }

const _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// The streak of one daily at a time: pills for the modes that have a daily and
/// are chosen, the streak and best, the last seven days (today last) with a
/// mark each, and a button that opens the current month with the same marks.
/// Green flames are solved days (two for a super solved), yellow is today still
/// to play or under way, a skull a daily played and lost, a dim flame a day not
/// played. It listens to [appState] for itself.
class StreakWeek extends StatefulWidget {
  const StreakWeek({super.key});

  @override
  State<StreakWeek> createState() => _StreakWeekState();
}

class _StreakWeekState extends State<StreakWeek> {
  GameMode? _picked;
  bool _month = false;

  GameMode _current(List<GameMode> modes) => modes.contains(_picked)
      ? _picked!
      : modes.contains(appState.mode)
      ? appState.mode
      : modes.isNotEmpty
      ? modes.first
      : appState.mode;

  /// Makes the neighbour at [step] (+1 next, -1 previous) the mode in view.
  void _step(List<GameMode> modes, int step) {
    try {
      if (modes.length < 2) return;
      final i = modes.indexOf(_current(modes));
      setState(() => _picked = modes[(i + step) % modes.length]);
    } catch (e) {
      appLog.w('streak_week', 'could not change the mode: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: appState, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final c = Theme.of(context).colorScheme;
    final lang = appState.lang;
    final modes = appState.dailiesOf(lang);
    final mode = _current(modes);
    final many = modes.length > 1;
    final index = modes.indexOf(mode);

    Widget arrow(String glyph, String label, int step, Key key) => SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(6),
          onTap: many ? () => _step(modes, step) : null,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                fontSize: 24,
                color: c.onSurface.withValues(alpha: many ? 1 : dimAlpha),
              ),
            ),
          ),
        ),
      ),
    );

    final header = Row(
      children: [
        arrow('\u2039', 'previous mode', -1, const ValueKey('sw-prev')),
        Expanded(
          child: Column(
            children: [
              if (modes.isNotEmpty)
                ModeStrip(
                  key: const ValueKey('sw-strip'),
                  modes: modes,
                  selected: mode,
                  caption: null,
                  label: 'streak',
                  onChanged: (m) => setState(() => _picked = m),
                  onTap: () {},
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < modes.length; i++)
                    Container(
                      key: ValueKey('sw-dot-$i'),
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == index
                            ? c.onSurface
                            : c.onSurface.withValues(alpha: .25),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        arrow('\u203a', 'next mode', 1, const ValueKey('sw-next')),
      ],
    );

    return Container(
      key: const ValueKey('streak-week'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        border: Border.fromBorderSide(hairline(c)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 6),
          _page(c, lang, mode),
        ],
      ),
    );
  }

  /// The content of the card for one mode: streak line, week or month.
  Widget _page(ColorScheme c, String lang, GameMode mode) {
    final today = dailyDate();
    final log = appState.dailyLogOf(lang, mode);
    final streak = appState.dailyStreakFor(lang, mode);
    final best = appState.dailyBestOf(lang, mode);

    var underWay = false;
    try {
      final e = appState.dailyFor(lang, today, mode);
      underWay = e != null && !e.over && e.guesses.isNotEmpty;
    } catch (e) {
      appLog.w('streak_week', 'could not read the daily: ${e.runtimeType}');
    }

    _Mark markOf(String date) {
      final t = log[date];
      if (t == dailyMissed) return _Mark.lost;
      if (t == dailyDouble) return _Mark.double;
      if (t == dailySolved) return _Mark.solved;
      if (date == today && (underWay || streak > 0)) return _Mark.ongoing;
      return _Mark.none;
    }

    Color colorOf(_Mark m) => switch (m) {
      _Mark.solved || _Mark.double => c.secondary,
      _Mark.ongoing => yellowOf(c),
      _Mark.lost => heartColor(c),
      _Mark.none => c.outlineVariant,
    };

    String describe(_Mark m) => switch (m) {
      _Mark.solved => 'solved',
      _Mark.double => 'super solved',
      _Mark.ongoing => 'ongoing',
      _Mark.lost => 'not solved',
      _Mark.none => 'not played',
    };

    Widget flames(String id, _Mark m, double size) {
      final color = colorOf(m);
      if (m == _Mark.lost) {
        return TablerIcon(
          'skull',
          key: ValueKey('sw-skull-$id'),
          size: size,
          color: color,
        );
      }
      if (m != _Mark.double) {
        return TablerIcon(
          'flame',
          key: ValueKey('sw-flame-$id-0'),
          size: size,
          color: color,
        );
      }
      final s = size * .82;
      return SizedBox(
        width: size + s * .4,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: TablerIcon(
                'flame',
                key: ValueKey('sw-flame-$id-0'),
                size: s,
                color: color,
              ),
            ),
            Positioned(
              right: 0,
              child: TablerIcon(
                'flame',
                key: ValueKey('sw-flame-$id-1'),
                size: s,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget cell(
      String prefix,
      String date, {
      required Widget top,
      required Widget bottom,
      required bool mark,
      bool bordered = false,
    }) {
      final m = markOf(date);
      final isToday = date == today;
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: mark ? '$date: ${describe(m)}' : date,
        child: Container(
          key: ValueKey('sw-$prefix-$date'),
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isToday ? c.secondaryContainer : null,
            // the month's days are the only bordered thing in the app
            border: bordered && !isToday
                ? Border.all(color: c.outlineVariant)
                : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [top, const SizedBox(height: 4), bottom],
          ),
        ),
      );
    }

    Widget dim(String t) => Text(
      t,
      style: TextStyle(
        fontSize: 11,
        color: c.onSurface.withValues(alpha: dimAlpha),
      ),
    );

    final week = dailyRolling(today);
    final weekRow = Row(
      children: [
        for (final date in week)
          Expanded(
            child: cell(
              'week',
              date,
              mark: true,
              top: dim(dailyLetter(date)),
              bottom: flames('w-$date', markOf(date), 22),
            ),
          ),
      ],
    );

    Widget monthGrid() {
      final d = DateTime.tryParse(today);
      if (d == null) return const SizedBox.shrink();
      final first = DateTime.utc(d.year, d.month, 1);
      final days = DateTime.utc(d.year, d.month + 1, 0).day;
      final lead = first.weekday - 1; // monday first
      final rows = ((lead + days) / 7).ceil();
      Widget empty() => const SizedBox(height: 44);
      return Column(
        children: [
          Row(
            children: [
              for (final h in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
                Expanded(child: Center(child: dim(h))),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var k = 0; k < 7; k++)
                  Expanded(
                    child: () {
                      final day = r * 7 + k - lead + 1;
                      if (day < 1 || day > days) return empty();
                      final date = dailyShift(
                        '${d.year.toString().padLeft(4, '0')}-'
                        '${d.month.toString().padLeft(2, '0')}-01',
                        day - 1,
                      );
                      // days still to come have no mark, only their number
                      final past = date.compareTo(today) <= 0;
                      return cell(
                        'month',
                        date,
                        mark: past,
                        bordered: true,
                        top: past
                            ? flames('m-$date', markOf(date), 20)
                            : const SizedBox(height: 20),
                        bottom: dim('$day'),
                      );
                    }(),
                  ),
              ],
            ),
        ],
      );
    }

    Widget legendItem(String label, Widget icon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    final legend = Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        legendItem('solved', flames('l-s', _Mark.solved, 16)),
        legendItem('super solved', flames('l-d', _Mark.double, 16)),
        legendItem('ongoing', flames('l-o', _Mark.ongoing, 16)),
        legendItem('not solved', flames('l-w', _Mark.lost, 16)),
        legendItem('not played', flames('l-n', _Mark.none, 16)),
      ],
    );

    final streakColor = streak > 0
        ? (markOf(today) == _Mark.ongoing ? yellowOf(c) : c.secondary)
        : c.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          label: '${mode.label} daily streak: $streak days, best $best',
          child: Row(
            children: [
              TablerIcon(
                'flame',
                key: const ValueKey('sw-streak-flame'),
                size: 34,
                color: streakColor,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                key: const ValueKey('sw-streak-count'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Caption('day streak'),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    mode.label,
                    key: const ValueKey('sw-streak-mode'),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                  Text(
                    'best $best',
                    key: const ValueKey('sw-streak-best'),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!_month) ...[weekRow, const SizedBox(height: 12)],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('sw-month-toggle'),
            onPressed: () => setState(() => _month = !_month),
            child: Text(_month ? 'back to the week' : 'show the month'),
          ),
        ),
        if (_month) ...[
          const SizedBox(height: 14),
          Text(() {
            final d = DateTime.tryParse(today);
            return d == null ? '' : _months[d.month - 1];
          }(), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          monthGrid(),
          const SizedBox(height: 12),
          legend,
        ],
      ],
    );
  }
}
