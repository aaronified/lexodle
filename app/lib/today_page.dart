import 'package:flutter/material.dart';

import 'app_log.dart';
import 'choose_dailies_sheet.dart';
import 'clock.dart';
import 'daily.dart';
import 'first_run/mode_lesson_page.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_wheel.dart';
import 'modes.dart';
import 'routes.dart';
import 'today_prefs.dart';
import 'tonal.dart';
import 'language_picker.dart';
import 'ui.dart';
import 'ui_kit.dart';

/// Where one chosen daily stands today.
enum _State { progress, fresh, solved, lost }

class _Row {
  const _Row(this.mode, this.state, this.tries, this.streak);
  final GameMode mode;
  final _State state;

  /// The guesses used so far (in progress) or taken (solved), when known.
  final int? tries;
  final int streak;
}

/// The look of one daily: colours and words, for a row or a tile.
class _Look {
  const _Look({
    required this.fill,
    required this.mark,
    required this.iconName,
    required this.dim,
    required this.lost,
    required this.stateText,
    required this.flame,
    required this.verb,
  });
  final Color fill, mark, dim, flame;
  final String iconName, stateText, verb;
  final bool lost;

  Widget icon(double size) => TablerIcon(iconName, size: size, color: mark);
}

/// The hours and minutes left until the dailies change (midnight in India).
String _untilNext() {
  final now = dailyClock().toUtc().add(const Duration(hours: 5, minutes: 30));
  final left =
      const Duration(days: 1) -
      Duration(hours: now.hour, minutes: now.minute, seconds: now.second);
  final m = left.inMinutes + (left.inSeconds % 60 == 0 ? 0 : 1);
  return '${m ~/ 60}h ${m % 60}m';
}

