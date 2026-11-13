import 'package:flutter/material.dart';

import 'app_log.dart';
import 'daily.dart';
import 'difficulty.dart';
import 'equations.dart';
import 'geography.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_wheel.dart';
import 'modes.dart';
import 'stepper_choice.dart';
import 'store.dart' show Helper;
import 'ui.dart';
import 'words.dart';

/// Plays of a mode after which it is "known" and its settings can be changed
/// here.
const modeSettingsPlays = 3;

/// The modes the player has opened, in the swipe's order.
List<GameMode> openedModes() {
  final vet = appState.lex.veteran;
  return [
    for (final m in GameMode.loopFor(appState.lang))
      if (isOpen(m, appState.stats.played, veteran: vet)) m,
  ];
}

/// The modes whose free play settings can be changed here: open, and played
/// [modeSettingsPlays] times (a veteran: open is enough).
List<GameMode> knownModes() {
  final vet = appState.lex.veteran;
  var counts = const <GameMode, int>{};
  try {
    counts = {
      for (final m in GameMode.values)
        m: appState.history.games.where((g) => g.mode == m).length,
    };
  } catch (e) {
    appLog.w('modeset', 'could not count the plays ${e.runtimeType}');
  }
  return [
    for (final m in openedModes())
      if (vet || (counts[m] ?? 0) >= modeSettingsPlays) m,
  ];
}

/// What the daily of [m] always uses, from the daily's own constants.
String dailySettingsOf(GameMode m) {
  switch (m) {
    case GameMode.equations:
      return '$equationDailyLength tiles, $equationDailyTries tries';
    case GameMode.mastermind:
      return '$dailyLength letters, no limit';
    case GameMode.lockdown:
      return '$dailyLength letters, $lockdownTries tries, $dailyHearts hearts';
    case GameMode.quartet:
    case GameMode.relay:
      return '$dailyLength letters, ${dailyTriesOf(m)} tries, '
          '$dailyShare% shared';
    default:
      return '$dailyLength letters, ${dailyTriesOf(m)} tries';
  }
}

/// Free play settings of one mode at a time, chosen by a row of pills. It edits
/// the chosen mode without making it the mode in view. The tries, length,
/// helper and shared letters are one setting for the app, so a change shows in
/// every mode that uses it.
class ModeSettingsPage extends StatefulWidget {
  const ModeSettingsPage({super.key});

  @override
  State<ModeSettingsPage> createState() => _ModeSettingsPageState();
}

class _ModeSettingsPageState extends State<ModeSettingsPage> {
  List<Language>? _langs = WordBank.loadedLanguages;
  GameMode? _picked;

