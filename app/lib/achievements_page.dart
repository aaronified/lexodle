import 'package:flutter/material.dart';

import 'main.dart';
import 'store.dart';
import 'ui.dart';

int achievementCount() => achievements.length;

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('achievements')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              final s = appState.stats;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Caption('${appState.unlocked.length} of '
                      '${achievements.length} unlocked'),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Stat('played', s.played),
                    _Stat('won', s.wins),
                    _Stat('streak', s.streak),
                    _Stat('best', s.bestStreak),
                  ]),
                  const SizedBox(height: 20),
                  for (final a in achievements) ...[
                    const Divider(),
                    Builder(builder: (context) {
                      final date = appState.unlocked[a.id];
                      final done = date != null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: done ? c.primary : null,
                              border: Border.all(
                                  color: done ? c.primary : c.outline),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Opacity(
                              opacity: done ? 1 : .55,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(a.description,
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          if (done) Caption(date),
                        ]),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Caption(label),
        ]),
      );
}
