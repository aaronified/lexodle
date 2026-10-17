import 'package:flutter/material.dart';

import 'achievements_page.dart';
import 'game.dart';
import 'main.dart';
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

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((l) => setState(() => _langs = l));
  }

  Language _current(List<Language> langs) =>
      langs.firstWhere((l) => l.code == appState.lang, orElse: () => langs.first);

  Future<void> _start(Language lang) async {
    setState(() => _starting = true);
    final bank = await WordBank.load(lang);
    if (!mounted) return;
    setState(() => _starting = false);
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => GamePage(bank: bank)));
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
                      final unlocked = appState.unlocked.length;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                        children: [
                          Text('lexodle',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
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
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final n in lang.lengths)
                              Choice('$n',
                                  selected: n == length,
                                  onTap: () => appState.setup(length: n)),
                          ]),
                          const SizedBox(height: 28),
                          const Caption('difficulty · number of tries'),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final (name, n) in difficulties)
                              Choice(name,
                                  sub: '$n tries',
                                  selected: n == appState.tries,
                                  onTap: () => appState.setup(tries: n)),
                          ]),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('show words left',
                                style: TextStyle(fontSize: 14)),
                            value: appState.showWordsLeft,
                            onChanged: (v) => appState.setup(showWordsLeft: v),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _starting ? null : () => _start(lang),
                            child: Text(_starting ? 'loading…' : 'play'),
                          ),
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AchievementsPage())),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      'achievements  $unlocked/${achievementCount()}'),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => showAboutDialog(
                                context: context,
                                applicationName: 'lexodle',
                                children: const [
                                  Text('English 5-letter words: Google Ngrams '
                                      'and dwyl/english-words. Other words: '
                                      'wordfreq (CC BY-SA 4.0). Font: '
                                      'JetBrains Mono (OFL).'),
                                ],
                              ),
                              child: Text('about',
                                  style: TextStyle(color: c.onSurface)),
                            ),
                          ]),
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
