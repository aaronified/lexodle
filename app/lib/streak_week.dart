import 'package:flutter/material.dart';

import 'app_log.dart';
import 'daily.dart';
import 'main.dart';
import 'mode_wheel.dart' show modeIconName;
import 'modes.dart';
import 'open_review.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

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

class _StreakWeekState extends State<StreakWeek>
    with SingleTickerProviderStateMixin {
  GameMode? _picked;
  bool _month = false;

  /// The month the calendar shows, as the first of it; null: the current one.
  /// It opens on the current month each time.
  DateTime? _viewing;
  bool _opening = false;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  /// How far the card has been dragged, in pages: positive shows the next mode,
  /// negative the previous. The calendar follows the finger.
  double _shift = 0;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  GameMode _current(List<GameMode> modes) => modes.contains(_picked)
      ? _picked!
      : modes.contains(appState.mode)
      ? appState.mode
      : modes.isNotEmpty
      ? modes.first
      : appState.mode;

  /// Runs on to the neighbour at [step] (+1 next, -1 previous, 0 stay) from
  /// where the finger left it, then makes that mode the one in view.
  void _settle(List<GameMode> modes, int step) {
    try {
      final from = _shift;
      final to = step.toDouble();
      void land() {
        if (!mounted) return;
        setState(() {
          if (step != 0 && modes.length > 1) {
            final i = modes.indexOf(_current(modes));
            _picked = modes[(i + step).clamp(0, modes.length - 1)];
          }
          _shift = 0;
        });
      }

      _anim.stop();
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        land();
        return;
      }
      _anim.reset();
      void tick() => setState(
        () =>
            _shift = from + (to - from) * Curves.easeOut.transform(_anim.value),
      );
      _anim.addListener(tick);
      _anim.forward().whenComplete(() {
        _anim.removeListener(tick);
        land();
      });
    } catch (e) {
      appLog.w('streak_week', 'could not change the mode: ${e.runtimeType}');
      if (mounted) setState(() => _shift = 0);
    }
  }

  /// Opens the review of the daily of [mode] on [date], the screen the history
  /// opens for that game.
  Future<void> _openDay(String lang, GameMode mode, String date) async {
    if (_opening) return;
    _opening = true;
    try {
      final g = dailyGamesOf(appState.history, lang, mode)[date];
      if (g == null) return;
      final langs = WordBank.loadedLanguages ?? await WordBank.languages();
      final language = langs.where((l) => l.code == g.lang).firstOrNull;
      if (language == null || !mounted) return;
      final why = await openGameReview(context, appState.history, g, language);
      if (why != null && mounted) showToast(context, why);
    } catch (e) {
      appLog.w('streak_week', 'could not open a day: ${e.runtimeType}');
      if (mounted) showToast(context, 'could not open that day');
    } finally {
      _opening = false;
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
    final index = modes.indexOf(mode);
    final last = modes.length - 1;
    // the dot of the page nearest the middle while it is being dragged
    final at = index < 0 ? 0 : (index + _shift).round().clamp(0, last);

    final dots = Row(
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
              color: i == at ? c.onSurface : c.onSurface.withValues(alpha: .25),
            ),
          ),
      ],
    );

    return TonalCard(
      key: const ValueKey('streak-week'),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final many = modes.length > 1;
          // no looping: nothing before the first mode or after the last
          final lo = index > 0 ? -1.0 : 0.0;
          final hi = index >= 0 && index < last ? 1.0 : 0.0;
          return Semantics(
            container: true,
            label: 'streak',
            value: mode.label,
            increasedValue: index < last ? modes[index + 1].label : null,
            decreasedValue: index > 0 ? modes[index - 1].label : null,
            onIncrease: many && index < last ? () => _settle(modes, 1) : null,
            onDecrease: many && index > 0 ? () => _settle(modes, -1) : null,
            child: GestureDetector(
              key: const ValueKey('sw-swipe'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: many ? (_) => _anim.stop() : null,
              onHorizontalDragUpdate: many
                  ? (d) => setState(
                      () =>
                          _shift = (_shift - d.delta.dx / width).clamp(lo, hi),
                    )
                  : null,
              onHorizontalDragEnd: many
                  ? (d) {
                      final v = d.primaryVelocity ?? 0;
                      final go = _shift.abs() > .25 || v.abs() > 700;
                      final dir = _shift != 0
                          ? (_shift > 0 ? 1 : -1)
                          : (v < 0 ? 1 : -1);
                      final ok = dir > 0 ? index < last : index > 0;
                      _settle(modes, go && ok ? dir : 0);
                    }
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slid(c, lang, modes, mode, width, top: true),
                  if (many) ...[const SizedBox(height: 4), dots],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('sw-month-toggle'),
                      onPressed: () => setState(() {
                        _month = !_month;
                        _viewing = null;
                      }),
                      child: Text(
                        _month ? 'back to the week' : 'show the month',
                      ),
                    ),
                  ),
                  _slid(c, lang, modes, mode, width, top: false),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// One part of the card, moved sideways with the finger: the page
  /// of [mode] and, while the ratchet is between two modes, its neighbour.
  Widget _slid(
    ColorScheme c,
    String lang,
    List<GameMode> modes,
    GameMode mode,
    double width, {
    required bool top,
  }) {
    Widget part(GameMode m) {
      final (t, b) = _page(c, lang, m);
      return top ? t : b;
    }

    final index = modes.indexOf(mode);
    final shift = index < 0 ? 0.0 : _shift.clamp(-1.0, 1.0);
    final other = index + (shift > 0 ? 1 : -1);
    if (shift == 0 || other < 0 || other >= modes.length) return part(mode);
    return ClipRect(
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(-shift * width, 0),
            child: part(mode),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: width,
            child: Transform.translate(
              offset: Offset((shift > 0 ? 1 - shift : -1 - shift) * width, 0),
              child: part(modes[other]),
            ),
          ),
        ],
      ),
    );
  }

  /// One of the two arrows beside the month name: a tonal square, dim when
  /// there is no month that way.
  Widget _monthArrow(
    ColorScheme c,
    Key key,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusElement),
        child: Container(
          width: 36,
          height: 40,
          decoration: BoxDecoration(
            color: tonesOf(context).s2,
            borderRadius: BorderRadius.circular(radiusElement),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? c.onSurface.withValues(alpha: .3)
                : c.onSurface,
          ),
        ),
      ),
    );
  }

  /// The content of the card for one mode, in the two parts that move with the
  /// finger: the mode's name, the streak line and the week (top), and the month with its legend
  /// (bottom). The month button between them stays where it is.
  (Widget, Widget) _page(ColorScheme c, String lang, GameMode mode) {
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
      VoidCallback? onTap,
    }) {
      final m = markOf(date);
      final isToday = date == today;
      final box = Container(
        key: ValueKey('sw-$prefix-$date'),
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isToday ? c.secondaryContainer : null,
          borderRadius: BorderRadius.circular(radiusInner),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [top, const SizedBox(height: 4), bottom],
        ),
      );
      return Semantics(
        container: true,
        excludeSemantics: true,
        button: onTap != null,
        onTap: onTap,
        label: mark ? '$date: ${describe(m)}' : date,
        child: onTap == null
            ? box
            : InkWell(
                key: ValueKey('sw-open-$date'),
                borderRadius: BorderRadius.circular(radiusInner),
                onTap: onTap,
                child: box,
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

    // the month on show: the current one to begin with, never a future one,
    // never before the first month the log has a day in
    final nowDate = DateTime.tryParse(today);
    final curFirst = nowDate == null
        ? null
        : DateTime.utc(nowDate.year, nowDate.month, 1);
    DateTime? firstLogged;
    for (final k in log.keys) {
      final t = DateTime.tryParse(k);
      if (t == null) continue;
      final f = DateTime.utc(t.year, t.month, 1);
      if (firstLogged == null || f.isBefore(firstLogged)) firstLogged = f;
    }
    var view = _viewing ?? curFirst;
    if (view != null && curFirst != null) {
      if (view.isAfter(curFirst)) view = curFirst;
      final lo = firstLogged ?? curFirst;
      if (view.isBefore(lo.isAfter(curFirst) ? curFirst : lo)) {
        view = lo.isAfter(curFirst) ? curFirst : lo;
      }
    }
    final canBack =
        view != null && firstLogged != null && view.isAfter(firstLogged);
    final canForward =
        view != null && curFirst != null && view.isBefore(curFirst);
    void goMonth(int by) {
      if (view == null) return;
      setState(() => _viewing = DateTime.utc(view!.year, view.month + by, 1));
    }

    // the days that have a game to open
    final kept = _month ? dailyGamesOf(appState.history, lang, mode) : const {};

    Widget monthGrid() {
      final d = view;
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
                      final m = markOf(date);
                      final game = kept[date];
                      final canOpen =
                          past &&
                          game != null &&
                          (m == _Mark.solved ||
                              m == _Mark.double ||
                              m == _Mark.lost) &&
                          appState.history.guessesOf(game.id).isNotEmpty;
                      return cell(
                        'month',
                        date,
                        mark: past,
                        onTap: canOpen
                            ? () => _openDay(lang, mode, date)
                            : null,
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

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TablerIcon(modeIconName(mode), size: 22, color: c.primary),
            const SizedBox(width: 8),
            Text(
              mode.label,
              key: const ValueKey('sw-header-mode'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
      ],
    );
    final bottom = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_month) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  view == null
                      ? ''
                      : '${_months[view.month - 1]}'
                            '${curFirst != null && view.year != curFirst.year ? ' ${view.year}' : ''}',
                  key: const ValueKey('sw-month-title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _monthArrow(
                c,
                const ValueKey('sw-month-prev'),
                Icons.chevron_left,
                'earlier month',
                canBack ? () => goMonth(-1) : null,
              ),
              const SizedBox(width: 4),
              _monthArrow(
                c,
                const ValueKey('sw-month-next'),
                Icons.chevron_right,
                'later month',
                canForward ? () => goMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          monthGrid(),
          const SizedBox(height: 12),
          legend,
        ],
      ],
    );
    return (top, bottom);
  }
}
