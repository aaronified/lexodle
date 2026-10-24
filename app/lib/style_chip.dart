import 'package:flutter/material.dart';

import 'main.dart';
import 'playstyle.dart';
import 'ui.dart';

/// The home page's playstyle, read from the last 100 games, as a square button
/// like the ones beside it: the playstyle's icon in a box. Its name is the
/// tooltip. Until there are enough games to rate, a dim placeholder icon says
/// so, and the tooltip says how many are played towards it. It is the same icon
/// as the playstyle's achievement.
class StyleChip extends StatelessWidget {
  const StyleChip({super.key, this.onTap, this.size = 52});

  /// Where a tap goes (the history), if anywhere.
  final VoidCallback? onTap;

  /// The side of the box.
  final double size;

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
    final progress = '$games/$minRatedGames';
    final tip = p == null
        ? 'playstyle: play $minRatedGames classic games to be given one '
              '($progress)'
        : 'playstyle: ${p.name}. ${p.blurb}';
    return Tooltip(
      message: tip,
      child: Semantics(
        button: onTap != null,
        container: true,
        excludeSemantics: true,
        label: p == null
            ? 'playstyle: not rated yet, $progress games'
            : 'playstyle: ${p.name}',
        child: OutlinedButton(
          key: const ValueKey('style-chip'),
          style: OutlinedButton.styleFrom(
            fixedSize: Size.square(size),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: TablerIcon(
            p?.icon ?? 'puzzle',
            key: ValueKey('style-icon-${p?.id ?? 'unrated'}'),
            size: 28,
            color: p == null
                ? c.onSurface.withValues(alpha: dimAlpha)
                : c.primary,
          ),
        ),
      ),
    );
  }
}
