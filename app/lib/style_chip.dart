import 'package:flutter/material.dart';

import 'main.dart';
import 'playstyle.dart';
import 'ui.dart';

/// The height of the name under the icon, and of the space above it that keeps
/// the icon centred.
const _labelHeight = 16.0;

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
    final games = appState.history.recentClassic(100, appState.lang).length;
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
            // the icon, not the icon and its name, is what sits on the middle
            // of the header row: an empty space the height of the name goes
            // above it, so the name hangs below and the icon stays centred
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: _labelHeight),
                TablerIcon(
                  p?.icon ?? 'puzzle',
                  key: ValueKey('style-icon-${p?.id ?? 'unrated'}'),
                  size: 34,
                  color: p == null
                      ? c.onSurface.withValues(alpha: dimAlpha)
                      : c.primary,
                ),
                SizedBox(
                  height: _labelHeight,
                  child: Center(
                    child: Text(
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
