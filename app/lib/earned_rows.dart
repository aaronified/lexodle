import 'package:flutter/material.dart';

import 'store.dart';
import 'ui.dart';

/// The achievements a game or a piece of learning has just earned, one row each:
/// the icon, what it is called and what it asked.
class EarnedRows extends StatelessWidget {
  const EarnedRows(this.earned, {super.key});
  final List<Achievement> earned;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('earned-rows'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in earned)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                TablerIcon(a.icon, size: 30, color: c.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${a.title}  —  ${a.description}',
                    style: TextStyle(color: c.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// What a game from the history earned, under its own heading; nothing when it
/// earned nothing (or is from before that was kept).
class EarnedInGame extends StatelessWidget {
  const EarnedInGame(this.earned, {super.key});
  final List<Achievement> earned;

  @override
  Widget build(BuildContext context) {
    if (earned.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('earned-in-game'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption(
            earned.length == 1
                ? 'earned in this game'
                : '${earned.length} earned in this game',
          ),
          const SizedBox(height: 8),
          EarnedRows(earned),
        ],
      ),
    );
  }
}

/// The medals of a game on its row of the history: an icon for each of the first
/// few, and how many more.
class EarnedStrip extends StatelessWidget {
  const EarnedStrip(this.earned, {super.key, this.shown = 4});
  final List<Achievement> earned;
  final int shown;

  @override
  Widget build(BuildContext context) {
    if (earned.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('earned-strip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in earned.take(shown))
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: TablerIcon(a.icon, size: 14, color: c.primary),
          ),
        if (earned.length > shown)
          Text(
            '+${earned.length - shown}',
            style: TextStyle(fontSize: 11, color: c.primary),
          ),
      ],
    );
  }
}
