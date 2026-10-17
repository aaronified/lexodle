import 'package:flutter/material.dart';

import 'achievements_page.dart';
import 'game.dart';
import 'how_to.dart';
import 'logo.dart';
import 'solver.dart';
import 'main.dart';
import 'store.dart';
import 'ui.dart';
import 'words.dart';

const difficulties = <(String, int)>[
  ('easy', 8),
  ('normal', 6),
  ('hard', 4),
  ('brutal', 3),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Language>? _langs;
  bool _starting = false;

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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HowToPage()),
        );
      }
    });
  }

  Language _current(List<Language> langs) => langs.firstWhere(
    (l) => l.code == appState.lang,
    orElse: () => langs.first,
  );

  Future<void> _start(Language lang, {bool solver = false}) async {
    setState(() => _starting = true);
    final bank = await WordBank.load(lang);
    if (!mounted) return;
    setState(() => _starting = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => solver ? SolverPage(bank: bank) : GamePage(bank: bank),
      ),
    );
  }

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
                              Text(
                                'lexodle',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Caption('a word game, in many tongues'),
                          const SizedBox(height: 40),
                          const Caption('language'),
                          const SizedBox(height: 10),
                          DropdownMenu<String>(
                            initialSelection: lang.code,
                            expandedInsets: EdgeInsets.zero,
                            requestFocusOnTap: false,
                            enableSearch: false,
                            dropdownMenuEntries: [
                              for (final l in langs)
                                DropdownMenuEntry(value: l.code, label: l.name),
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
                          const SizedBox(height: 28),
                          const Caption('letters'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final n in lang.lengths)
                                Choice(
                                  '$n',
                                  selected: n == length,
                                  onTap: () => appState.setup(length: n),
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Caption('difficulty · number of tries'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (name, n) in difficulties)
                                Choice(
                                  name,
                                  sub: '$n tries',
                                  selected: n == appState.tries,
                                  onTap: () => appState.setup(tries: n),
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Caption('helper'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final h in Helper.values)
                                Choice(
                                  h.label,
                                  sub: h.sub,
                                  selected: h == appState.helper,
                                  onTap: () => appState.setup(helper: h),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'skill: how well a guess narrows the field '
                            '(100 = best possible). luck: how much smaller (+, '
                            'green) or larger (-, red) than average the pool '
                            'you landed in was (0% = average). everything is '
                            'revealed when the game ends.',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurface.withValues(alpha: .6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _starting ? null : () => _start(lang),
                            child: Text(_starting ? 'loading…' : 'play'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _starting
                                ? null
                                : () => _start(lang, solver: true),
                            child: const Text('solver'),
                          ),
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AchievementsPage(),
                                  ),
                                ),
                                child: Text(
                                  'achievements  $unlocked/${achievementCount()}',
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HowToPage(),
                                  ),
                                ),
                                child: Text(
                                  'how to play',
                                  style: TextStyle(color: c.onSurface),
                                ),
                              ),
                              TextButton(
                                onPressed: () => showAboutDialog(
                                  context: context,
                                  applicationName: 'lexodle',
                                  children: const [
                                    Text(
                                      'English 5-letter words: Google Ngrams '
                                      'and dwyl/english-words. Other words: '
                                      'wordfreq (CC BY-SA 4.0). Font: '
                                      'JetBrains Mono (OFL). Icons: Tabler '
                                      'Icons (MIT).',
                                    ),
                                  ],
                                ),
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
