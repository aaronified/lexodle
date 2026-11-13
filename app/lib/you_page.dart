import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'main.dart';
import 'mode_settings_page.dart' show knownModes;
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
                      InkWell(
                        key: const ValueKey('you-chip'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => showProfileSheet(context),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
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
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('you-help'),
                        tooltip: 'help: play your first game again',
                        onPressed: onReplayFirstGame,
                        icon: TablerIcon(
                          'info-circle',
                          size: 26,
                          color: c.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const StreakWeek(),
                  const SizedBox(height: 20),
                  Material(
                    color: c.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                      side: hairline(c),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
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
                  ),
                  const SizedBox(height: 12),
                  if (appState.lexUnlocked || _from(3))
                    _row(
                      context,
                      'achievements',
                      'achievements',
                      '${appState.unlockedCount} of ${achievementCount()} earned'
                          '${appState.lexUnlocked ? ' · lex and hints' : ''}',
                      icon: 'trophy',
                      trailing: appState.lexUnlocked
                          ? '${appState.lexBalance}'
                          : null,
                      onTap: () => _push(context, Routes.achievements),
                    ),
                  if (_from(5))
                    _row(
                      context,
                      'friends',
                      'friends and social',
                      'coming in an upcoming release',
                      icon: 'bubble-text',
                      onTap: () =>
                          showToast(context, 'coming in an upcoming release'),
                    ),
                  if (_from(2))
                    _row(
                      context,
                      'reminders',
                      'reminders',
                      'a ping when your dailies open',
                      icon: 'clock',
                      onTap: () => _push(context, Routes.reminders),
                    ),
                  if (knownModes().isNotEmpty)
                    _row(
                      context,
                      'modeset',
                      'mode settings',
                      'free play settings · '
                          '${[for (final m in knownModes()) m.label].join(', ')}',
                      icon: 'settings',
                      onTap: () => _push(context, Routes.modeSettings),
                    ),
                  if (_from(5))
                    _row(
                      context,
                      'history',
                      'history',
                      style == null
                          ? 'and your playstyle'
                          : 'your playstyle: ${style.name}',
                      icon: 'hourglass',
                      onTap: () => _push(context, Routes.history),
                    ),
                  if (_from(3))
                    _row(
                      context,
                      'backup',
                      'backup',
                      'save your data, or restore it',
                      icon: 'shield-check',
                      onTap: () => _push(context, Routes.settings),
                    ),
                  if (_from(7))
                    _row(
                      context,
                      'support',
                      'support lexodle',
                      'keep it going',
                      icon: 'gift',
                      onTap: () => _push(context, Routes.settings),
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
