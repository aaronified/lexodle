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
  int _tab = 0;

  static const _tabs = [
    (Icons.today_outlined, Icons.today, 'today'),
    (Icons.menu_book_outlined, Icons.menu_book, 'words'),
    (Icons.school_outlined, Icons.school, 'learn'),
    (Icons.person_outline, Icons.person, 'you'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            const TodayPage(),
            const WordsPage(),
            learnGate(builder: (bank) => LearnHomePage(bank: bank)),
            YouPage(
              onReplayFirstGame: () =>
                  showToast(context, 'your first game is next'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.outlineVariant)),
        ),
        child: NavigationBar(
          key: const ValueKey('tabs'),
          height: 60,
          elevation: 0,
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final (off, on, label) in _tabs)
              NavigationDestination(
                icon: Icon(off),
                selectedIcon: Icon(on),
                label: label,
              ),
          ],
        ),
      ),
    );
  }
}
