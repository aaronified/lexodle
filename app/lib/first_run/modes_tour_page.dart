import 'package:flutter/material.dart';

import '../app_log.dart';
import '../mode_wheel.dart';
import '../modes.dart';
import '../ui.dart';

/// The idea of each mode in a line, and the rule that differs in a line. Checked
/// against the how-to text of each mode (`modeHelp` in help.dart) and the
/// ladder notes (ladder.dart).
const _idea = <GameMode, String>{
  GameMode.quartet: 'four words at once. one guess plays on all four.',
  GameMode.relay: 'four words, one after the other.',
  GameMode.lockdown: 'greens lock for good, and bad words cost hearts.',
  GameMode.themed: 'place names, in english.',
  GameMode.blind: 'only counts, no tile colours.',
  GameMode.equations: 'find the true equation.',
  GameMode.mastermind: 'the word dodges you.',
};

const _rule = <GameMode, String>{
  GameMode.quartet: 'every key is split in four. a solved board drops out. you get nine tries.',
  GameMode.relay: 'the next word opens with every guess played.',
  GameMode.lockdown:
      'a word not in the list costs a heart. no hearts left, you lose.',
  GameMode.themed: 'only places count. tap the i to learn about one.',
  GameMode.blind:
      'you see how many letters are right, and how many are elsewhere.',
  GameMode.equations: 'digits and signs are the tiles. a true sum with one =.',
  GameMode.mastermind: 'no word is chosen. each reply fits a word still possible. no limit on tries.',
};

/// A swipeable card per mode (classic is left out: the player just played it).
/// [onLearn] gets the mode shown, [onDone] ends the tour (the X or finish).
class ModesTourPage extends StatefulWidget {
  const ModesTourPage({super.key, required this.onLearn, required this.onDone});

  final void Function(GameMode mode) onLearn;
  final VoidCallback onDone;

  @override
  State<ModesTourPage> createState() => _ModesTourPageState();
}

class _ModesTourPageState extends State<ModesTourPage> {
  static final _modes = [
    for (final m in GameMode.values)
      if (m != GameMode.classic) m,
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _learn() {
    try {
      widget.onLearn(_modes[_page]);
    } catch (e) {
      appLog.w('modes_tour.learn', '${e.runtimeType}');
    }
  }

  void _done() {
    try {
      widget.onDone();
    } catch (e) {
      appLog.w('modes_tour.done', '${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'the modes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('tour-close'),
                      tooltip: 'close the tour',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: _done,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('tour-pages'),
                  controller: _controller,
                  itemCount: _modes.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _card(c, _modes[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _modes.length; i++)
                    Container(
                      key: ValueKey('tour-dot-$i'),
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? c.onSurface
                            : c.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const ValueKey('tour-finish'),
                  onPressed: _done,
                  child: const Text('finish'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme c, GameMode m) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablerIcon(modeIconName(m), size: 72, color: c.primary),
          const SizedBox(height: 14),
          Text(
            m.label,
            key: ValueKey('tour-name-${m.name}'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                Text(
                  _idea[m] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 10),
                Text(
                  _rule[m] ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonal(
            key: const ValueKey('tour-learn'),
            style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: _learn,
            child: const Text('learn'),
          ),
        ],
      ),
    ),
  );
}
