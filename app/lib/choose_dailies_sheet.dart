import 'package:flutter/material.dart';

import 'ladder.dart';
import 'main.dart';
import 'mode_wheel.dart' show modeIconName;
import 'modes.dart';
import 'ui.dart';

/// Opens the sheet where the player chooses their dailies: one row per game
/// mode with a daily, and a switch that adds or drops it. The switches apply at
/// once; there is no "done" button.
Future<void> showChooseDailies(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChooseDailiesSheet(),
    );

class _ChooseDailiesSheet extends StatefulWidget {
  const _ChooseDailiesSheet();

  @override
  State<_ChooseDailiesSheet> createState() => _ChooseDailiesSheetState();
}

class _ChooseDailiesSheetState extends State<_ChooseDailiesSheet> {
  /// The mode whose streak is being confirmed before it is dropped.
  GameMode? _asking;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 0, 19, 12),
            child: Text(
              'the ones you add are on Today and in your reminders. a daily you '
              'drop keeps no streak. you can still play it from "more dailies".',
              style: text.bodySmall?.copyWith(
                height: 1.6,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final m in GameMode.loopFor(lang))
                    if (m.hasDaily && (everyMode || isOpen(m, level)))
                      _row(context, m, chosen: chosen, level: level),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    GameMode m, {
    required List<GameMode> chosen,
    required int level,
  }) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = appState.lang;
    final streak = appState.dailyStreakFor(lang, m);
    final open = isOpen(m, level);
    final dim = c.onSurface.withValues(alpha: dimAlpha);

    Widget body;
    if (_asking == m) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${m.label} has a $streak day streak. a daily you drop keeps no '
            'streak: it ends if you skip a day. remove it anyway?',
            style: text.bodySmall,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _asking = null),
                child: const Text('keep it'),
              ),
              TextButton(
                onPressed: () {
                  appState.chooseDaily(lang, m, on: false);
                  setState(() => _asking = null);
                },
                child: const Text('remove'),
              ),
            ],
          ),
        ],
      );
    } else {
      final on = chosen.contains(m);
      final sub = !open
          ? '${m.sub} · not open yet'
          : streak > 0
          ? '${m.sub} · streak $streak'
          : m.sub;
      body = Row(
        children: [
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
          if (open)
            Semantics(
              label: m.label,
              child: Switch(
                key: ValueKey('daily-switch-${m.name}'),
                value: on,
                onChanged: (v) =>
                    _toggle(context, m, v, chosen: chosen, streak: streak),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: body,
    );
  }

  void _toggle(
    BuildContext context,
    GameMode m,
    bool on, {
    required List<GameMode> chosen,
    required int streak,
  }) {
    if (on) {
      appState.chooseDaily(appState.lang, m, on: true);
      return;
    }
    if (chosen.length <= 1) {
      showToast(context, 'keep at least one daily');
      return;
    }
    if (streak > 0) {
      setState(() => _asking = m);
      return;
    }
    appState.chooseDaily(appState.lang, m, on: false);
  }
}
