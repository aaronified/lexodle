import 'package:flutter/material.dart';

import 'achievements_page.dart';
import 'difficulty.dart';
import 'game.dart';
import 'how_to.dart';
import 'logo.dart';
import 'solver.dart';
import 'stepper_choice.dart';
import 'main.dart';
import 'store.dart';
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
                          const SizedBox(height: 28),
                          const Caption('letters'),
                          const SizedBox(height: 10),
                          StepperChoice<int>(
                            semanticLabel: 'letters',
                            items: [
                              for (final n in lang.lengths)
                                (n, '$n letters', _lengthNote[n]),
                            ],
                            selected: length,
                            onChanged: (n) => appState.setup(length: n),
                          ),
                          const SizedBox(height: 28),
                          const Caption(
                            'difficulty · tries across, word pool down',
                          ),
                          const SizedBox(height: 12),
                          DifficultyMatrix(
                            tries: appState.tries,
                            pool: appState.pool,
                            available: lang.counts[length],
                            onChanged: (t, pl) =>
                                appState.setup(tries: t, pool: pl),
                          ),
                          const SizedBox(height: 28),
                          const Caption('helper'),
                          const SizedBox(height: 10),
                          StepperChoice<Helper>(
                            semanticLabel: 'helper',
                            items: [
                              for (final h in Helper.values)
                                (h, h.label, h.sub),
                            ],
                            selected: appState.helper,
                            onChanged: (h) => appState.setup(helper: h),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'whatever you choose, everything is revealed when '
                            'the game ends.',
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
                                      'Words: wordfreq (CC BY-SA 4.0), '
                                      'filtered with spelling dictionaries. '
                                      'Definitions: Wiktionary (CC BY-SA 4.0). '
                                      'Font: JetBrains Mono (OFL). Icons: '
                                      'Tabler Icons (MIT). Full licences are '
                                      'under "view licenses".',
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
