import 'package:flutter/material.dart';

import 'main.dart' show appState;
import 'home.dart';
import 'learn_home.dart';
import 'routes.dart' show learnGate;
import 'today_page.dart';
import 'ui.dart';
import 'words_page.dart';
import 'you_page.dart';

/// The home route: the new four-tab shell when the preview is switched on in the
/// settings, the old home page otherwise.
class HomeSwitch extends StatelessWidget {
  const HomeSwitch({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) =>
        appState.newUi ? const AppShell() : const HomePage(),
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
          _ => YouPage(
            onReplayFirstGame: () =>
                showToast(context, 'your first game is next'),
          ),
        };
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: at,
              children: [for (final id in tabs) page(id)],
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(color: c.surfaceContainerHighest),
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
