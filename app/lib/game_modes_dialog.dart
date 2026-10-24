import 'package:flutter/material.dart';

import 'difficulty.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'ui.dart';
import 'words.dart';

/// A word on each length, the second tier of the letters slider.
const _lengthNote = {
  4: 'short and quick',
  5: 'the classic',
  6: 'a step up',
  7: 'long',
  8: 'very long',
};

/// The game modes popup: mode, letters, difficulty, how often the words share
/// letters, the helper level, and play, the solver and learn. Changes apply and
/// are saved as they are made. It is a route of its own ([Routes.gameModes]).
class GameModesDialog extends StatefulWidget {
  const GameModesDialog({super.key});

  @override
  State<GameModesDialog> createState() => _GameModesDialogState();
}

class _GameModesDialogState extends State<GameModesDialog> {
  // the list is cached once read, so it is usually there at once
  List<Language>? _langs = WordBank.loadedLanguages;

  @override
  void initState() {
    super.initState();
    if (_langs == null) {
      WordBank.languages().then((l) {
        if (mounted) setState(() => _langs = l);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final langs = _langs;
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
            final lang = langs == null
                ? null
                : langs.firstWhere(
                    (l) => l.code == appState.lang,
                    orElse: () => langs.first,
                  );
            final length = lang == null
                ? appState.length
                : lang.lengths.contains(appState.length)
                ? appState.length
                : lang.lengths.first;
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
                          'game modes',
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
                  if (lang != null) ...[
                    const SizedBox(height: 24),
                    const Caption('letters'),
                    const SizedBox(height: 10),
                    StepperChoice<int>(
                      semanticLabel: 'letters',
                      items: [
                        for (final n in lang.lengths)
                          (n, '$n letters', _lengthNote[n]),
                      ],
                      selected: length,
                      onChanged: (n) => appState.setup(length: n),
                    ),
                    const SizedBox(height: 24),
                    const Caption('difficulty'),
                    const SizedBox(height: 10),
                    DifficultyMatrix(
                      tries: appState.tries,
                      pool: effectivePool(appState.pool, lang.counts[length]),
                      available: lang.counts[length],
                      onChanged: (t, pl) => appState.setup(tries: t, pool: pl),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // always there, so the popup keeps one shape; one word has
                  // nothing to share, so in classic it is greyed and fixed
                  Row(
                    children: [
                      const Expanded(child: Caption('shared letters')),
                      Text(
                        '${appState.share}%',
                        key: const ValueKey('share-value'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: mode.multi
                              ? c.primary
                              : c.onSurface.withValues(alpha: dimAlpha),
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
                    onChanged: mode.multi
                        ? (v) => appState.setup(share: v.round())
                        : null,
                  ),
                  Text(
                    !mode.multi
                        ? 'one word has nothing to share. this applies to '
                              'quartet and relay race.'
                        : appState.share == 0
                        ? 'the words never share a letter, as far as the '
                              'language allows.'
                        : 'the chance that the words share a letter. '
                              'lower makes them more different.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Caption('helper'),
                  const SizedBox(height: 10),
                  // the helper only shows in classic, so for the other modes
                  // it is greyed: dimmed, and out of reach of touch and keys
                  Opacity(
                    key: const ValueKey('helper-fade'),
                    opacity: mode.multi ? .38 : 1,
                    child: AbsorbPointer(
                      absorbing: mode.multi,
                      child: ExcludeFocus(
                        excluding: mode.multi,
                        child: StepperChoice<Helper>(
                          semanticLabel: 'helper',
                          items: [
                            for (final h in Helper.values) (h, h.label, h.sub),
                          ],
                          selected: appState.helper,
                          onChanged: (h) => appState.setup(helper: h),
                        ),
                      ),
                    ),
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
                  const Caption('play or solve'),
                  const SizedBox(height: 10),
                  // all replace the popup, so back from any is home
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('settings-play'),
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            Routes.play,
                          ),
                          child: const Text('play'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            Routes.solver,
                          ),
                          child: const Text('open the solver'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('settings-learn'),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, Routes.learn),
                      child: const Text('learn: find the best guess'),
                    ),
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
