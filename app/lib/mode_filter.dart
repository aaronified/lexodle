import 'package:flutter/material.dart';

import 'app_log.dart';
import 'edge_fade.dart';
import 'mode_wheel.dart' show modeIconName;
import 'modes.dart';
import 'ui.dart';

/// A row to pick which mode a page is about, or all of them (null): the same
/// look as the language picker. [modes] are the ones offered, in the order shown.
/// One row that scrolls sideways, faded only where there is more to scroll to;
/// the selected chip is brought into view.
class ModeFilter extends StatefulWidget {
  const ModeFilter({
    super.key,
    required this.selected,
    required this.onSelect,
    this.modes = GameMode.values,
    this.showAll = true,
  });

  final GameMode? selected;
  final ValueChanged<GameMode?> onSelect;
  final List<GameMode> modes;

  /// Offers "all" first (null); false for a page that is always about a mode.
  final bool showAll;

  @override
  State<ModeFilter> createState() => _ModeFilterState();
}

class _ModeFilterState extends State<ModeFilter> {
  final _keys = <GameMode?, GlobalKey>{};

  GlobalKey _keyOf(GameMode? m) => _keys.putIfAbsent(m, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(ModeFilter old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  /// Scrolls the selected chip into view once it is built, if it is not.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final ctx = _keys[widget.selected]?.currentContext;
        if (!mounted || ctx == null || !ctx.mounted) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
        );
      } catch (e) {
        appLog.w(
          'mode-filter',
          'could not scroll to the mode: ${e.runtimeType}',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final selected = widget.selected;
    Widget chip(String label, GameMode? mode, Key key) {
      final on = mode == selected;
      final color = on ? c.onSecondaryContainer : null;
      return Semantics(
        key: _keyOf(mode),
        button: true,
        selected: on,
        label: mode == null ? 'all modes' : mode.label,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          onTap: () => widget.onSelect(mode),
          borderRadius: BorderRadius.circular(3),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? c.secondaryContainer : c.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mode != null) ...[
                    TablerIcon(
                      modeIconName(mode),
                      size: 14,
                      color: color ?? c.onSurface,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.bold : null,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return EdgeFade(
      key: const ValueKey('mode-filter'),
      scrollKey: const ValueKey('mode-filter-scroll'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showAll) chip('all', null, const ValueKey('mode-all')),
          for (final m in widget.modes) ...[
            if (widget.showAll || m != widget.modes.first)
              const SizedBox(width: 6),
            chip(m.label, m, ValueKey('mode-${m.name}')),
          ],
        ],
      ),
    );
  }
}
