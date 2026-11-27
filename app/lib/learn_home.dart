import 'package:flutter/material.dart';

import 'app_log.dart';
import 'first_run/mode_lesson_page.dart';
import 'ladder.dart';
import 'learn_log.dart';
import 'mode_filter.dart';
import 'modes.dart';
import 'main.dart';
import 'routes.dart';
import 'language_picker.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

/// The start of learn mode: the things to do, in two labelled groups (start
/// here, and train), each with how it has been going in the language and length
/// chosen, and the days in a row something was learned. Free practice shows you
/// the answer; the two drills hide it.
class LearnHomePage extends StatelessWidget {
  const LearnHomePage({super.key, required this.bank});
  final WordBank bank;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final c = Theme.of(context).colorScheme;
        final mode = appState.mode;
        final length = appState.learnLength;
        final log = appState.learnLog;
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final streak = log.streak(today);
        // before step 'learn' the page holds only how to play each open mode
        final full = appState.stepOpen('learn');
        // learn is four things for the modes with a board of one word to find:
        // the opening, how to play, how to master and a quiz
        final four = const {
          GameMode.classic,
          GameMode.blind,
          GameMode.mastermind,
        }.contains(mode);
        final modes = [
          for (final m in openModes(appState.level))
            if (GameMode.loopFor(appState.lang).contains(m)) m,
        ];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                // the language slider is the top bar; classic adds its length
                // to the line under it
                child: UnderTopBar(
                  bar: const TopBar(slider: LanguageBar(pill: true)),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topBarInset,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      if (full) ...[
                        Caption(
                          'get better at the first guesses, and at seeing '
                          'which ${thingOf(mode, plural: false)} splits the rest best'
                          '${mode == GameMode.classic ? ' · $length letters' : ''}',
                        ),
                        const SizedBox(height: 10),
                      ] else if (mode == GameMode.classic) ...[
                        Caption('$length letters'),
                        const SizedBox(height: 10),
                      ],
                      if (modes.length > 1)
                        ModeFilter(
                          key: const ValueKey('learn-modes'),
                          showAll: false,
                          selected: mode,
                          modes: modes,
                          onSelect: (m) {
                            if (m == null) return;
                            try {
                              appState.setup(mode: m);
                            } catch (e) {
                              appLog.w(
                                'learn',
                                'could not switch mode: ${e.runtimeType}',
                              );
                            }
                          },
                        ),
                      const SectionLabel('start here', first: true),
                      GroupedList(rows: [_howToPlay(context, mode)]),
                      if (full) ...[
                        const SectionLabel('train'),
                        GroupedList(
                          rows: [
                            // the master page for the modes with a board
                            // of one word, else the strategy guide
                            if (four)
                              _lesson(
                                context,
                                title: 'how to master ${mode.label}',
                                about:
                                    'play a word with every number to hand: '
                                    'the words that fit, the best guesses and '
                                    'the logic of each colour',
                                route: Routes.learnMaster,
                                key: 'learn-card-master',
                                icon: 'school',
                              )
                            else
                              _lesson(
                                context,
                                title: 'how to master ${mode.label}',
                                about:
                                    'strategy for the mode you have selected',
                                route: Routes.learnGuide,
                                key: 'learn-card-guide',
                                icon: 'school',
                              ),
                            _lesson(
                              context,
                              title: 'the opening',
                              about: four
                                  ? 'the best first guess, then the best '
                                        'second and third for any colours it '
                                        'can show'
                                  : 'the best first guess, then the best '
                                        'second guess for each colour it can '
                                        'show',
                              route: Routes.learnOpening,
                              key: 'learn-card-opening',
                              icon: 'bolt',
                            ),
                            if (four)
                              _lesson(
                                context,
                                title: 'guess the best',
                                about:
                                    'four guesses: which splits the rest best, '
                                    'or got the luckiest reply',
                                route: Routes.learnGuess,
                                key: 'learn-card-guess',
                                icon: 'bulb',
                              ),
                            if (!four) ...[
                              _lesson(
                                context,
                                title: 'the styles',
                                about:
                                    'the three habits of the opening and the '
                                    'two of the end, and luck, explained',
                                route: Routes.learnStyles,
                                key: 'learn-card-styles',
                                icon: 'sparkles',
                              ),
                              _card(
                                context,
                                LearnKind.clue,
                                'read the clue',
                                'a guess and its clues, four ${thingOf(mode)}: which one fits',
                                Routes.learnClue,
                                log,
                                'zoom-question',
                              ),
                              _card(
                                context,
                                LearnKind.free,
                                'practise ${mode == GameMode.equations ? 'an equation' : 'a ${thingOf(mode, plural: false)}'}',
                                mode == GameMode.mastermind
                                    ? 'the opponent answers as in the game. '
                                          'find the best split at each step'
                                    : 'the answer is shown. find the best '
                                          'guess at each step',
                                Routes.learnFree,
                                log,
                                'dice-5',
                              ),
                              _card(
                                context,
                                LearnKind.choose,
                                'choose the best',
                                'ten positions, four ${thingOf(mode)} each: which splits the rest best',
                                Routes.learnChoose,
                                log,
                                'scale',
                              ),
                              _card(
                                context,
                                LearnKind.closing,
                                'closing',
                                mode == GameMode.mastermind
                                    ? 'ten endgames: few words left. which '
                                          'guess splits them best'
                                    : 'ten endgames: few ${thingOf(mode)} left, '
                                          'few tries. which guess wins in time',
                                Routes.learnClosing,
                                log,
                                'shield-check',
                              ),
                              _card(
                                context,
                                LearnKind.sequence,
                                'three ${thingOf(mode)}',
                                'find three ${thingOf(mode)} to play first that '
                                    'tell the answers apart best',
                                Routes.learnSequence,
                                log,
                                'square-number-3',
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (full && streak > 0) ...[
                        const SizedBox(height: 12),
                        TonalCard(
                          child: Text(
                            '$streak ${streak == 1 ? 'day' : 'days'} in a row',
                            key: const ValueKey('learn-streak'),
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The row that opens the lesson of [mode]: its rules and its screen, as a
  /// short game.
  GroupRow _howToPlay(BuildContext context, GameMode mode) {
    return GroupRow(
      key: const ValueKey('learn-card-how-to-play'),
      leading: const TonalTile('puzzle'),
      title: Text('how to play ${mode.label}'),
      subtitle: const Text('the rules and the screen, as a short game'),
      onTap: () {
        try {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (ctx) => ModeLessonPage(
                mode: mode,
                onDone: () {
                  try {
                    Navigator.of(ctx).pop();
                  } catch (e) {
                    appLog.w(
                      'learn',
                      'could not leave the lesson: ${e.runtimeType}',
                    );
                  }
                },
              ),
            ),
          );
        } catch (e) {
          appLog.w('learn', 'could not open the lesson: ${e.runtimeType}');
        }
      },
    );
  }

  /// A lesson: something to read, so there is no progress to show.
  GroupRow _lesson(
    BuildContext context, {
    required String title,
    required String about,
    required String route,
    required String key,
    required String icon,
  }) {
    return GroupRow(
      key: ValueKey(key),
      leading: TonalTile(icon),
      title: Text(title),
      subtitle: Text(about),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }

  /// One activity: its name, what it is, and how it has been going (or 'new')
  /// at the trailing edge, with a tap to start.
  GroupRow _card(
    BuildContext context,
    LearnKind kind,
    String title,
    String about,
    String route,
    LearnLog log,
    String icon,
  ) {
    final c = Theme.of(context).colorScheme;
    final mine = log.where(
      kind: kind,
      language: bank.language.code,
      length: appState.learnLength,
      mode: appState.mode,
    );
    final trend = log.recentSkill(
      12,
      kind: kind,
      language: bank.language.code,
      length: appState.learnLength,
      mode: appState.mode,
    );
    final String progress;
    if (mine.isEmpty) {
      progress = 'new';
    } else {
      final last = mine.last;
      final what = switch (kind) {
        LearnKind.free =>
          'last ${thingOf(appState.mode, plural: false)}: ${last.right} of ${last.questions} guesses the best',
        LearnKind.sequence => 'last set',
        _ => 'last round: ${last.right} of ${last.questions} right',
      };
      progress = '$what · skill ${last.avgSkill.round()}';
    }
    return GroupRow(
      key: ValueKey('learn-card-${kind.name}'),
      leading: TonalTile(icon),
      title: Text(title),
      subtitle: Text(about),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trend.isNotEmpty)
              Text(
                sparkline(trend),
                key: ValueKey('learn-trend-${kind.name}'),
                style: TextStyle(color: c.primary, letterSpacing: 1),
              ),
            Text(
              progress,
              key: ValueKey('learn-progress-${kind.name}'),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
