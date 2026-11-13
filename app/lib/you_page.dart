import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'main.dart';
import 'profile_sheet.dart';
import 'routes.dart';
import 'streak_week.dart';
import 'ui.dart';

/// The fourth tab: the week's streak, the theme, and the doors to the
/// achievements, lex, reminders, playstyle, history and friends. A new player
/// sees a door once enough games are played.
class YouPage extends StatelessWidget {
  const YouPage({super.key, required this.onReplayFirstGame});

  /// The help button: play the first game again.
  final VoidCallback onReplayFirstGame;

  /// Whether the player has played [games] games (a veteran sees all).
  static bool _from(int games) =>
      appState.lex.veteran || appState.stats.played >= games;

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
                            color: c.surfaceContainerHighest,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      key: const ValueKey('you-chip'),
                      onTap: () => showProfileSheet(context),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(appState.profile, size: 28),
                            const SizedBox(width: 8),
                            Text(appState.profile.name),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: c.onSurface.withValues(alpha: dimAlpha),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const StreakWeek(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
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
                                      color: appState.themeMode == m
                                          ? c.secondaryContainer
                                          : c.surfaceContainerHighest,
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: appState.themeMode == m
                                            ? FontWeight.bold
                                            : null,
                                        color: appState.themeMode == m
                                            ? c.onSecondaryContainer
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
                  if (_from(3))
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
                      onTap: () => _push(context, Routes.lex),
                    ),
                  if (_from(2))
                    _row(
                      context,
                      'reminders',
                      'reminders',
                      'a ping when your dailies open',
                      onTap: () => showToast(context, 'reminders are next'),
                    ),
                  if (_from(5))
                    _row(
                      context,
                      'playstyle',
                      'playstyle',
                      style == null
                          ? 'from your last 100 games'
                          : '${style.name} · from your last 100 games',
                      onTap: () => _push(context, Routes.playstyle),
                    ),
                  if (_from(5))
                    _row(
                      context,
                      'history',
                      'history',
                      null,
                      onTap: () => _push(context, Routes.history),
                    ),
                  if (_from(5))
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
