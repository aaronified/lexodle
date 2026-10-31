import 'package:flutter/material.dart';

import 'daily.dart';
import 'difficulty.dart';
import 'geography.dart';
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

  /// The theme being looked at, and the mythology. Only geography can be played.
  String _theme = 'geography';
  String _myth = 'greek';

  @override
  void initState() {
    super.initState();
    if (_langs == null) {
      WordBank.languages().then((l) {
        if (mounted) setState(() => _langs = l);
      });
    }
    // the places are counted once read, for the difficulty's summary
    if (Geography.counts.isEmpty) {
      WordBank.languages()
          .then((l) => Geography.load(l.firstWhere((x) => x.code == 'en')))
          .then((_) {
            if (mounted) setState(() {});
          }, onError: (_) {});
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
                              if (m != GameMode.themed || appState.lang == 'en')
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
                          !mode.hasDaily
                              ? 'no daily in this mode. themed wordles accept only '
                                    'the words of the theme, in english: no ordinary words.'
                              : 'the daily of ${mode.label} always uses fixed '
                                    'settings: five letters, '
                                    '${mode.multi ? 'the words may share a letter (10% chance), ' : ''}'
                                    '${dailyTriesOf(mode)} tries'
                                    '${mode == GameMode.lockdown ? ', $dailyHearts hearts' : ''}.',
                          key: const ValueKey('daily-note'),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                        ),
                        if (mode == GameMode.themed) ..._themedChoices(c),
                        // only the modes with several words have words that can
                        // share letters
                        if (mode.multi) ...[
                          const SizedBox(height: 16),
                          const Caption('shared letters'),
                          const SizedBox(height: 10),
                          StepperChoice<int>(
                            key: const ValueKey('share-stepper'),
                            semanticLabel: 'shared letters',
                            items: [
                              for (var p = 0; p <= maxShare; p += 5)
                                (
                                  p,
                                  '$p%',
                                  p == 0 ? 'the words never share a letter' : 'the chance that the words share a letter',
                                ),
                            ],
                            selected: (appState.share / 5).round() * 5,
                            onChanged: (p) => appState.setup(share: p),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            appState.share == 0
                                ? 'the words never share a letter, as far as the '
                                      'language allows.'
                                : 'the chance that the words share a letter. '
                                      'lower makes them more different.',
                            key: const ValueKey('share-note'),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurface.withValues(alpha: dimAlpha),
                            ),
                          ),
                        ],
                        if (lang != null) ...[
                          const SizedBox(height: 24),
                          const Caption('difficulty'),
                          const SizedBox(height: 10),
                          // lockdown is judged by its hearts, with its tries fixed
                          if (mode == GameMode.blind)
                            DifficultyMatrix(
                              key: const ValueKey('blind-matrix'),
                              tries: appState.blindTries,
                              levels: blindTriesLevels,
                              length: length,
                              lengths: lang.lengths,
                              available: lang.counts[length],
                              onChanged: (t, n) =>
                                  appState.setup(blindTries: t, length: n),
                            )
                          else if (mode == GameMode.lockdown)
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
                              lengths: mode == GameMode.themed
                                  ? [
                                      for (final n in lang.lengths)
                                        if (Geography.counts.isEmpty ||
                                            Geography.counts.containsKey(n))
                                          n,
                                    ]
                                  : lang.lengths,
                              noun: mode == GameMode.themed
                                  ? 'place names'
                                  : 'words',
                              nounOne: mode == GameMode.themed
                                  ? 'place name'
                                  : 'word',
                              available: mode == GameMode.themed
                                  ? Geography.counts[length]
                                  : lang.counts[length],
                              onChanged: (t, n) =>
                                  appState.setup(tries: t, length: n),
                            ),
                        ],
                        const SizedBox(height: 24),
                        const Caption('word draw'),
                        const SizedBox(height: 10),
                        // how the answer is drawn, in a swipe: the sigmoid curve,
                        // every word equally, or by how common each word is. In
                        // themed it is the same swiper with the places' values
                        StepperChoice<Draw>(
                          key: ValueKey(
                            mode == GameMode.themed
                                ? 'draw-stepper-themed'
                                : 'draw-stepper',
                          ),
                          semanticLabel: 'word draw',
                          items: mode == GameMode.themed
                              ? const [
                                  (
                                    Draw.sigmoid,
                                    'well known',
                                    'the best known places about equally likely',
                                  ),
                                  (
                                    Draw.equal,
                                    'all places',
                                    'every place equally likely',
                                  ),
                                ]
                              : [
                                  for (final d in Draw.values)
                                    (d, d.label, d.sub),
                                ],
                          selected:
                              mode == GameMode.themed &&
                                  appState.draw == Draw.frequency
                              ? Draw.sigmoid
                              : appState.draw,
                          onChanged: (d) => appState.setup(draw: d),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mode == GameMode.themed
                              ? (appState.draw == Draw.equal
                                    ? 'any place of the database can be the answer, '
                                          'small cities and minor rivers too.'
                                    : 'the answer is a place most people know. any '
                                          'place of the database is still a valid '
                                          'guess.')
                              : switch (appState.draw) {
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
                        Caption(
                          mode == GameMode.blind ? 'colour logic' : 'helper',
                        ),
                        const SizedBox(height: 10),
                        if (mode == GameMode.blind)
                          StepperChoice<bool>(
                            key: const ValueKey('assist-choice'),
                            semanticLabel: 'colour logic',
                            items: const [
                              (true, 'on', 'marks what the counts settle'),
                              (false, 'off', 'you mark everything'),
                            ],
                            selected: appState.blindAssist,
                            onChanged: (on) => appState.setup(blindAssist: on),
                          )
                        else
                          // the helper only shows in classic, so for the other modes
                          // it is greyed: dimmed, and out of reach of touch and keys
                          Opacity(
                            key: const ValueKey('helper-fade'),
                            opacity: _noHelper(mode) ? .38 : 1,
                            child: AbsorbPointer(
                              absorbing: _noHelper(mode),
                              child: ExcludeFocus(
                                excluding: _noHelper(mode),
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
                          mode == GameMode.blind
                              ? (appState.blindAssist
                                    ? 'the obvious is marked for you, on the keyboard and '
                                          'the guesses, and you can only pencil colours that '
                                          'can be true. everything is revealed when the game '
                                          'ends.'
                                    : 'nothing is marked for you and you can pencil any '
                                          'colour on any letter. everything is revealed when '
                                          'the game ends.')
                              : mode == GameMode.themed
                              ? 'the helper shows in classic and lockdown only. '
                                    'everything is revealed when the game ends.'
                              : mode.multi
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
                                onPressed:
                                    mode == GameMode.themed &&
                                        _theme != 'geography'
                                    ? null
                                    : () => Navigator.pushReplacementNamed(
                                        context,
                                        Routes.play,
                                      ),
                                child: const Text('play'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _themedOrBlind(mode)
                                    ? null
                                    : () => Navigator.pushReplacementNamed(
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
                            onPressed: _themedOrBlind(mode)
                                ? null
                                : () => Navigator.pushReplacementNamed(
                                    context,
                                    Routes.learn,
                                  ),
                            child: const Text('learn: find the best guess'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('settings-diy'),
                            icon: TablerIcon(
                              'gift',
                              size: 18,
                              color: c.primary,
                            ),
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              Routes.diy,
                            ),
                            label: const Text('diy: make a wordle of your own'),
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

  static bool _themedOrBlind(GameMode m) =>
      m == GameMode.blind || m == GameMode.themed;

  static bool _noHelper(GameMode m) =>
      m.multi || m == GameMode.blind || m == GameMode.themed;

  /// The theme (and, for mythology, which one): swipers like the mode's. The
  /// themes still to come can be looked at, and cannot be played yet.
  List<Widget> _themedChoices(ColorScheme c) {
    final note = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return [
      const SizedBox(height: 14),
      const Caption('theme'),
      const SizedBox(height: 10),
      StepperChoice<String>(
        key: const ValueKey('theme-stepper'),
        semanticLabel: 'theme',
        items: [
          (
            'geography',
            'geography',
            'place names across the world, in english',
          ),
          for (final t in const ['mathematics', 'history', 'mythology'])
            (t, t, 'upcoming feature'),
        ],
        selected: _theme,
        onChanged: (t) => setState(() => _theme = t),
      ),
      const SizedBox(height: 8),
      Text(
        _theme == 'geography'
            ? 'countries, cities, rivers, mountains, lakes, bays. every guess has '
                  'an info dot that tells about the word.'
            : 'upcoming feature: this theme cannot be played yet.',
        key: const ValueKey('theme-note'),
        style: note,
      ),
      if (_theme == 'mythology') ...[
        const SizedBox(height: 14),
        const Caption('mythology'),
        const SizedBox(height: 10),
        StepperChoice<String>(
          key: const ValueKey('mythology-stepper'),
          semanticLabel: 'mythology',
          items: [
            for (final t in const [
              'greek',
              'egyptian',
              'chinese',
              'japanese',
              'indian',
            ])
              (t, t, 'upcoming feature'),
          ],
          selected: _myth,
          onChanged: (t) => setState(() => _myth = t),
        ),
      ],
    ];
  }
}
