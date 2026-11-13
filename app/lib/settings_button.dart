import 'package:flutter/material.dart';

import 'app_log.dart';
import 'routes.dart';
import 'ui.dart';

/// The settings button, top right of every tab and secondary page (the game
/// screens and the tutorials have their own corner buttons).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return IconButton(
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
  }
}
