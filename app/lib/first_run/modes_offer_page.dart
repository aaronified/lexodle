import 'package:flutter/material.dart';

import '../app_log.dart';

/// The one question asked right after the first game: learn about the
/// different modes? [onLearn] opens the tour, [onNotNow] goes on.
class ModesOfferPage extends StatelessWidget {
  const ModesOfferPage({
    super.key,
    required this.onLearn,
    required this.onNotNow,
  });

  final VoidCallback onLearn;
  final VoidCallback onNotNow;

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
                'that is the basics',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Text(
                'lexodle has eight modes. want to learn about the different ones?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('offer-yes'),
                  onPressed: () => _run(onLearn, 'modes_offer.yes'),
                  child: const Text('yes'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton.tonal(
                  key: const ValueKey('offer-not-now'),
                  onPressed: () => _run(onNotNow, 'modes_offer.not_now'),
                  child: const Text('not now'),
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
