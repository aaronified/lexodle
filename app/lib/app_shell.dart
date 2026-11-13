import 'package:flutter/material.dart';

import 'app_log.dart';
import 'choose_dailies_sheet.dart';
import 'first_run/first_run_flow.dart';
import 'first_run/first_run_state.dart';
import 'main.dart' show appState;
import 'home.dart';
import 'learn_home.dart';
import 'routes.dart' show learnGate;
import 'today_page.dart';
import 'words_page.dart';
import 'you_page.dart';

/// The home route: the new four-tab shell when the preview is switched on in the
/// settings, the old home page otherwise.
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) {
      if (_firstRun && appState.firstRunDone) _firstRun = false;
      if (!appState.newUi) return const HomePage();
      if (_firstRun) return FirstRunFlow(screens: widget.screens);
      return AppShell(screens: widget.screens);
    },
  );
}

/// Today, words, learn and you as four tabs; each page is a body and the pages
/// they open are pushed over the shell as before.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.screens = const FirstRunScreens()});

  /// The first game's screen, for the replay from you (a test puts a fake).
  final FirstRunScreens screens;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _tab = 'today';

  @override
  void initState() {
    super.initState();
    // the first run ended with "i know how lexodle works": pick the dailies once
    if (FirstRunSignals.takeChooseDailies()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          showChooseDailies(context);
        } catch (e) {
          appLog.w('first-run', 'dailies sheet failed ${e.runtimeType}');
        }
      });
    }
  }

  void _replayFirstGame() {
    try {
      Navigator.of(context).push(practiceRoute(screens: widget.screens));
    } catch (e) {
      appLog.w('first-run', 'replay failed ${e.runtimeType}');
    }
  }

  /// The tabs the player has been taught: today and you from the end of the
  /// first game, words with my words (game 9), and learn, the last piece, at
  /// game 24. A veteran has all four.
  List<String> _visible() {
    final played = appState.stats.played, vet = appState.lex.veteran;
    return [
      'today',
      if (vet || played >= 9) 'words',
      if (vet || played >= 24) 'learn',
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
          'today' => const TodayPage(),
          'words' => const WordsPage(),
          'learn' => learnGate(builder: (bank) => LearnHomePage(bank: bank)),
          _ => YouPage(onReplayFirstGame: _replayFirstGame),
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
