import 'package:flutter/material.dart';

import 'main.dart';
import 'playstyle.dart';
import 'ui.dart';

/// The home page's playstyle: its icon and name, read from the last 100 games.
/// Until there are enough games to rate, a dim placeholder says how many are
/// played towards it. It is the same icon as the playstyle's achievement.
class StyleChip extends StatelessWidget {
  const StyleChip({super.key, this.onTap});

  /// Where a tap goes (the history), if anywhere.
  final VoidCallback? onTap;

  // it listens for itself: the home page builds it as a const, which Flutter
  // does not rebuild when the page does, so a game finished in front of it
  // would leave it showing the old style
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: appState, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final c = Theme.of(context).colorScheme;
    final p = appState.style;
    final games = appState.history.recentClassic().length;
    final label =
        p?.name ??
        (games < minRatedGames ? '$games/$minRatedGames' : 'unrated');
    final tip = p == null
        ? 'play $minRatedGames classic games to be given a playstyle'
        : '${p.name}: ${p.blurb}';
    return Tooltip(
      message: tip,
      child: Semantics(
        button: onTap != null,
        container: true,
        excludeSemantics: true,
        label: p == null
            ? 'playstyle: not rated yet, $label games'
            : 'playstyle: ${p.name}',
        child: InkWell(
          key: const ValueKey('style-chip'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TablerIcon(
                  p?.icon ?? 'puzzle',
                  key: ValueKey('style-icon-${p?.id ?? 'unrated'}'),
                  size: 34,
                  color: p == null
                      ? c.onSurface.withValues(alpha: dimAlpha)
                      : c.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  key: const ValueKey('style-label'),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .8,
                    color: p == null
                        ? c.onSurface.withValues(alpha: dimAlpha)
                        : c.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
