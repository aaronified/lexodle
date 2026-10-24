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

/// The space the play row takes in the page: its height and the gap above it.
const _playBlock = _buttonHeight + 20;

/// The room around the page's content (the list's top and bottom padding).
const _pagePadding = 40.0 + 24.0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Language>? _langs;

  bool _howToShown = false;

  // The play row is pinned to the bottom of the screen when the rest of the page
  // does not fit without scrolling, and otherwise sits in the page. Whether it
  // fits is judged from the page without that row (these two keys), so pinning
  // the row cannot flip the answer back.
  final _topKey = GlobalKey();
  final _bottomKey = GlobalKey();
  bool _pinned = false;

  void _judge(double room) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      double height(GlobalKey k) =>
          (k.currentContext?.findRenderObject() as RenderBox?)?.size.height ??
          0;
      final need =
          height(_topKey) + height(_bottomKey) + _pagePadding + _playBlock;
      final pin = need > room;
      if (pin != _pinned) setState(() => _pinned = pin);
    });
  }

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

  /// Play, the daily, and the two icon buttons: game modes and settings.
  Widget _playRow(BuildContext context, Language lang) {
    final c = Theme.of(context).colorScheme;
    Widget square(String tip, String icon, String route) => Tooltip(
      message: tip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          fixedSize: const Size.square(_buttonHeight),
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => Navigator.pushNamed(context, route),
        // the app's own icon set, in an explicit colour
        child: Semantics(
          label: tip,
          child: TablerIcon(icon, size: 28, color: c.onSurface),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(_buttonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.pushNamed(context, Routes.play),
            child: Text(
              appState.mode == GameMode.classic
                  ? 'play'
                  : 'play · ${appState.mode.label}',
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
            child: _dailyChild(lang.code),
          ),
        ),
        const SizedBox(width: 8),
        square('game modes', 'layout-grid', Routes.gameModes),
        const SizedBox(width: 8),
        square('settings', 'settings', Routes.settings),
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
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      return LayoutBuilder(
                        builder: (context, box) {
                          _judge(box.maxHeight);
                          return Column(
                            children: [
                              Expanded(
                                // (not a ListView: that builds only what is near the
                                // window, and the page's height is measured)
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
                                      Column(
                                        key: _topKey,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              const LexodleLogo(width: 56),
                                              const SizedBox(width: 16),
                                              // the name shrinks before it can
                                              // crowd the style
                                              Expanded(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
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
                                              StyleChip(
                                                onTap: () =>
                                                    Navigator.pushNamed(
                                                      context,
                                                      Routes.history,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip: 'about',
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                // the app's own icon set, like
                                                // the buttons below
                                                icon: Semantics(
                                                  label: 'about',
                                                  child: TablerIcon(
                                                    'info-circle',
                                                    size: 26,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pushNamed(
                                                      context,
                                                      Routes.about,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Caption(
                                            'a word game, in many tongues',
                                          ),
                                          const SizedBox(height: 28),
                                          // the card says what it is (a flag and
                                          // a name), so it has no header
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
                                                  leadingIcon: FlagBadge(
                                                    l.flag,
                                                  ),
                                                ),
                                            ],
                                            onSelected: (v) {
                                              if (v == null) return;
                                              final nl = langs.firstWhere(
                                                (l) => l.code == v,
                                              );
                                              appState.setup(
                                                lang: v,
                                                length:
                                                    nl.lengths.contains(length)
                                                    ? length
                                                    : nl.lengths.first,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 20),
                                          const DailyStreak(),
                                        ],
                                      ),
                                      // in the page unless it is pinned below
                                      if (!_pinned) ...[
                                        const SizedBox(height: 20),
                                        _playRow(context, lang),
                                      ],
                                      Column(
                                        key: _bottomKey,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
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
                                            key: const ValueKey(
                                              'how-to-button',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_pinned)
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
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
