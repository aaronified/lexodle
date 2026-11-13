import 'package:flutter/material.dart';

import '../app_log.dart';
import '../ui.dart';

/// Tells the player where the first game lives now: the you tab, the help
/// icon at the top right. Shown after the first game and after any mode
/// lesson, whichever way it is left. No bottom tab bar.
class GatewayPage extends StatelessWidget {
  const GatewayPage({super.key, required this.onOkay, required this.onReplay});

  final VoidCallback onOkay;
  final VoidCallback onReplay;

  void _run(VoidCallback f, String tag) {
    try {
      f();
    } catch (e) {
      appLog.w(tag, '${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'play it again any time',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Text(
                'open you, then tap the help icon at the top right.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                key: const ValueKey('gateway-hint'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Text(
                      'you',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TablerIcon('info-circle', size: 26, color: c.primary),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('gateway-okay'),
                  onPressed: () => _run(onOkay, 'gateway.okay'),
                  child: const Text('okay'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton.tonal(
                  key: const ValueKey('gateway-replay'),
                  onPressed: () => _run(onReplay, 'gateway.replay'),
                  child: const Text('replay'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
