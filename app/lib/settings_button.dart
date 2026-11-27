import 'package:flutter/material.dart';

import 'app_log.dart';
import 'routes.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart' show topBarShadow;

/// The settings button, top right of every tab and secondary page (the game
/// screens and the tutorials have their own corner buttons).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.floating = false});

  /// The cog of the top bar: a round tonal button floating on shadows.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final button = IconButton(
      key: const ValueKey('settings-button'),
      tooltip: 'settings',
      icon: TablerIcon('settings', size: 24, color: c.onSurface),
      onPressed: () {
        try {
          Navigator.pushNamed(context, Routes.settings);
        } catch (e) {
          appLog.w('settings', 'could not open: ${e.runtimeType}');
        }
      },
    );
    if (!floating) return button;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tonesOf(context).s1,
        shape: BoxShape.circle,
        boxShadow: topBarShadow(context),
      ),
      child: button,
    );
  }
}
