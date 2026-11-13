import 'package:flutter/material.dart';

import 'app_log.dart';
import 'daily.dart';
import 'main.dart';
import 'modes.dart';
import 'ui.dart';

/// The line about the tries (or hearts) of a daily in [mode], true for each
/// mode from the daily's own rules.
String dailyIntroTries(GameMode mode) {
  switch (mode) {
    case GameMode.mastermind:
      return 'no limit on guesses.';
    case GameMode.lockdown:
      return '$lockdownTries tries and $dailyHearts hearts.';
    default:
      return '${dailyTriesOf(mode)} tries.';
  }
}

/// Shows the one-time introduction the first time any daily is opened, then
/// never again. Does nothing for a player who has seen it. Typing is never
/// blocked: it is a sheet, dismissed by "got it" or a tap outside. [onClosed]
/// runs when it is gone (to hand the keyboard back to the game).
Future<void> maybeShowDailyIntro(
  BuildContext context,
  GameMode mode, {
  VoidCallback? onClosed,
}) async {
  try {
    if (appState.dailyIntroSeen || !context.mounted) return;
    appState.markDailyIntroSeen();
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _DailyIntro(mode: mode),
    );
    onClosed?.call();
  } catch (e) {
    appLog.w('daily', 'could not show the intro: ${e.runtimeType}');
  }
}

class _DailyIntro extends StatelessWidget {
  const _DailyIntro({required this.mode});
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lines = [
      'one word a day, the same for everyone.',
      'it changes at midnight in india (IST).',
      dailyIntroTries(mode),
      'it is logged: it counts for your streak and your history.',
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(19, 16, 19, 16),
        child: Column(
          key: const ValueKey('daily-intro'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'your first daily',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'just want to practise? use free play on today instead.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('daily-intro-ok'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('got it'),
            ),
          ],
        ),
      ),
    );
  }
}
