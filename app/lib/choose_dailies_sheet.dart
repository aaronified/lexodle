import 'package:flutter/material.dart';

import 'app_log.dart';
import 'edge_fade.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_wheel.dart' show modeIconName;
import 'modes.dart';
import 'today_prefs.dart';
import 'ui.dart';

/// Opens the sheet where the player chooses their dailies: one row per game
/// mode with a daily, a switch that shows or hides it on Today, a handle to put
/// the rows in their own order, and the pills that say how Today is sorted. The
/// switches apply at once; there is no "done" button. [play] starts a daily the
/// player has hidden (the sheet closes first); without it no "play" is offered.
Future<void> showChooseDailies(
  BuildContext context, {
  Future<void> Function(GameMode)? play,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ChooseDailiesSheet(play: play),
);

class _ChooseDailiesSheet extends StatelessWidget {
  const _ChooseDailiesSheet({this.play});

  final Future<void> Function(GameMode)? play;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: appState, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = appState.lang;
    final chosen = appState.dailiesOf(lang);
    final level = appState.level;
    // until the step opens, no locked mode is named
    final everyMode = appState.stepOpen('every mode');
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final shown = orderModes([
      for (final m in GameMode.loopFor(lang))
        if (m.hasDaily && (everyMode || isOpen(m, level))) m,
    ], appState.dailyOrder);
    Widget caption(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 4),
      child: Text(
        t,
        style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: dim),
      ),
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'choose your dailies',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 0, 19, 12),
                    child: Text(
                      'the ones you add are on today and in your reminders. a '
                      'daily you hide keeps its streak: it is only off today. '
                      'you can still play it from here.',
                      style: text.bodySmall?.copyWith(height: 1.6, color: dim),
                    ),
                  ),
                  caption('sort today by'),
                  _pills(c),
                  caption('dailies'),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: shown.length,
                    onReorderItem: (from, to) => _reorder(shown, from, to),
                    itemBuilder: (context, i) => _row(
                      context,
                      shown[i],
                      index: i,
                      chosen: chosen,
                      level: level,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The sort pills: the look of the mode filter, one row that scrolls sideways.
  Widget _pills(ColorScheme c) {
    return EdgeFade(
      key: const ValueKey('sort-pills'),
      padding: const EdgeInsets.fromLTRB(19, 4, 19, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in TodaySort.values) ...[
            if (s != TodaySort.values.first) const SizedBox(width: 6),
            _pill(c, s),
          ],
        ],
      ),
    );
  }

  Widget _pill(ColorScheme c, TodaySort s) {
    final on = appState.todaySort == s;
    return Semantics(
      button: true,
      selected: on,
      label: 'sort by ${s.label}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('sort-${s.name}'),
        onTap: () {
          try {
            appState.setTodaySort(s);
          } catch (e) {
            appLog.w(
              'choose-dailies',
              'could not set the sort: ${e.runtimeType}',
            );
          }
        },
        borderRadius: BorderRadius.circular(3),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? c.secondaryContainer : c.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              s.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.bold : null,
                color: on ? c.onSecondaryContainer : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _reorder(List<GameMode> shown, int from, int to) {
    try {
      final list = [...shown];
      list.insert(to, list.removeAt(from));
      appState.setDailyOrder([
        ...list,
        for (final m in appState.dailyOrder)
          if (!list.contains(m)) m,
      ]);
    } catch (e) {
      appLog.w('choose-dailies', 'could not reorder: ${e.runtimeType}');
    }
  }

  Widget _row(
    BuildContext context,
    GameMode m, {
    required int index,
    required List<GameMode> chosen,
    required int level,
  }) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = appState.lang;
    final streak = appState.dailyStreakFor(lang, m);
    final open = isOpen(m, level);
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final on = chosen.contains(m);
    final tail = streak > 0 ? ' · streak $streak' : '';
    final sub = !open
        ? '${m.sub} · not open yet'
        : on
        ? '${m.sub}$tail'
        : 'hidden$tail';
    final play = this.play;

    return Container(
      key: ValueKey('daily-row-${m.name}'),
      padding: const EdgeInsets.fromLTRB(11, 10, 19, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'move ${m.label}',
              child: SizedBox(
                width: 32,
                height: 40,
                child: Icon(Icons.drag_indicator, size: 22, color: dim),
              ),
            ),
          ),
          const SizedBox(width: 5),
          TablerIcon(
            modeIconName(m),
            size: chooserIconSize,
            color: open ? c.primary : dim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: open ? c.onSurface : dim,
                  ),
                ),
                Text(sub, style: text.bodySmall?.copyWith(color: dim)),
              ],
            ),
          ),
          if (open && !on && play != null)
            TextButton(
              key: ValueKey('daily-play-${m.name}'),
              onPressed: () => _play(context, play, m),
              child: const Text(
                'play ›',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (open)
            Semantics(
              label: m.label,
              child: Switch(
                key: ValueKey('daily-switch-${m.name}'),
                value: on,
                onChanged: (v) => _toggle(context, m, v, chosen: chosen),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _play(
    BuildContext context,
    Future<void> Function(GameMode) play,
    GameMode m,
  ) async {
    try {
      Navigator.pop(context);
      await play(m);
    } catch (e) {
      appLog.w('choose-dailies', 'could not play the daily: ${e.runtimeType}');
    }
  }

  void _toggle(
    BuildContext context,
    GameMode m,
    bool on, {
    required List<GameMode> chosen,
  }) {
    try {
      if (!on && chosen.length <= 1) {
        showToast(context, 'keep at least one daily');
        return;
      }
      appState.chooseDaily(appState.lang, m, on: on);
    } catch (e) {
      appLog.w(
        'choose-dailies',
        'could not switch the daily: ${e.runtimeType}',
      );
    }
  }
}
