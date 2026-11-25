import 'package:flutter/material.dart';

import 'app_log.dart';
import 'daily.dart';
import 'difficulty.dart';
import 'equations.dart';
import 'geography.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_filter.dart';
import 'modes.dart';
import 'stepper_choice.dart';
import 'store.dart' show Helper;
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

/// The modes the player has opened, in the swipe's order.
List<GameMode> openedModes() => [
  for (final m in GameMode.loopFor(appState.lang))
    if (isOpen(m, appState.level)) m,
];

/// The modes whose free play settings can be changed here: every opened mode.
List<GameMode> knownModes() => openedModes();

/// What the daily of [m] always uses, from the daily's own constants.
String dailySettingsOf(GameMode m) {
  switch (m) {
    case GameMode.equations:
      return '$equationDailyLength tiles, $equationDailyTries tries';
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

/// The open modes that share the letters and the length, as a sentence part:
/// "classic and quartet". It never names a locked mode.
String _sharers() {
  final names = [
    for (final m in openedModes())
      if (m == GameMode.classic || m.multi || m == GameMode.themed) m.label,
  ];
  if (names.length < 2) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const PageHeader(text: 'mode settings', back: true),
                Expanded(
                  child: ListenableBuilder(
                    listenable: appState,
                    builder: (context, _) {
                      final known = knownModes();
                      final opened = openedModes();
                      final mode = known.contains(_picked)
                          ? _picked!
                          : (known.isEmpty ? null : known.first);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          if (_showNote) ...[
                            _firstNote(c),
                            const SizedBox(height: 12),
                          ],
                          _daily(c, opened),
                          if (mode == null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 28, 2, 0),
                              child: Text(
                                'open a mode to change its settings here',
                                style: _note(c),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 28),
                            ModeFilter(
                              showAll: false,
                              modes: known,
                              selected: mode,
                              onSelect: (m) => setState(() => _picked = m),
                            ),
                            _settings(c, mode),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _firstNote(ColorScheme c) => TonalCard(
    key: const ValueKey('mode-settings-first-note'),
    color: c.secondaryContainer,
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
  );

  TextStyle _note(ColorScheme c) =>
      TextStyle(fontSize: 13, color: c.onSurface.withValues(alpha: dimAlpha));

  Widget _daily(ColorScheme c, List<GameMode> opened) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('these change free play only', first: true),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(
          'the daily is the same for everyone, and always uses:',
          style: _note(c),
        ),
      ),
      GroupedList(
        rows: [
          for (final m in opened)
            GroupRow(
              key: ValueKey('daily-row-${m.name}'),
              title: Text(m.label),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(dailySettingsOf(m), textAlign: TextAlign.right),
              ),
              chevron: false,
            ),
        ],
      ),
    ],
  );

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
    return Column(
      key: ValueKey('settings-${mode.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mode != GameMode.equations)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text(
              mode == GameMode.classic || mode.multi || mode == GameMode.themed
                  ? 'shared by ${_sharers()}'
                  : 'the word length is shared with the other modes',
              key: const ValueKey('shared-note'),
              style: TextStyle(
                fontSize: 13,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ),
        if (mode.multi) ...[
          const SectionLabel('shared letters'),
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
        ],
        if (mode == GameMode.mastermind) ...[
          const SectionLabel('pool choice'),
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
        ],
        if (lang != null) ...[
          const SectionLabel('difficulty'),
          _difficulty(mode, lang, length),
        ],
        if (!mode.endless && !mode.isEquations) ...[
          const SectionLabel('word draw'),
          StepperChoice<Draw>(
            key: ValueKey(
              mode == GameMode.themed ? 'draw-stepper-themed' : 'draw-stepper',
            ),
            semanticLabel: 'word draw',
            items: mode == GameMode.themed
                ? const [
                    (
                      Draw.sigmoid,
                      'well known',
                      'the best known places about equally likely',
                    ),
                    (Draw.equal, 'all places', 'every place equally likely'),
                  ]
                : [for (final d in Draw.values) (d, d.label, d.sub)],
            selected: mode == GameMode.themed && draw == Draw.frequency
                ? Draw.sigmoid
                : draw,
            onChanged: (d) => appState.setDrawOf(mode, d),
          ),
          SectionLabel(mode == GameMode.blind ? 'colour logic' : 'helper'),
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
                    items: [for (final h in Helper.values) (h, h.label, h.sub)],
                    selected: appState.helper,
                    onChanged: (h) => appState.setup(helper: h),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _difficulty(GameMode mode, Language lang, int length) {
    switch (mode) {
      case GameMode.equations:
        return DifficultyMatrix(
          key: const ValueKey('equations-matrix'),
          levels: equationTriesLevels,
          tries: appState.eqTries,
          length: appState.eqLength,
          lengths: equationLengths,
          lengthUnit: 'tiles',
          noun: 'equations',
          nounOne: 'equation',
          available: Equations.counts[appState.eqLength],
          onChanged: (t, n) => appState.setup(eqTries: t, eqLength: n),
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