/// The Today tab: the dailies the player chose, each named with its state in
/// words, the way into choosing them, and one bar with the next thing to do.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: appState, builder: _build);

  static List<_Row> _rows(String lang, String today) {
    final modes = appState.dailiesOf(lang);
    final rows = [for (final m in modes) _rowOf(lang, today, m)];
    switch (appState.todaySort) {
      case TodaySort.status:
        // in progress first, then not started, then done or lost (stable)
        int rank(_Row r) => switch (r.state) {
          _State.progress => 0,
          _State.fresh => 1,
          _ => 2,
        };
        return _stable(rows, (a, b) => rank(a).compareTo(rank(b)));
      case TodaySort.mine:
        final order = orderModes(modes, appState.dailyOrder);
        return [for (final m in order) rows.firstWhere((r) => r.mode == m)];
      case TodaySort.name:
        return _stable(rows, (a, b) => a.mode.label.compareTo(b.mode.label));
      case TodaySort.streak:
        return _stable(rows, (a, b) => b.streak.compareTo(a.streak));
    }
  }

  /// [rows] sorted by [cmp], equal ones keeping their order.
  static List<_Row> _stable(List<_Row> rows, int Function(_Row, _Row) cmp) {
    final idx = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    return [...rows]..sort((a, b) {
      final d = cmp(a, b);
      return d != 0 ? d : idx[a]!.compareTo(idx[b]!);
    });
  }

  /// Starts [m]'s daily: the route is told the mode, so the free play mode is
  /// left as it is, and the clock is asked again if it is stale.
  static Future<void> _play(BuildContext context, GameMode m) async {
    try {
      if (!TrustedClock.isFresh()) {
        await TrustedClock.sync(timeout: const Duration(milliseconds: 1500));
      }
      if (!context.mounted) return;
      await Navigator.pushNamed(context, Routes.daily, arguments: m);
    } catch (e) {
      appLog.w('today', 'could not start a daily: ${e.runtimeType}');
    }
  }

  static void _freePlay(BuildContext context) {
    try {
      Navigator.pushNamed(context, Routes.play);
    } catch (e) {
      appLog.w('today', 'could not start a free game: ${e.runtimeType}');
    }
  }

  static void _choose(BuildContext context) {
    try {
      showChooseDailies(context, play: (m) => _play(context, m));
    } catch (e) {
      appLog.w('today', 'could not open the choice: ${e.runtimeType}');
    }
  }

  Widget _build(BuildContext context, Widget? _) {
    final c = Theme.of(context).colorScheme;
    final lang = appState.lang;
    final today = dailyDate();
    final rows = _rows(lang, today);
    final done = rows.where((r) => r.state == _State.solved).length;
    final veteran = appState.lex.veteran;
    final canChoose = isOpen(GameMode.quartet, appState.level);
    final newPlayer = !veteran;
    final dim = c.onSurface.withValues(alpha: dimAlpha);

    final pending = rows.where(
      (r) => r.state != _State.solved && r.state != _State.lost,
    );
    final next = pending.isEmpty ? null : pending.first;

    final date = _date(today);
    return LayoutBuilder(
      builder: (context, box) {
        // the tiles share the free height, but never less than they need to
        // read: with many dailies the list scrolls (128 holds the icon, the
        // name and the state line with room around them)
        final n = (rows.length + 1) ~/ 2;
        final free = box.maxHeight - 244 - 8 * (n - 1);
        final tileHeight = n == 0
            ? 128.0
            : (free / n).clamp(128.0, 148.0).toDouble();
        // the list scrolls under the top bar and under the free play
        // strip, which float over it
        final inset = MediaQuery.paddingOf(context).bottom;
        final list = ListView(
          key: const ValueKey('today-list'),
          padding: EdgeInsets.only(top: topBarInset, bottom: 104 + inset),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$done of ${rows.length}',
                              key: const ValueKey('today-count'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rows.length == 1
                                  ? 'daily done today'
                                  : 'dailies done today',
                              style: TextStyle(fontSize: 13, color: dim),
                            ),
                          ],
                        ),
                      ),
                      if (canChoose) ...[
                        _switch(context, [
                          _switchButton(
                            context,
                            key: const ValueKey('today-choose'),
                            icon: 'adjustments-horizontal',
                            label: 'choose, sort and more dailies',
                            selected: false,
                            onTap: () => _choose(context),
                          ),
                        ]),
                        const SizedBox(width: 8),
                      ],
                      _switch(context, [
                        _switchButton(
                          context,
                          key: const ValueKey('today-view-list'),
                          icon: 'list',
                          label: 'list',
                          selected: !appState.todayTiles,
                          onTap: () => appState.setTodayTiles(false),
                        ),
                        _switchButton(
                          context,
                          key: const ValueKey('today-view-tiles'),
                          icon: 'layout-grid',
                          label: 'tiles',
                          selected: appState.todayTiles,
                          onTap: () => appState.setTodayTiles(true),
                        ),
                      ]),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(child: SectionLabel('your dailies')),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 28, 2, 8),
                        child: Text(
                          date,
                          key: const ValueKey('today-date'),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (appState.todayTiles)
                    _tiles(context, rows, tileHeight)
                  else
                    GroupedList(
                      rows: [for (final r in rows) _groupRow(context, r)],
                    ),
                  if (newPlayer) ..._cards(context, lang),
                  // all done: the last row of the scrolled area
                  if (next == null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'all done · the next dailies open in ${_untilNext()}',
                        key: const ValueKey('today-all-done'),
                        style: TextStyle(fontSize: 12, color: dim),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        return Stack(
          children: [
            Positioned.fill(child: list),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: TopBar(slider: LanguageBar(pill: true)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: inset,
              child: _bottomBar(context, c),
            ),
          ],
        );
      },
    );
  }

  /// A group of flat icon buttons on one tonal fill, with no edge.
  Widget _switch(BuildContext context, List<Widget> buttons) {
    return Container(
      decoration: BoxDecoration(
        color: tonesOf(context).s1,
        borderRadius: BorderRadius.circular(radiusElement),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }

  Widget _switchButton(
    BuildContext context, {
    required Key key,
    required String icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: key,
          onTap: () {
            try {
              onTap();
            } catch (e) {
              appLog.w('today', 'could not use $icon: ${e.runtimeType}');
            }
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? tonesOf(context).s2 : null,
              borderRadius: BorderRadius.circular(radiusElement),
            ),
            child: TablerIcon(
              icon,
              size: 22,
              color: selected
                  ? c.onSurface
                  : c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ),
      ),
    );
  }

  /// The dailies as a two column grid of tiles, each [height] tall.
  Widget _tiles(BuildContext context, List<_Row> rows, double height) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(child: _tile(context, rows[i])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < rows.length
                        ? _tile(context, rows[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, _Row r) {
    final c = Theme.of(context).colorScheme;
    final look = _look(c, r);
    final m = r.mode;
    return InkWell(
      key: ValueKey('today-row-${m.name}'),
      onTap: () => _play(context, m),
      child: Container(
        padding: const EdgeInsets.all(12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: tonesOf(context).s1,
          borderRadius: BorderRadius.circular(radiusContainer),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: look.fill,
                    borderRadius: BorderRadius.circular(radiusElement),
                  ),
                  child: look.icon(22),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '${look.verb} ›',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: look.dim),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        look.lost
                            ? '${look.stateText} · streak ended'
                            : look.stateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: look.lost ? heartColor(c) : look.dim,
                          fontWeight: look.lost ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (!look.lost) ...[
                      Text(
                        ' · ',
                        style: TextStyle(fontSize: 11, color: look.dim),
                      ),
                      TablerIcon('flame', size: 12, color: look.flame),
                      Text(
                        ' ${r.streak}',
                        style: TextStyle(fontSize: 11, color: look.flame),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The colours and words of one daily's state, shared by row and tile.
  static _Look _look(ColorScheme c, _Row r) {
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final m = r.mode;
    final yellow = yellowOf(c);
    final (Color fill, Color mark) = switch (r.state) {
      _State.solved => (c.secondary, c.onSecondary),
      _State.progress => (yellow, onColor(c, yellow)),
      _State.lost => (c.surfaceContainerHighest, heartColor(c)),
      _State.fresh => (c.surfaceContainerHighest, c.onSurface),
    };
    return _Look(
      fill: fill,
      mark: mark,
      iconName: modeIconName(m),
      dim: dim,
      lost: r.state == _State.lost,
      stateText: switch (r.state) {
        _State.fresh => 'not started',
        _State.progress => '${r.tries ?? 0} of ${dailyTriesOf(m)} tries used',
        _State.solved =>
          r.tries == null || r.tries == 0 ? 'solved' : 'solved in ${r.tries}',
        _State.lost => 'missed',
      },
      flame: switch (r.state) {
        _State.solved => c.secondary,
        _State.progress => yellow,
        _ => dim,
      },
      verb: switch (r.state) {
        _State.fresh => 'play',
        _State.progress => 'continue',
        _ => 'view',
      },
    );
  }

  static _Row _rowOf(String lang, String today, GameMode m) {
    final tier = appState.dailyLogOf(lang, m)[today];
    final e = appState.dailyFor(lang, today, m);
    final state = tier == null
        ? (e != null && !e.over ? _State.progress : _State.fresh)
        : tier >= dailySolved
        ? _State.solved
        : _State.lost;
    return _Row(
      m,
      state,
      state == _State.progress || state == _State.solved
          ? e?.guesses.length
          : null,
      appState.dailyStreakFor(lang, m),
    );
  }

  /// `thu 13 nov`, from `2026-11-13`.
  static String _date(String ymd) {
    try {
      final p = ymd.split('-').map(int.parse).toList();
      final d = DateTime.utc(p[0], p[1], p[2]);
      const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      const months = [
        'jan', 'feb', 'mar', 'apr', 'may', 'jun',
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec', //
      ];
      return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    } catch (e) {
      appLog.w('today', 'the date could not be shown: ${e.runtimeType}');
      return ymd;
    }
  }

  /// One daily as a row of its [GroupedList]: the mode's icon on the fill of
  /// its state, the name, the state line with the streak, and the verb.
  GroupRow _groupRow(BuildContext context, _Row r) {
    final c = Theme.of(context).colorScheme;
    final look = _look(c, r);
    final m = r.mode;
    return GroupRow(
      key: ValueKey('today-row-${m.name}'),
      // a finished daily opens its game over screen, as it always did
      onTap: () => _play(context, m),
      leading: TonalTile(
        look.iconName,
        big: true,
        fill: look.fill,
        color: look.mark,
      ),
      title: Text(m.label, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            look.stateText,
            style: TextStyle(
              fontSize: 13,
              color: look.lost ? heartColor(c) : look.dim,
              fontWeight: look.lost ? FontWeight.w700 : null,
            ),
          ),
          if (look.lost)
            Text(
              ' · streak ended',
              style: TextStyle(fontSize: 13, color: look.dim),
            )
          else ...[
            Text(' · ', style: TextStyle(fontSize: 13, color: look.dim)),
            TablerIcon('flame', size: 14, color: look.flame),
            Text(
              ' ${r.streak}',
              style: TextStyle(fontSize: 13, color: look.flame),
            ),
          ],
        ],
      ),
      trailing: Text(
        look.verb,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: c.onSurface,
        ),
      ),
    );
  }

  /// Where a tap on the card of [s] goes, and the verb it carries.
  static String _verb(LadderStep s) => switch (s.name) {
    'skill, luck and risk' => 'got it ›',
    'achievements' => 'see them ›',
    'your numbers' => 'see it ›',
    'every mode' => 'got it ›',
    'my words' => 'open it ›',
    'learn' => 'try it ›',
    _ => s.mode != null ? 'how it works ›' : 'try it ›',
  };

  Future<void> _go(BuildContext context, LadderStep s) async {
    try {
      final mode = s.mode;
      if (mode != null) {
        // a mode card is handled only once its lesson finished taught
        await _openLesson(context, mode);
        if (appState.isTaught(mode)) appState.markIntroCardDone(s.name);
        return;
      }
      appState.markIntroCardDone(s.name);
      if (s.name == 'every mode') {
        await showChooseDailies(context, play: (m) => _play(context, m));
        return;
      }
      final route = switch (s.name) {
        'achievements' => Routes.achievements,
        'your numbers' => Routes.history,
        'my words' => Routes.words,
        'learn' => Routes.learn,
        _ => null,
      };
      if (route != null) await Navigator.pushNamed(context, route);
    } catch (e) {
      appLog.w('today', 'could not open the card: ${e.runtimeType}');
    }
  }

  /// The card of what just opened: a tap takes the player into it.
  Widget _newCard(
    BuildContext context,
    ColorScheme c,
    Color dim,
    LadderStep s,
  ) {
    return InkWell(
      key: ValueKey('today-new-${s.name}'),
      borderRadius: BorderRadius.circular(3),
      onTap: () => _go(context, s),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.secondaryContainer,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('new', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              Text(
                s.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(s.note, style: TextStyle(fontSize: 12, color: dim)),
              const SizedBox(height: 8),
              Text(_verb(s), style: TextStyle(fontSize: 12, color: c.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, GameMode mode) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => ModeLessonPage(
            mode: mode,
            onDone: () {
              try {
                Navigator.of(ctx).pop();
              } catch (e) {
                appLog.w(
                  'today',
                  'could not leave the lesson: ${e.runtimeType}',
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      appLog.w('today', 'could not open the lesson: ${e.runtimeType}');
    }
  }

  /// The slow-introduction card: the earliest reached step not yet handled, at
  /// most one, so that the page is never crowded. A mode that is taught, or not
  /// in the language's loop, is skipped. The card waits however many games pass.
  List<Widget> _cards(BuildContext context, String lang) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final loop = GameMode.loopFor(lang);
    for (final s in reached(appState.level)) {
      if (appState.introCardsDone.contains(s.name)) continue;
      final m = s.mode;
      if (m != null && (appState.isTaught(m) || !loop.contains(m))) continue;
      return [const SizedBox(height: 16), _newCard(context, c, dim, s)];
    }
    return const [];
  }

  /// The free play slider of the bar: the open modes side by side, the one
  /// under the rectangle is the free play mode.
  Widget _modeButton(BuildContext context) {
    final loop = GameMode.loopFor(appState.lang);
    var open = [
      for (final m in openModes(appState.level))
        if (loop.contains(m)) m,
    ];
    if (open.isEmpty) open = [GameMode.classic];
    final shown = open.contains(appState.mode) ? appState.mode : open.first;
    return KeyedSubtree(
      key: const ValueKey('today-free-play'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ChoiceSlider<GameMode>(
                  id: 'free-play',
                  title: 'free play',
                  caption: 'free play',
                  float: true,
                  compact: true,
                  items: [
                    for (final m in open)
                      ChoiceItem<GameMode>(
                        value: m,
                        label: m.label,
                        icon: modeIconName(m),
                      ),
                  ],
                  selected: shown,
                  onChanged: (m) {
                    try {
                      appState.setup(mode: m);
                    } catch (e) {
                      appLog.w(
                        'today',
                        'could not change the mode: ${e.runtimeType}',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // the name opens the list of modes, so the game starts from here
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radiusElement),
                  boxShadow: floatShadow(context),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('free-play-start'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () {
                      try {
                        if (shown != appState.mode) appState.setup(mode: shown);
                      } catch (e) {
                        appLog.w(
                          'today',
                          'could not set the mode: ${e.runtimeType}',
                        );
                      }
                      _freePlay(context);
                    },
                    child: const Icon(Icons.play_arrow),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, ColorScheme c) {
    return Container(
      key: const ValueKey('today-bar'),
      // no background: the strip floats on its shadows over the list
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_modeButton(context)],
      ),
    );
  }
}
