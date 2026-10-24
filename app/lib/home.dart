import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'clock.dart';
import 'daily.dart';
import 'daily_streak.dart';
import 'logo.dart';
import 'style_chip.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'ui.dart';
import 'words.dart';

/// The height of the play button, the buttons beside it and the menu buttons.
const _buttonHeight = 52.0;

/// The narrowest window that counts as a desktop. Narrower is a phone, where the
/// play row sticks to the bottom of the screen; on a desktop it floats, as the
/// last row of the page.
const _desktopWidth = 600.0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Language>? _langs;

  bool _howToShown = false;

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((l) => setState(() => _langs = l));
    appState.addListener(_maybeShowHowTo);
    _maybeShowHowTo();
  }

  @override
  void dispose() {
    appState.removeListener(_maybeShowHowTo);
    super.dispose();
  }

  /// First visit: open how to play once, and remember that it was shown.
  void _maybeShowHowTo() {
    if (_howToShown || !appState.loaded || appState.seenHowTo) return;
    if (!appState.canRemember) return;
    _howToShown = true;
    appState.markHowToSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          Routes.howTo,
          arguments: onboardingArgument,
        );
      }
    });
  }

  /// The small second line under "daily": where today's daily word stands for
  /// [lang], or null before it is started.
  String? _dailyStatus(String lang) {
    final e = appState.dailyFor(lang, dailyDate());
    if (e == null) return null;
    if (!e.over) return '${e.guesses.length}/$dailyTries';
    return e.won! ? 'solved in ${e.guesses.length}' : 'missed';
  }

  /// "daily", with the status in a smaller font under it so a long status
  /// never wraps the button label onto three rows.
  Widget _dailyChild(String lang) {
    final status = _dailyStatus(lang);
    if (status == null) return const Text('daily');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('daily'),
        Text(status, style: const TextStyle(fontSize: 11, height: 1.1)),
      ],
    );
  }

  Language _current(List<Language> langs) => langs.firstWhere(
    (l) => l.code == appState.lang,
    orElse: () => langs.first,
  );

  /// The play row, the last row of the page: the playstyle, play, the daily, and
  /// game modes. The playstyle and game modes are square, like the settings
  /// button at the top.
  Widget _playRow(BuildContext context, Language lang) {
    final c = Theme.of(context).colorScheme;
    // a label that does not fit shrinks, so a long mode name never wraps
    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);
    return Row(
      children: [
        StyleChip(
          size: _buttonHeight,
          onTap: () => Navigator.pushNamed(context, Routes.history),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(_buttonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => Navigator.pushNamed(context, Routes.play),
            child: fit(
              Text(
                appState.mode == GameMode.classic
                    ? 'play'
                    : 'play · ${appState.mode.label}',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('daily-button'),
            style: OutlinedButton.styleFrom(
              fixedSize: const Size.fromHeight(_buttonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () async {
              // the daily goes by the server's time: ask again if it has not
              // been for a while
              if (!TrustedClock.isFresh()) {
                await TrustedClock.sync(
                  timeout: const Duration(milliseconds: 1500),
                );
              }
              if (!context.mounted) return;
              Navigator.pushNamed(context, Routes.daily);
            },
            child: fit(_dailyChild(lang.code)),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'game modes',
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              fixedSize: const Size.square(_buttonHeight),
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.pushNamed(context, Routes.gameModes),
            // the app's own icon set, in an explicit colour
            child: Semantics(
              label: 'game modes',
              child: TablerIcon('layout-grid', size: 28, color: c.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  /// A full-width menu button, as tall as play.
  Widget _menuButton(String label, String route, {Key? key}) => SizedBox(
    width: double.infinity,
    height: _buttonHeight,
    child: OutlinedButton(
      key: key,
      onPressed: () => Navigator.pushNamed(context, route),
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final langs = _langs;
    final c = Theme.of(context).colorScheme;
    // a phone sticks the play row to the bottom of the screen; a desktop lets it
    // float as the last row of the page
    return Scaffold(
      body: SafeArea(
        // (the width the page is given, so a window and a test both decide it)
        child: LayoutBuilder(
          builder: (context, outer) {
            final phone = outer.maxWidth < _desktopWidth;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: langs == null
                    ? const SizedBox()
                    : ListenableBuilder(
                        listenable: appState,
                        builder: (context, _) {
                          final lang = _current(langs);
                          final length = lang.lengths.contains(appState.length)
                              ? appState.length
                              : lang.lengths.first;
                          final unlocked = appState.unlockedCount;
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    40,
                                    24,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const LexodleLogo(width: 56),
                                          const SizedBox(width: 16),
                                          // the name shrinks before it can crowd the
                                          // settings button
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'lexodle',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          // settings, with about inside it
                                          IconButton(
                                            tooltip: 'settings',
                                            constraints: const BoxConstraints(
                                              minWidth: 48,
                                              minHeight: 48,
                                            ),
                                            // the app's own icon set, like the
                                            // buttons below
                                            icon: Semantics(
                                              label: 'settings',
                                              child: TablerIcon(
                                                'settings',
                                                size: 28,
                                                color: c.onSurface,
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pushNamed(
                                                  context,
                                                  Routes.settings,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Caption(
                                        'a word game, in many tongues',
                                      ),
                                      const SizedBox(height: 28),
                                      // the card says what it is (a flag and a
                                      // name), so it has no header
                                      DropdownMenu<String>(
                                        initialSelection: lang.code,
                                        expandedInsets: EdgeInsets.zero,
                                        requestFocusOnTap: false,
                                        enableSearch: false,
                                        leadingIcon: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                          ),
                                          child: FlagBadge(lang.flag),
                                        ),
                                        dropdownMenuEntries: [
                                          for (final l in langs)
                                            DropdownMenuEntry(
                                              value: l.code,
                                              label: l.name,
                                              leadingIcon: FlagBadge(l.flag),
                                            ),
                                        ],
                                        onSelected: (v) {
                                          if (v == null) return;
                                          final nl = langs.firstWhere(
                                            (l) => l.code == v,
                                          );
                                          appState.setup(
                                            lang: v,
                                            length: nl.lengths.contains(length)
                                                ? length
                                                : nl.lengths.first,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      const DailyStreak(),
                                      const SizedBox(height: 28),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      _menuButton(
                                        'achievements  $unlocked/${achievementCount()}',
                                        Routes.achievements,
                                        key: const ValueKey(
                                          'achievements-button',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _menuButton(
                                        'how to play',
                                        Routes.howTo,
                                        key: const ValueKey('how-to-button'),
                                      ),
                                      // on a desktop the row floats: the last row
                                      if (!phone) ...[
                                        const SizedBox(height: 20),
                                        _playRow(context, lang),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // on a phone it sticks to the bottom
                              if (phone)
                                Padding(
                                  key: const ValueKey('pinned-play'),
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    24,
                                    16,
                                  ),
                                  child: _playRow(context, lang),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
