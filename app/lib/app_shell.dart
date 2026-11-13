import 'package:flutter/material.dart';

import 'app_log.dart';
import 'changelog.dart';
import 'choose_dailies_sheet.dart';
import 'first_run/first_run_flow.dart';
import 'first_run/first_run_state.dart';
import 'main.dart' show appState;
import 'home.dart';
import 'learn_home.dart';
import 'routes.dart' show learnGate;
import 'update_check.dart' show appVersion;
import 'today_page.dart';
import 'words_page.dart';
import 'you_page.dart';

/// The home route: the new four-tab shell unless the player turned the new look
/// off in the settings, which gives the old home page.
class HomeSwitch extends StatefulWidget {
  const HomeSwitch({super.key, this.screens = const FirstRunScreens()});

  /// The first run's screens (a test puts fakes here).
  final FirstRunScreens screens;

  @override
  State<HomeSwitch> createState() => _HomeSwitchState();
}

class _HomeSwitchState extends State<HomeSwitch> {
  // decided once: a player in the middle of the first run stays in it even
  // when the first game makes them a player with history
  late bool _firstRun = appState.newUi && firstRunDue();

  /// A new player has no past version to read about: mark this one seen.
  void _skipChangelog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (appState.loaded &&
            appState.canRemember &&
            appState.changelogSeen != appVersion) {
          appState.noteChangelogSeen(appVersion);
        }
      } catch (e) {
        appLog.w('changelog', 'mark seen failed ${e.runtimeType}');
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) {
      if (_firstRun && appState.firstRunDone) _firstRun = false;
      if (!appState.newUi) return const HomePage();
      if (_firstRun) _skipChangelog();
      if (_firstRun) return FirstRunFlow(screens: widget.screens);
      return const AppShell();
    },
  );
}

/// Today, words, learn and you as four tabs; each page is a body and the pages
/// they open are pushed over the shell as before.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _tab = 'today';

  bool _changesChecked = false;

  /// First start of a new version, for someone who has played before: lists
  /// what changed in it, once (as the old home does).
  Future<void> _maybeShowChanges() async {
    try {
      if (_changesChecked || !appState.loaded || !appState.canRemember) return;
      _changesChecked = true;
      final returning = appState.seenHowTo || appState.stats.played > 0;
      if (appState.changelogSeen == appVersion) return;
      appState.noteChangelogSeen(appVersion);
      if (!returning || !showWhatsNew) return;
      final lines = await loadChangelog();
      if (lines.isEmpty || !mounted) return;
      showChangelog(context, lines);
    } catch (e) {
      appLog.w('changelog', 'whats new failed ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    appState.removeListener(_maybeShowChanges);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    appState.addListener(_maybeShowChanges);
    _maybeShowChanges();
    // the first run ended with "i know how lexodle works": pick the dailies once
    if (FirstRunSignals.takeChooseDailies()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !twoModesOpen()) return;
        try {
          showChooseDailies(context);
        } catch (e) {
          appLog.w('first-run', 'dailies sheet failed ${e.runtimeType}');
        }
      });
    }
  }

  /// The tabs the player has been taught: today and you always, words with
  /// my words and learn with how to play (see ladder.dart).
  List<String> _visible() {
    return [
      'today',
      if (appState.stepOpen('my words')) 'words',
      if (appState.stepOpen('how to play')) 'learn',
      'you',
    ];
  }

  static const _icons = {
    'today': (Icons.today_outlined, Icons.today),
    'words': (Icons.menu_book_outlined, Icons.menu_book),
    'learn': (Icons.school_outlined, Icons.school),
    'you': (Icons.person_outline, Icons.person),
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final tabs = _visible();
        final at = tabs.contains(_tab) ? tabs.indexOf(_tab) : 0;
        Widget page(String id) => switch (id) {
          'today' => const TodayPage(key: ValueKey('tab-today')),
          'words' => const WordsPage(key: ValueKey('tab-words')),
          'learn' => KeyedSubtree(
            key: const ValueKey('tab-learn'),
            child: learnGate(builder: (bank) => LearnHomePage(bank: bank)),
          ),
          _ => const YouPage(key: ValueKey('tab-you')),
        };
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: at,
              children: [for (final id in tabs) page(id)],
            ),
          ),
          // a soft shadow cast upwards, so what scrolls under the bar reads as
          // behind it (and the bar sits above any pinned action row)
          bottomNavigationBar: DecoratedBox(
            key: const ValueKey('tabs-shadow'),
            decoration: BoxDecoration(
              color: c.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: c.shadow.withValues(alpha: .2),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: c.shadow.withValues(alpha: .18),
                  offset: const Offset(0, -10),
                  blurRadius: 24,
                ),
              ],
            ),
            child: NavigationBar(
              key: const ValueKey('tabs'),
              height: 60,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              selectedIndex: at,
              onDestinationSelected: (i) => setState(() => _tab = tabs[i]),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final id in tabs)
                  NavigationDestination(
                    icon: Icon(_icons[id]!.$1),
                    selectedIcon: Icon(_icons[id]!.$2),
                    label: id,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
