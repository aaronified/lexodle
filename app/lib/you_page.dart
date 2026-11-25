import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'language_sheet.dart';
import 'lex_widgets.dart' show LexChip;
import 'main.dart';
import 'mode_settings_page.dart' show knownModes;
import 'profile_sheet.dart';
import 'routes.dart';
import 'streak_week.dart';
import 'tonal.dart';
import 'ui_kit.dart';
import 'ui.dart';
import 'words.dart';

/// The fourth tab: the player chip and the settings cog, the week's streak, and
/// the doors to the achievements, history, the modes, the solver, diy, the
/// language and friends, in three groups. A new player sees a door once enough
/// games are played.
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

  /// The sheet where the languages of the switchers are ticked.
  void _pickLanguages() => showLanguagesChooser(context);

  /// The names of the ticked languages, in English, for the line under the row.
  String? get _langName {
    final langs = _langs;
    if (langs == null || langs.isEmpty) return null;
    return [
      for (final c in appState.playLangs)
        (langs.where((l) => l.code == c).firstOrNull?.wikt ?? c).toLowerCase(),
    ].join(', ');
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
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final style = appState.style;
        final progress = <GroupRow>[
          if (appState.stepOpen('achievements'))
            _row(
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
          if (appState.stepOpen('your numbers'))
            _row(
              'history',
              'history',
              style == null
                  ? 'and your playstyle'
                  : 'your playstyle: ${style.name}',
              icon: 'hourglass',
              onTap: () => _push(context, Routes.history),
            ),
        ];
        final play = <GroupRow>[
          if (appState.stepOpen('mode settings') && knownModes().isNotEmpty)
            _row(
              'modeset',
              'mode settings',
              'free play settings · '
                  '${[for (final m in knownModes()) m.label].join(', ')}',
              icon: 'settings',
              onTap: () => _push(context, Routes.modeSettings),
            ),
          if (appState.stepOpen('solver'))
            _row(
              'solver',
              'solver',
              'enter your colours, see the words left',
              icon: 'calculator',
              onTap: () => _push(context, Routes.solver),
            ),
          if (appState.stepOpen('diy'))
            _row(
              'diy',
              'diy',
              'make a puzzle and share a link',
              icon: 'puzzle',
              onTap: () => _push(context, Routes.diy),
            ),
        ];
        final you = <GroupRow>[
          if (appState.stepOpen('language'))
            _row(
              'language',
              'languages',
              _langName,
              icon: 'world',
              onTap: _pickLanguages,
            ),
          if (appState.stepOpen('friends'))
            _row(
              'friends',
              'friends and social',
              'coming in an upcoming release',
              icon: 'bubble-text',
              onTap: () => showToast(context, 'coming in an upcoming release'),
            ),
        ];
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: _playerChip(context),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        const StreakWeek(),
                        if (progress.isNotEmpty) ...[
                          const SectionLabel('progress'),
                          GroupedList(rows: progress),
                        ],
                        if (play.isNotEmpty) ...[
                          const SectionLabel('play'),
                          GroupedList(rows: play),
                        ],
                        if (you.isNotEmpty) ...[
                          const SectionLabel('you'),
                          GroupedList(rows: you),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The player: the avatar and the name on a tonal pill, a chevron after them.
  /// Tapping it opens the profile sheet.
  Widget _playerChip(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('you-chip'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => showProfileSheet(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 8, right: 16),
        decoration: BoxDecoration(
          color: tonesOf(context).s1,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(appState.profile, size: 30),
            const SizedBox(width: 10),
            Text(appState.profile.name),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 20, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  GroupRow _row(
    String id,
    String title,
    String? sub, {
    required VoidCallback onTap,
    required String icon,
    Widget? trailingWidget,
  }) {
    return GroupRow(
      key: ValueKey('you-row-$id'),
      leading: TonalTile(icon),
      title: Text(title),
      subtitle: sub == null ? null : Text(sub),
      trailing: trailingWidget,
      onTap: onTap,
    );
  }
}
