import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'app_log.dart';
import 'language_picker.dart' show LanguageBar;
import 'language_sheet.dart';
import 'lex_widgets.dart' show LexChip;
import 'main.dart';
import 'medal.dart';
import 'mode_settings_page.dart' show knownModes;
import 'profile_sheet.dart';
import 'routes.dart';
import 'store.dart' show achievements;
import 'streak_week.dart';
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
  @override
  void initState() {
    super.initState();
    _loadLangs();
  }

  Future<void> _loadLangs() async {
    try {
      // read once, so the flags of the languages are known: draw them again
      await WordBank.languages();
      if (mounted) setState(() {});
    } catch (e) {
      appLog.w('you', 'languages failed ${e.runtimeType}');
    }
  }

  /// The sheet where the languages of the switchers are ticked.
  void _pickLanguages() => showLanguagesChooser(context);

  /// The medals earned in this language: "7 bronze · 2 silver · 1 gold".
  String _medals() {
    final n = {for (final m in Medal.values) m: 0};
    for (final a in achievements) {
      final t = (appState.ach[a.id]?.times ?? 0).clamp(0, a.count);
      for (var i = 0; i < t; i++) {
        final m = a.levels[i].medal;
        n[m] = n[m]! + 1;
      }
    }
    return [
      for (final m in Medal.values)
        if (n[m]! > 0) '${n[m]} ${m.name}',
    ].join(' · ');
  }

  /// The last game, in a line: how it went and when.
  String? _lastGame() {
    try {
      final h = appState.history;
      if (h.games.isEmpty) return null;
      final g = h.games.last;
      final day = DateTime.fromMillisecondsSinceEpoch(g.at);
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final date = DateUtils.isSameDay(day, now)
          ? 'today'
          : DateUtils.isSameDay(day, now.subtract(const Duration(days: 1)))
          ? 'yesterday'
          : '${day.year}-${two(day.month)}-${two(day.day)}';
      final how = g.won
          ? 'solved in ${h.guessesOf(g.id).length}/${g.tries}'
          : 'missed';
      return 'last: $how · $date';
    } catch (e) {
      appLog.w('you', 'last game failed ${e.runtimeType}');
      return null;
    }
  }

  /// "113 games · since 2026-09-02", or nothing before the first game.
  String? _since() {
    try {
      final h = appState.history;
      if (h.games.isEmpty) return null;
      final d = DateTime.fromMillisecondsSinceEpoch(h.games.first.at);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${h.games.length} ${h.games.length == 1 ? 'game' : 'games'}'
          ' · since ${d.year}-${two(d.month)}-${two(d.day)}';
    } catch (e) {
      appLog.w('you', 'since failed ${e.runtimeType}');
      return null;
    }
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
                  '${_medals().isEmpty ? '' : ' · ${_medals()}'}',
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
              _lastGame() ?? 'every game you play',
              icon: 'hourglass',
              onTap: () => _push(context, Routes.history),
            ),
          if (appState.stepOpen('your numbers') && style != null)
            _row(
              'playstyle',
              'playstyle',
              style.name,
              icon: style.icon,
              onTap: () => _push(context, Routes.playstyle),
            ),
        ];
        final play = <GroupRow>[
          if (appState.stepOpen('mode settings') && knownModes().isNotEmpty)
            _row(
              'modeset',
              'mode settings',
              'for free play',
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
              null,
              subtitle: Row(
                children: [
                  for (final c in appState.playLangs) ...[
                    languageBadge(c, size: 14),
                    const SizedBox(width: 6),
                  ],
                  Text('${appState.playLangs.length} ticked'),
                ],
              ),
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
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // the language slider is the top bar; the player chip, which was
              // the header, is the first row of the page
              child: UnderTopBar(
                bar: const TopBar(slider: LanguageBar(pill: true)),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topBarInset,
                    16,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    _hero(context),
                    const SizedBox(height: 16),
                    const StreakWeek(),
                    if (progress.isNotEmpty) ...[
                      const SectionLabel('your record'),
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
            ),
          ),
        );
      },
    );
  }

  /// The player, the hero of the page: a large avatar, the name, and how many
  /// games since when. Tapping it opens the profile sheet.
  Widget _hero(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final since = _since();
    return InkWell(
      key: const ValueKey('you-chip'),
      borderRadius: BorderRadius.circular(radiusContainer),
      onTap: () => showProfileSheet(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
        child: Row(
          children: [
            ProfileAvatar(appState.profile, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appState.profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (since != null)
                    Text(
                      since,
                      key: const ValueKey('you-since'),
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: c.onSurfaceVariant),
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
    Widget? subtitle,
  }) {
    return GroupRow(
      key: ValueKey('you-row-$id'),
      leading: TonalTile(icon),
      title: Text(title),
      subtitle: subtitle ?? (sub == null ? null : Text(sub)),
      trailing: trailingWidget,
      onTap: onTap,
    );
  }
}
