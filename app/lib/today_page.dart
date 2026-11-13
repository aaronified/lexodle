import 'package:flutter/material.dart';

import 'app_log.dart';
import 'choose_dailies_sheet.dart';
import 'clock.dart';
import 'daily.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_wheel.dart';
import 'modes.dart';
import 'routes.dart';
import 'ui.dart';

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
    final rows = [
      for (final m in appState.dailiesOf(lang)) _rowOf(lang, today, m),
    ];
    // in progress first, then not started, then done or lost (stable inside)
    int rank(_Row r) => switch (r.state) {
      _State.progress => 0,
      _State.fresh => 1,
      _ => 2,
    };
    final order = [...rows]..sort((a, b) => rank(a).compareTo(rank(b)));
    return order;
  }

  /// Starts [m]'s daily the way the home page does: the mode in view decides
  /// which daily the route opens, and the clock is asked again if it is stale.
  static Future<void> _play(BuildContext context, GameMode m) async {
    try {
      appState.setup(mode: m);
      if (!TrustedClock.isFresh()) {
        await TrustedClock.sync(timeout: const Duration(milliseconds: 1500));
      }
      if (!context.mounted) return;
      await Navigator.pushNamed(context, Routes.daily);
    } catch (e) {
      appLog.w('today', 'could not start a daily: ${e.runtimeType}');
    }
  }

  static void _freePlay(BuildContext context) {
    try {
      Navigator.pushNamed(context, Routes.gameModes);
    } catch (e) {
      appLog.w('today', 'could not open the game modes: ${e.runtimeType}');
    }
  }

  static void _choose(BuildContext context) {
    try {
      showChooseDailies(context);
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
    final games = appState.stats.played;
    final veteran = appState.lex.veteran;
    final chosen = appState.dailiesOf(lang);
    final more = [
      for (final m in openModes(games, veteran: veteran))
        if (m.hasDaily &&
            GameMode.loopFor(lang).contains(m) &&
            !chosen.contains(m))
          m,
    ];
    final canChoose = isOpen(GameMode.quartet, games, veteran: veteran);
    final newPlayer = !veteran && nextStep(games) != null;
    final dim = c.onSurface.withValues(alpha: dimAlpha);

    final pending = rows.where(
      (r) => r.state != _State.solved && r.state != _State.lost,
    );
    final next = pending.isEmpty ? null : pending.first;

    final date = _date(today);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('today-list'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'today',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    date,
                    key: const ValueKey('today-date'),
                    style: TextStyle(fontSize: 12, color: dim),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$done of ${rows.length}',
                key: const ValueKey('today-count'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rows.length == 1 ? 'daily done today' : 'dailies done today',
                style: TextStyle(fontSize: 12, color: dim),
              ),
              const SizedBox(height: 12),
              for (final r in rows) _rowTile(context, r),
              if (canChoose)
                _linkRow(
                  context,
                  key: const ValueKey('today-choose'),
                  title: 'choose dailies',
                  sub:
                      '${chosen.length} shown · ${more.length} more you can add',
                  onTap: () => _choose(context),
                ),
              if (more.isNotEmpty)
                _More(
                  modes: more,
                  tileOf: (m) => _rowTile(
                    context,
                    _rowOf(lang, today, m),
                    key: ValueKey('today-more-${m.name}'),
                  ),
                ),
              if (newPlayer) ..._cards(context, games),
            ],
          ),
        ),
        _bottomBar(context, c, next),
      ],
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

  Widget _rowTile(BuildContext context, _Row r, {Key? key}) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final m = r.mode;
    final yellow = yellowOf(c);
    final lost = r.state == _State.lost;

    final (Color fill, Color? edge, Widget mark) = switch (r.state) {
      _State.solved => (
        c.secondary,
        null,
        Text('✓', style: TextStyle(fontSize: 18, color: c.onSecondary)),
      ),
      _State.progress => (
        yellow,
        null,
        Text('…', style: TextStyle(fontSize: 18, color: onColor(c, yellow))),
      ),
      _State.lost => (
        Colors.transparent,
        heartColor(c),
        TablerIcon('skull', size: 22, color: heartColor(c)),
      ),
      _State.fresh => (Colors.transparent, c.outlineVariant, const SizedBox()),
    };

    final String stateText = switch (r.state) {
      _State.fresh => 'not started',
      _State.progress =>
        m.endless
            ? '${r.tries ?? 0} guesses'
            : '${r.tries ?? 0} of ${dailyTriesOf(m)} tries used',
      _State.solved =>
        r.tries == null || r.tries == 0 ? 'solved' : 'solved in ${r.tries}',
      _State.lost => 'missed',
    };

    final flame = switch (r.state) {
      _State.solved => c.secondary,
      _State.progress => yellow,
      _ => dim,
    };
    final verb = switch (r.state) {
      _State.fresh => 'play',
      _State.progress => 'continue',
      _ => 'view',
    };

    return InkWell(
      key: key ?? ValueKey('today-row-${m.name}'),
      onTap: () {
        if (r.state == _State.solved || lost) {
          showToast(
            context,
            'the game over and review screens remain as they are',
          );
        } else {
          _play(context, m);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.outlineVariant)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                border: edge == null ? null : Border.all(color: edge),
                borderRadius: BorderRadius.circular(3),
              ),
              child: mark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TablerIcon(modeIconName(m), size: 18, color: c.onSurface),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          m.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        stateText,
                        style: TextStyle(
                          fontSize: 12,
                          color: lost ? heartColor(c) : dim,
                          fontWeight: lost ? FontWeight.w700 : null,
                        ),
                      ),
                      if (lost)
                        Text(
                          ' · streak ended',
                          style: TextStyle(fontSize: 12, color: dim),
                        )
                      else ...[
                        Text(' · ', style: TextStyle(fontSize: 12, color: dim)),
                        TablerIcon('flame', size: 14, color: flame),
                        Text(
                          ' ${r.streak}',
                          style: TextStyle(fontSize: 12, color: flame),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$verb ›',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(
    BuildContext context, {
    required Key key,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                ],
              ),
            ),
            const Text('›', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  /// The slow-introduction cards: what just opened, and what comes next.
  List<Widget> _cards(BuildContext context, int games) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final next = nextStep(games);
    return [
      const SizedBox(height: 16),
      for (final s in justOpened(games))
        Container(
          key: ValueKey('today-new-${s.name}'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: c.onSurface, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: c.onSurface),
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
            ],
          ),
        ),
      if (next != null)
        Container(
          key: const ValueKey('today-next-up'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Caption('next up')),
                  Text(
                    'in ${next.games - games} '
                    '${next.games - games == 1 ? 'game' : 'games'}',
                    style: TextStyle(fontSize: 12, color: dim),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                next.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(next.note, style: TextStyle(fontSize: 12, color: dim)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  key: const ValueKey('today-next-bar'),
                  value: progressToNext(games),
                  minHeight: 3,
                  color: c.primary,
                  backgroundColor: c.outlineVariant,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _bottomBar(BuildContext context, ColorScheme c, _Row? next) {
    final allDone = next == null;
    return Container(
      key: const ValueKey('today-bar'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allDone) ...[
            Text(
              'all done · the next dailies open in ${_untilNext()}',
              key: const ValueKey('today-all-done'),
              style: TextStyle(
                fontSize: 12,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (!allDone) ...[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('today-free-play'),
                    onPressed: () => _freePlay(context),
                    child: const Text('free play'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: allDone ? 1 : 2,
                child: FilledButton(
                  key: const ValueKey('today-primary'),
                  onPressed: () =>
                      allDone ? _freePlay(context) : _play(context, next.mode),
                  child: Text(
                    allDone
                        ? 'free play'
                        : '${next.state == _State.progress ? 'continue' : 'play'}'
                              ' ${next.mode.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "more dailies (n)": the open modes that are not chosen, folded away.
class _More extends StatefulWidget {
  const _More({required this.modes, required this.tileOf});
  final List<GameMode> modes;
  final Widget Function(GameMode) tileOf;

  @override
  State<_More> createState() => _MoreState();
}

class _MoreState extends State<_More> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('today-more'),
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'more dailies (${widget.modes.length})',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'not on your list · play any',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                    ],
                  ),
                ),
                TablerIcon(
                  _open ? 'chevron-up' : 'chevron-down',
                  size: 18,
                  color: c.onSurface,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          for (final m in widget.modes) widget.tileOf(m),
      ],
    );
  }
}
