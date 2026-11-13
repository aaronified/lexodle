import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'ladder.dart';
import 'main.dart';
import 'routes.dart';
import 'streak_week.dart';
import 'ui.dart';

/// The fourth tab: the week's streak, the theme, and the doors to the
/// achievements, lex, reminders, playstyle, history and friends. A new player
/// sees a door once the ladder has opened it (see [ladder]).
class YouPage extends StatelessWidget {
  const YouPage({super.key, required this.onReplayFirstGame});

  /// The help button: play the first game again.
  final VoidCallback onReplayFirstGame;

  /// Whether the ladder step called [name] is open to this player.
  static bool _open(String name) {
    if (appState.lex.veteran) return true;
    final played = appState.stats.played;
    for (final s in ladder) {
      if (s.name == name) return played >= s.games;
    }
    return true;
  }

  void _push(BuildContext context, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (e) {
      appLog.w('you', 'open failed ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final dark = appState.themeMode == ThemeMode.dark;
        final style = appState.style;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'you',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('you-help'),
                        tooltip: 'help: play your first game again',
                        onPressed: onReplayFirstGame,
                        icon: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.onSurface),
                          ),
                          child: Text(
                            '?',
                            style: TextStyle(fontSize: 13, color: c.onSurface),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('you-settings'),
                        tooltip: 'settings',
                        icon: TablerIcon(
                          'settings',
                          size: 24,
                          color: c.onSurface,
                        ),
                        onPressed: () => _push(context, Routes.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const StreakWeek(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Caption('theme'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final (m, label) in const [
                              (ThemeMode.light, 'light'),
                              (ThemeMode.dark, 'dark'),
                              (ThemeMode.system, 'system'),
                            ])
                              Expanded(
                                child: InkWell(
                                  key: ValueKey('theme-$label'),
                                  onTap: () => appState.setup(
                                    themeMode: m,
                                    black:
                                        m == ThemeMode.dark &&
                                        appState.blackTheme,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: appState.themeMode == m
                                            ? c.primary
                                            : c.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: appState.themeMode == m
                                            ? c.primary
                                            : c.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SwitchListTile(
                          key: const ValueKey('black-switch'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('true black'),
                          subtitle: Text(
                            'for OLED screens: pure #000000 when dark',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurface.withValues(alpha: dimAlpha),
                            ),
                          ),
                          value: appState.blackTheme,
                          onChanged: dark
                              ? (on) => appState.setup(
                                  themeMode: ThemeMode.dark,
                                  black: on,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_open('achievements'))
                    _row(
                      context,
                      'achievements',
                      'achievements',
                      '${appState.unlockedCount} of ${achievementCount()} earned',
                      icon: 'trophy',
                      onTap: () => _push(context, Routes.achievements),
                    ),
                  if (appState.lexUnlocked)
                    _row(
                      context,
                      'lex',
                      'lex',
                      'hint currency · how it works',
                      icon: 'bulb',
                      trailing: '${appState.lexBalance}',
                      onTap: () => showToast(context, 'the lex page is next'),
                    ),
                  _row(
                    context,
                    'reminders',
                    'reminders',
                    'a ping when your dailies open',
                    onTap: () => showToast(context, 'reminders are next'),
                  ),
                  if (_open('your numbers'))
                    _row(
                      context,
                      'playstyle',
                      'playstyle',
                      style == null
                          ? 'from your last 100 games'
                          : '${style.name} · from your last 100 games',
                      onTap: () => _push(context, Routes.playstyle),
                    ),
                  if (_open('your numbers'))
                    _row(
                      context,
                      'history',
                      'history',
                      null,
                      onTap: () => _push(context, Routes.history),
                    ),
                  _row(
                    context,
                    'friends',
                    'friends and social',
                    'coming in an upcoming release',
                    onTap: () =>
                        showToast(context, 'coming in an upcoming release'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    String id,
    String title,
    String? sub, {
    required VoidCallback onTap,
    String? icon,
    String? trailing,
  }) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('you-row-$id'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.outlineVariant)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: icon == null
                  ? null
                  : TablerIcon(icon, size: 20, color: c.onSurface),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.onSurface.withValues(alpha: dimAlpha),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(trailing, style: TextStyle(color: c.primary)),
              ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ],
        ),
      ),
    );
  }
}
