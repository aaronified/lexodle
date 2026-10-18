import 'package:flutter/material.dart';

import 'main.dart';
import 'store.dart';
import 'ui.dart';
import 'words.dart';

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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Caption(
                    '${appState.unlockedCount} of '
                    '${achievements.length} earned',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat('played', s.played),
                      _Stat('won', s.wins),
                      _Stat('streak', s.streak),
                      _Stat('best', s.bestStreak),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final a in achievements) ...[
                    const Divider(),
                    _Row(a, appState.ach[a.id] ?? AchState()),
                  ],
                  const SizedBox(height: 28),
                  const Caption('language mastery'),
                  const SizedBox(height: 4),
                  const Text(
                    'win once at every length and every difficulty setting '
                    '(tries and word pool) of a language.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Language>>(
                    future: WordBank.languages(),
                    builder: (context, snap) => Column(
                      children: [
                        for (final l in snap.data ?? const <Language>[])
                          _MasteryRow(l, s.mastery[l.code]?.length ?? 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Caption('history'),
                  const SizedBox(height: 10),
                  _History(c),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One achievement: its glyph, what it asks for, how often it has been earned
/// and, for numbered ones, a bar showing progress towards the next time.
class _Row extends StatelessWidget {
  const _Row(this.a, this.st);
  final Achievement a;
  final AchState st;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final earned = st.times > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // earned at least once: the accent colour; not yet: a faint ghost
              TablerIcon(
                a.icon,
                size: 32,
                color: earned ? c.primary : c.onSurface.withValues(alpha: .22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: earned ? 1 : .55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(a.description, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              if (earned)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '×${st.times}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.primary,
                      ),
                    ),
                    Caption(st.latest ?? ''),
                  ],
                ),
            ],
          ),
          if (a.numbered) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _Bar(progress: st.progress, target: a.target),
            ),
          ],
        ],
      ),
    );
  }
}

/// One language's mastery: how many of its settings have been won at.
class _MasteryRow extends StatelessWidget {
  const _MasteryRow(this.language, this.won);
  final Language language;
  final int won;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final target = masteryTarget(language);
    final done = won >= target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          FlagBadge(language.flag),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              language.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done ? FontWeight.bold : FontWeight.normal,
                color: done ? c.primary : c.onSurface,
              ),
            ),
          ),
          Expanded(
            child: _Bar(progress: won, target: target),
          ),
        ],
      ),
    );
  }
}

/// Progress towards the next earning. It starts again from 0 each time.
class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.target});
  final int progress;
  final int target;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final frac = (progress / target).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  key: const ValueKey('bar-fill'),
                  height: 4,
                  width: box.maxWidth * frac,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$progress/$target',
          style: TextStyle(
            fontSize: 11,
            color: c.onSurface.withValues(alpha: .6),
          ),
        ),
      ],
    );
  }
}

/// When each earned achievement was first and last earned, and how many times.
class _History extends StatelessWidget {
  const _History(this.c);
  final ColorScheme c;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final a in achievements)
        if ((appState.ach[a.id]?.times ?? 0) > 0) (a, appState.ach[a.id]!),
    ]..sort((x, y) => y.$2.latest!.compareTo(x.$2.latest!));

    if (rows.isEmpty) {
      return Text(
        'nothing earned yet.',
        style: TextStyle(
          fontSize: 13,
          color: c.onSurface.withValues(alpha: .6),
        ),
      );
    }

    final head = TextStyle(
      fontSize: 10,
      letterSpacing: .8,
      color: c.onSurface.withValues(alpha: .6),
    );
    const cell = TextStyle(fontSize: 11);
    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: w);
    return Table(
      columnWidths: const {
        1: FixedColumnWidth(34),
        2: FixedColumnWidth(88),
        3: FixedColumnWidth(88),
      },
      children: [
        TableRow(
          children: [
            pad(Text('achievement', style: head)),
            pad(Text('times', style: head, textAlign: TextAlign.right)),
            pad(Text('first', style: head, textAlign: TextAlign.right)),
            pad(Text('latest', style: head, textAlign: TextAlign.right)),
          ],
        ),
        for (final (a, st) in rows)
          TableRow(
            children: [
              pad(Text(a.title, style: cell)),
              pad(Text('${st.times}', style: cell, textAlign: TextAlign.right)),
              pad(
                Text(st.first ?? '', style: cell, textAlign: TextAlign.right),
              ),
              pad(
                Text(st.latest ?? '', style: cell, textAlign: TextAlign.right),
              ),
            ],
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Caption(label),
      ],
    ),
  );
}
