import 'package:flutter/material.dart';

import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'store.dart';
import 'ui.dart';

/// The settings popup, the same on a phone and on a desktop: game mode, how
/// often its words share letters, the helper level and the solver. Changes
/// apply and are saved as they are made. It is a route of its own
/// ([Routes.settings]), so it has an address like every other screen.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final mode = appState.mode;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Caption('mode'),
                  const SizedBox(height: 10),
                  StepperChoice<GameMode>(
                    semanticLabel: 'mode',
                    items: [
                      for (final m in GameMode.values)
                        (
                          m,
                          m.label,
                          m.extraTries == 0
                              ? m.sub
                              : '${m.sub} · +${m.extraTries} tries',
                        ),
                    ],
                    selected: mode,
                    onChanged: (m) => appState.setup(mode: m),
                  ),
                  if (mode.multi) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Caption('shared letters')),
                        Text(
                          '${appState.share}%',
                          key: const ValueKey('share-value'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('share-slider'),
                      value: appState.share.toDouble(),
                      min: 0,
                      max: maxShare.toDouble(),
                      divisions: maxShare,
                      label: '${appState.share}%',
                      onChanged: (v) => appState.setup(share: v.round()),
                    ),
                    Text(
                      appState.share == 0
                          ? 'the words never share a letter, as far as the '
                                'language allows.'
                          : 'the chance that the words share a letter. '
                                'lower makes them more different.',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.onSurface.withValues(alpha: dimAlpha),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Caption('helper'),
                  const SizedBox(height: 10),
                  StepperChoice<Helper>(
                    semanticLabel: 'helper',
                    items: [for (final h in Helper.values) (h, h.label, h.sub)],
                    selected: appState.helper,
                    onChanged: (h) => appState.setup(helper: h),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mode.multi
                        ? 'the helper shows in classic mode only. whatever you '
                              'choose, everything is revealed when the game ends.'
                        : 'whatever you choose, everything is revealed when '
                              'the game ends.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Caption('theme'),
                  const SizedBox(height: 10),
                  StepperChoice<ThemeMode>(
                    semanticLabel: 'theme',
                    items: const [
                      (ThemeMode.system, 'system', 'follow the device'),
                      (ThemeMode.light, 'light', 'a light page'),
                      (ThemeMode.dark, 'dark', 'a dark page'),
                    ],
                    selected: appState.themeMode,
                    onChanged: (t) => appState.setup(themeMode: t),
                  ),
                  const SizedBox(height: 24),
                  const Caption('solver'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    // replaces the popup, so back from the solver is home
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, Routes.solver),
                    child: const Text('open the solver'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
