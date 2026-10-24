import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'clock.dart';
import 'daily.dart';
import 'daily_streak.dart';
import 'difficulty.dart';
import 'logo.dart';
import 'stepper_choice.dart';
import 'style_chip.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'ui.dart';
import 'words.dart';

/// A word on each length, the second tier of the letters slider.
const _lengthNote = {
  4: 'short and quick',
  5: 'the classic',
  6: 'a step up',
  7: 'long',
  8: 'very long',
};

/// The height of the play button and of the settings button beside it.
const _buttonHeight = 52.0;

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

  /// The daily button's text: where today's daily word stands for [lang].
  String _dailyLabel(String lang) {
    final e = appState.dailyFor(lang, dailyDate());
    if (e == null) return 'daily';
    if (!e.over) return 'daily · ${e.guesses.length}/$dailyTries';
    return e.won! ? 'daily · solved in ${e.guesses.length}' : 'daily · missed';
  }

  Language _current(List<Language> langs) => langs.firstWhere(
    (l) => l.code == appState.lang,
    orElse: () => langs.first,
  );

  @override
  Widget build(BuildContext context) {
    final langs = _langs;
    final c = Theme.of(context).colorScheme;
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
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                        children: [
                          Row(
                            children: [
                              const LexodleLogo(width: 56),
                              const SizedBox(width: 16),
                              // the name shrinks before it can crowd the style
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'lexodle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const StyleChip(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Caption('a word game, in many tongues'),
                          const SizedBox(height: 28),
                          // the cards say what they are (a flag and a name,
                          // "5 letters", tries and words), so none has a header
                          DropdownMenu<String>(
                            initialSelection: lang.code,
                            expandedInsets: EdgeInsets.zero,
                            requestFocusOnTap: false,
                            enableSearch: false,
                            leadingIcon: Padding(
                              padding: const EdgeInsets.only(left: 12),
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
                              final nl = langs.firstWhere((l) => l.code == v);
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
                          const SizedBox(height: 20),
                          StepperChoice<int>(
                            semanticLabel: 'letters',
                            items: [
                              for (final n in lang.lengths)
                                (n, '$n letters', _lengthNote[n]),
                            ],
                            selected: length,
                            onChanged: (n) => appState.setup(length: n),
                          ),
                          const SizedBox(height: 20),
                          DifficultyMatrix(
                            tries: appState.tries,
                            pool: effectivePool(
                              appState.pool,
                              lang.counts[length],
                            ),
                            available: lang.counts[length],
                            onChanged: (t, pl) =>
                                appState.setup(tries: t, pool: pl),
                          ),
                          const SizedBox(height: 20),
                          // play and the gear share one height, set outright
                          // rather than left to each button's own minimum
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    fixedSize: const Size.fromHeight(
                                      _buttonHeight,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      Navigator.pushNamed(context, Routes.play),
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
                                    fixedSize: const Size.fromHeight(
                                      _buttonHeight,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    // the daily goes by the server's time: ask
                                    // again if it has not been for a while
                                    if (!TrustedClock.isFresh()) {
                                      await TrustedClock.sync(
                                        timeout: const Duration(
                                          milliseconds: 1500,
                                        ),
                                      );
                                    }
                                    if (!context.mounted) return;
                                    Navigator.pushNamed(context, Routes.daily);
                                  },
                                  child: Text(_dailyLabel(lang.code)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'settings',
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    fixedSize: const Size.square(_buttonHeight),
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    Routes.settings,
                                  ),
                                  // the app's own icon set, in an explicit colour
                                  child: Semantics(
                                    label: 'settings',
                                    child: TablerIcon(
                                      'settings',
                                      size: 28,
                                      color: c.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  Routes.achievements,
                                ),
                                child: Text(
                                  'achievements  $unlocked/${achievementCount()}',
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, Routes.howTo),
                                child: Text(
                                  'how to play',
                                  style: TextStyle(color: c.onSurface),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, Routes.about),
                                child: Text(
                                  'about',
                                  style: TextStyle(color: c.onSurface),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
