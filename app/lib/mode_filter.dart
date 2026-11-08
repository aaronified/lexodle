import 'package:flutter/material.dart';

import 'modes.dart';

/// A row to pick which mode a page is about, or all of them (null): the same
/// look as the language picker. [modes] are the ones offered, in the order shown.
class ModeFilter extends StatelessWidget {
  const ModeFilter({
    super.key,
    required this.selected,
    required this.onSelect,
    this.modes = GameMode.values,
  });

  final GameMode? selected;
  final ValueChanged<GameMode?> onSelect;
  final List<GameMode> modes;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget chip(String label, GameMode? mode, Key key) => Semantics(
      button: true,
      selected: mode == selected,
      label: mode == null ? 'all modes' : mode.label,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: () => onSelect(mode),
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
              color: mode == selected ? c.primary : c.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: mode == selected ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
    return Wrap(
      key: const ValueKey('mode-filter'),
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('all', null, const ValueKey('mode-all')),
        for (final m in modes) chip(m.label, m, ValueKey('mode-${m.name}')),
      ],
    );
  }
}
