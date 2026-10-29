import 'package:flutter/material.dart';

import 'daily.dart';
import 'difficulty.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'store.dart' show Helper;
import 'ui.dart';
import 'words.dart';

/// The game modes popup: mode, difficulty (tries and word length), how the word
/// is drawn, how often the words share
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
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
            final lang = langs?.firstWhere(
              (l) => l.code == appState.lang,
              orElse: () => langs.first,
            );
            final length = lang == null
                ? appState.length
                : lang.lengths.contains(appState.length)
                ? appState.length
                : lang.lengths.first;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // the close button sits 8 from the top and the right edge, so
                // the cross is as far from one as from the other (the body's
                // 24 side padding is not applied to it)
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
                  child: Row(
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
                        key: const ValueKey('modes-close'),
                        tooltip: 'close',
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 8),
                        Text(
                          'the daily of ${mode.label} always uses fixed '
                          'settings: five letters, '
                          '${mode.multi ? 'the words share no letter, ' : ''}'
                          '${dailyTriesOf(mode)} tries'
                          '${mode == GameMode.lockdown ? ', $dailyHearts hearts' : ''}.',
                          key: const ValueKey('daily-note'),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // right under the mode it belongs to. always there, so the
                        // popup keeps one shape; one word has nothing to share, so
                        // in classic it is greyed and fixed
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
                        if (lang != null) ...[
                          const SizedBox(height: 24),
                          const Caption('difficulty'),
                          const SizedBox(height: 10),
                          // lockdown is judged by its hearts, with its tries fixed
                          if (mode == GameMode.lockdown)
                            DifficultyMatrix(
                              key: const ValueKey('hearts-matrix'),
                              tries: appState.hearts,
                              levels: [
                                for (final (name, n) in lockdownHearts)
                                  (name, n),
                              ],
                              unit: ('heart', 'hearts'),
                              extra: '$lockdownTries tries, ',
                              length: length,
                              lengths: lang.lengths,
                              available: lang.counts[length],
                              onChanged: (h, n) =>
                                  appState.setup(hearts: h, length: n),
                            )
                          else
                            DifficultyMatrix(
                              tries: appState.tries,
                              length: length,
                              lengths: lang.lengths,
                              available: lang.counts[length],
                              onChanged: (t, n) =>
                                  appState.setup(tries: t, length: n),
                            ),
                        ],
                        const SizedBox(height: 24),
                        const Caption('word draw'),
                        const SizedBox(height: 10),
                        // how the answer is drawn, in a swipe: the sigmoid curve,
                        // every word equally, or by how common each word is
                        StepperChoice<Draw>(
                          key: const ValueKey('draw-stepper'),
                          semanticLabel: 'word draw',
                          items: [
                            for (final d in Draw.values) (d, d.label, d.sub),
                          ],
                          selected: appState.draw,
                          onChanged: (d) => appState.setup(draw: d),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          switch (appState.draw) {
                            Draw.sigmoid =>
                              'the commonest words are about equally likely, then '
                                  'fewer and fewer, and almost none past the 3,500th. '
                                  'the daily always draws this way.',
                            Draw.equal =>
                              'every word of the length is as likely as any other, '
                                  'rare ones too. the daily always draws by the '
                                  'curve.',
                            Draw.frequency =>
                              'common words come up far more often. the daily '
                                  'always draws by the curve.',
                          },
                          key: const ValueKey('draw-note'),
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
                                  for (final h in Helper.values)
                                    (h, h.label, h.sub),
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
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              Routes.learn,
                            ),
                            child: const Text('learn: find the best guess'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
