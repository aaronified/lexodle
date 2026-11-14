import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'language_sheet.dart';
import 'lex_widgets.dart' show LexChip;
import 'main.dart';
import 'mode_settings_page.dart' show knownModes;
import 'profile_sheet.dart';
import 'routes.dart';
import 'settings_button.dart';
import 'streak_week.dart';
import 'ui.dart';
import 'words.dart';

/// The fourth tab: the week's streak, the settings button, and the doors to the
/// achievements, lex, playstyle, history and friends. A new player
/// sees a door once enough games are played.
class YouPage extends StatefulWidget {
  const YouPage({super.key});

  @override
  State<YouPage> createState() => _YouPageState();
}

class _YouPageState extends State<YouPage> {
  List<Language>? _langs;

  @override
  void initState() {
    super.initState();
    _loadLangs();
  }

  Future<void> _loadLangs() async {
    try {
      final l = await WordBank.languages();
      if (mounted) setState(() => _langs = l);
    } catch (e) {
      appLog.w('you', 'languages failed ${e.runtimeType}');
    }
  }

  Future<void> _pickLanguage() async {
    try {
      final langs = _langs ?? await WordBank.languages();
      if (!mounted || langs.isEmpty) return;
      final lang = langs.firstWhere(
        (l) => l.code == appState.lang,
        orElse: () => langs.first,
      );
      final code = await showLanguageSheet(
        context,
        langs: langs,
        current: lang.code,
      );
      if (code == null || code == lang.code) return;
      final next = langs.firstWhere((l) => l.code == code);
      final length = appState.length;
      appState.setup(
        lang: code,
        length: next.lengths.contains(length) ? length : next.lengths.first,
      );
    } catch (e) {
      appLog.w('you', 'language failed ${e.runtimeType}');
    }
  }

  String? get _langName {
    final langs = _langs;
    if (langs == null || langs.isEmpty) return null;
    return langs
        .firstWhere((l) => l.code == appState.lang, orElse: () => langs.first)
        .name;
  }

  void _push(BuildContext context, String route, {Object? arguments}) {
    try {
      Navigator.pushNamed(context, route, arguments: arguments);
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
                      const SettingsButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const StreakWeek(),
                  const SizedBox(height: 20),
                  if (appState.stepOpen('achievements'))
                    _row(
                      context,
                      'achievements',
                      'achievements',
                      '${appState.unlockedCount} of ${achievementCount()} earned'
                          '${appState.lexUnlocked ? ' · lex and hints' : ''}',
                      icon: 'trophy',
                      trailingWidget: appState.lexUnlocked
                          ? LexChip(appState.lexBalance)
                          : null,
                      onTap: () => _push(context, Routes.achievements),
                    ),
                  if (appState.stepOpen('friends'))
                    _row(
                      context,
                      'friends',
                      'friends and social',
                      'coming in an upcoming release',
                      icon: 'bubble-text',
                      onTap: () =>
                          showToast(context, 'coming in an upcoming release'),
                    ),
                  if (appState.stepOpen('mode settings') &&
                      knownModes().isNotEmpty)
                    _row(
                      context,
                      'modeset',
                      'mode settings',
                      'free play settings · '
                          '${[for (final m in knownModes()) m.label].join(', ')}',
                      icon: 'settings',
                      onTap: () => _push(context, Routes.modeSettings),
                    ),
                  if (appState.stepOpen('your numbers'))
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
                  if (appState.stepOpen('language'))
                    _row(
                      context,
                      'language',
                      'language',
                      _langName,
                      icon: 'world',
                      onTap: _pickLanguage,
                    ),
                  if (appState.stepOpen('solver'))
                    _row(
                      context,
                      'solver',
                      'solver',
                      'for ${solverModeOf(appState.mode).label}',
                      icon: 'calculator',
                      onTap: () => _push(context, Routes.solver),
                    ),
                  if (appState.stepOpen('diy'))
                    _row(
                      context,
                      'diy',
                      'diy',
                      null,
                      icon: 'puzzle',
                      onTap: () => _push(context, Routes.diy),
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
    Widget? trailingWidget,
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
            if (trailingWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: trailingWidget,
              )
            else if (trailing != null)
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