  /// The one-time line at the top: shown the first time this page opens.
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    try {
      _showNote = !appState.modeSettingsNoteSeen;
      appState.markModeSettingsNoteSeen();
    } catch (e) {
      appLog.w('modeset', 'could not read the note ${e.runtimeType}');
    }
    if (_langs == null) {
      try {
        WordBank.languages().then(
          (l) {
            if (mounted) setState(() => _langs = l);
          },
          onError: (Object e) => appLog.w(
            'modeset',
            'could not load the languages ${e.runtimeType}',
          ),
        );
      } catch (e) {
        appLog.w('modeset', 'could not load the languages ${e.runtimeType}');
      }
    }
  }

  static bool _noHelper(GameMode m) =>
      m.multi || m == GameMode.blind || m == GameMode.themed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('mode settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                final known = knownModes();
                final opened = openedModes();
                final mode = known.contains(_picked)
                    ? _picked!
                    : (known.isEmpty ? null : known.first);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
                  children: [
                    if (_showNote) ...[
                      _firstNote(c),
                      const SizedBox(height: 12),
                    ],
                    _card(c, opened),
                    const SizedBox(height: 12),
                    if (mode == null)
                      Text(
                        'play a mode $modeSettingsPlays times to change its '
                        'settings here',
                        style: _note(c),
                      )
                    else ...[
                      _pills(c, known, mode),
                      const SizedBox(height: 12),
                      _settings(c, mode),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _firstNote(ColorScheme c) => Material(
    key: const ValueKey('mode-settings-first-note'),
    color: c.secondaryContainer,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'these change free play only: the daily never changes',
              style: TextStyle(fontSize: 13, color: c.onSecondaryContainer),
            ),
          ),
          IconButton(
            key: const ValueKey('mode-settings-note-close'),
            tooltip: 'dismiss',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => setState(() => _showNote = false),
            icon: Icon(Icons.close, size: 18, color: c.onSecondaryContainer),
          ),
        ],
      ),
    ),
  );

  TextStyle _note(ColorScheme c) =>
      TextStyle(fontSize: 11, color: c.onSurface.withValues(alpha: dimAlpha));

  Widget _card(ColorScheme c, List<GameMode> opened) {
    return Material(
      color: c.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: hairline(c),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('these change free play only'),
            const SizedBox(height: 4),
            Text(
              'the daily is the same for everyone, and always uses:',
              style: _note(c),
            ),
            const SizedBox(height: 8),
            for (final m in opened)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  key: ValueKey('daily-row-${m.name}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(m.label)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dailySettingsOf(m),
                        textAlign: TextAlign.right,
                        style: _note(c),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pills(ColorScheme c, List<GameMode> known, GameMode mode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in known)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: m == mode
                    ? c.secondaryContainer
                    : c.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  key: ValueKey('pill-${m.name}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _picked = m),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TablerIcon(
                            modeIconName(m),
                            size: 18,
                            color: m == mode
                                ? c.onSecondaryContainer
                                : c.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontWeight: m == mode ? FontWeight.bold : null,
                              color: m == mode
                                  ? c.onSecondaryContainer
                                  : c.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settings(ColorScheme c, GameMode mode) {
    final langs = _langs;
    final lang = langs?.firstWhere(
      (l) => l.code == appState.lang,
      orElse: () => langs.first,
    );
    final length = lang == null
        ? appState.length
        : lang.lengths.contains(appState.length)
        ? appState.length
        : lang.lengths.first;
    final draw = appState.drawOf(mode);
    return Material(
      color: c.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: hairline(c),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          key: ValueKey('settings-${mode.name}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mode != GameMode.equations)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  mode == GameMode.classic ||
                          mode.multi ||
                          mode == GameMode.themed
                      ? 'shared by classic, quartet, relay and geography'
                      : 'the word length is shared with the other modes',
                  key: const ValueKey('shared-note'),
                  style: _note(c),
                ),
              ),
            if (mode.multi) ...[
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
                      p == 0
                          ? 'the words never share a letter'
                          : 'the chance that the words share a letter',
                    ),
                ],
                selected: (appState.share / 5).round() * 5,
                onChanged: (p) => appState.setup(share: p),
              ),
              const SizedBox(height: 24),
            ],
            if (mode == GameMode.mastermind) ...[
              const Caption('pool choice'),
              const SizedBox(height: 10),
              StepperChoice<bool>(
                key: const ValueKey('largest-choice'),
                semanticLabel: 'pool choice',
                items: const [
                  (false, 'random', 'bigger pools are likelier'),
                  (true, 'largest', 'always the biggest pool'),
                ],
                selected: appState.mastermindLargest,
                onChanged: (on) => appState.setup(mastermindLargest: on),
              ),
              const SizedBox(height: 24),
            ],
            if (lang != null) ...[
              const Caption('difficulty'),
              const SizedBox(height: 10),
              _difficulty(mode, lang, length),
            ],
            if (!mode.endless && !mode.isEquations) ...[
              const SizedBox(height: 24),
              const Caption('word draw'),
              const SizedBox(height: 10),
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
                    : [for (final d in Draw.values) (d, d.label, d.sub)],
                selected: mode == GameMode.themed && draw == Draw.frequency
                    ? Draw.sigmoid
                    : draw,
                onChanged: (d) => appState.setDrawOf(mode, d),
              ),
              const SizedBox(height: 24),
              Caption(mode == GameMode.blind ? 'colour logic' : 'helper'),
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
                // the helper only shows in classic, so for the other modes it
                // is greyed out and out of reach, as in the game modes popup
                Opacity(
                  key: const ValueKey('helper-fade'),
                  opacity: _noHelper(mode) ? .38 : 1,
                  child: AbsorbPointer(
                    absorbing: _noHelper(mode),
                    child: ExcludeFocus(
                      excluding: _noHelper(mode),
                      child: StepperChoice<Helper>(
                        key: const ValueKey('helper-stepper'),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _difficulty(GameMode mode, Language lang, int length) {
    switch (mode) {
      case GameMode.equations:
        return DifficultyMatrix(
          key: const ValueKey('equations-matrix'),
          levels: equationTriesLevels,
          tries: appState.tries,
          length: appState.eqLength,
          lengths: equationLengths,
          lengthUnit: 'tiles',
          noun: 'equations',
          nounOne: 'equation',
          available: Equations.counts[appState.eqLength],
          onChanged: (t, n) => appState.setup(tries: t, eqLength: n),
        );
      case GameMode.mastermind:
        return DifficultyMatrix(
          key: const ValueKey('mastermind-matrix'),
          tries: 0,
          levels: const [('endless', 0)],
          length: length,
          lengths: lang.lengths,
          available: lang.counts[length],
          onChanged: (_, n) => appState.setup(length: n),
        );
      case GameMode.blind:
        return DifficultyMatrix(
          key: const ValueKey('blind-matrix'),
          tries: appState.blindTries,
          levels: blindTriesLevels,
          length: length,
          lengths: lang.lengths,
          available: lang.counts[length],
          onChanged: (t, n) => appState.setup(blindTries: t, length: n),
        );
      case GameMode.lockdown:
        return DifficultyMatrix(
          key: const ValueKey('hearts-matrix'),
          tries: appState.hearts,
          levels: [for (final (name, n) in lockdownHearts) (name, n)],
          unit: ('heart', 'hearts'),
          extra: '$lockdownTries tries, ',
          length: length,
          lengths: lang.lengths,
          available: lang.counts[length],
          onChanged: (h, n) => appState.setup(hearts: h, length: n),
        );
      default:
        final themed = mode == GameMode.themed;
        return DifficultyMatrix(
          tries: appState.tries,
          length: length,
          lengths: themed
              ? [
                  for (final n in lang.lengths)
                    if (Geography.counts.isEmpty ||
                        Geography.counts.containsKey(n))
                      n,
                ]
              : lang.lengths,
          noun: themed ? 'place names' : 'words',
          nounOne: themed ? 'place name' : 'word',
          available: themed ? Geography.counts[length] : lang.counts[length],
          onChanged: (t, n) => appState.setup(tries: t, length: n),
        );
    }
  }
}
