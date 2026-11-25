import 'package:flutter/material.dart';

import 'modes.dart';
import 'mode_wheel.dart' show modeIconName;
import 'ui_kit.dart';

/// Picks which mode a page is about, or all of them (null): the one slider of the
/// app ([ChoiceSlider]), with the icon and name of the mode on show. [modes] are
/// the ones offered, in the order shown.
class ModeFilter extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChoiceSlider<GameMode?>(
      key: const ValueKey('mode-filter'),
      id: 'mode-slider',
      selected: selected,
      onChanged: onSelect,
      items: [
        if (showAll)
          const ChoiceItem<GameMode?>(
            value: null,
            label: 'all modes',
            icon: 'apps',
          ),
        for (final m in modes)
          ChoiceItem<GameMode?>(
            value: m,
            label: m.label,
            icon: modeIconName(m),
          ),
      ],
    );
  }
}
