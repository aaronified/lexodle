import 'package:flutter/material.dart';

import 'app_log.dart';
import 'first_run/mode_lesson_page.dart';
import 'learn_log.dart';
import 'modes.dart';
import 'main.dart';
import 'routes.dart';
import 'ui.dart';
import 'words.dart';

/// The start of learn mode: the three things to do, each with how it has been
/// going in the language and length chosen, and the days in a row something was
/// learned. Free practice shows you the answer; the two drills hide it.
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
        final lang = bank.language.name.toLowerCase();
        final log = appState.learnLog;
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final streak = log.streak(today);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlagBadge(bank.language.flag, size: 16),
                const SizedBox(width: 8),
                // the graduation hat: this is learn
                TablerIcon(
                  'school',
                  size: headerIconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    mode == GameMode.classic
                        ? 'learn · $lang · $length'
                        : 'learn · ${mode.label}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
                  children: [
                    Caption(
                      'get better at the first guesses, and at seeing '
                      'which ${thingOf(mode, plural: false)} splits the rest best',
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        '$streak ${streak == 1 ? 'day' : 'days'} in a row',
                        key: const ValueKey('learn-streak'),
                        style: TextStyle(color: c.primary),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // how to play the mode in view well, for every mode
                    OutlinedButton(
                      key: const ValueKey('learn-card-guide'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        shape: const RoundedRectangleBorder(),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.learnGuide),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mode.label}: how to play it well',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'strategy for the mode you have selected',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.onSurface.withValues(alpha: dimAlpha),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _howToPlay(context, mode),
                    ...[
                      _lesson(
                        context,
                        'the opening',
                        'the best first guess, then the best second guess for '
                            'each colour it can show',
                        Routes.learnOpening,
                      ),
                      _lesson(
                        context,
                        'the styles',
                        'the three habits of the opening and the two of the end, '
                            'and luck, explained',
                        Routes.learnStyles,
                        key: 'learn-card-styles',
                      ),
                      _card(
                        context,
                        LearnKind.clue,
                        'read the clue',
                        'a guess and its clues, four ${thingOf(mode)}: which one fits',
                        Routes.learnClue,
                        log,
                      ),
                      _card(
                        context,
                        LearnKind.free,
                        'practise ${mode == GameMode.equations ? 'an equation' : 'a ${thingOf(mode, plural: false)}'}',
                        'the answer is shown. find the best guess at each step',
                        Routes.learnFree,
                        log,
                      ),
                      _card(
                        context,
                        LearnKind.choose,
                        'choose the best',
                        'ten positions, four ${thingOf(mode)} each: which splits the rest best',
                        Routes.learnChoose,
                        log,
                      ),
                      _card(
                        context,
                        LearnKind.closing,
                        'closing',
                        'ten endgames: few ${thingOf(mode)} left, few tries. which guess '
                            'wins in time',
                        Routes.learnClosing,
                        log,
                      ),
                      _card(
                        context,
                        LearnKind.sequence,
                        'three ${thingOf(mode)}',
                        'find three ${thingOf(mode)} to play first that tell the answers '
                            'apart best',
                        Routes.learnSequence,
                        log,
                      ),
                      _lesson(
                        context,
                        'my words',
                        'the words you saved from finished games, with their meanings and your notes',
                        Routes.words,
                        key: 'learn-card-words',
                      ),
                    ],
                  ],
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
  Widget _howToPlay(BuildContext context, GameMode mode) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        key: const ValueKey('learn-card-how-to-play'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          shape: const RoundedRectangleBorder(),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () {
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
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'how to play ${mode.label}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'the rules and the screen, as a short game',
                style: TextStyle(
                  fontSize: 11,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A lesson: something to read, so there is no progress to show.
  Widget _lesson(
    BuildContext context,
    String title,
    String about,
    String route, {
    String key = 'learn-card-opening',
  }) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        key: ValueKey(key),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          shape: const RoundedRectangleBorder(),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => Navigator.pushNamed(context, route),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(about, style: dim),
            ],
          ),
        ),
      ),
    );
  }

  /// One activity: its name, what it is, how it has been going, and a tap to
  /// start.
  Widget _card(
    BuildContext context,
    LearnKind kind,
    String title,
    String about,
    String route,
    LearnLog log,
  ) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
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
      progress = 'not tried yet at this length';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        key: ValueKey('learn-card-${kind.name}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          shape: const RoundedRectangleBorder(),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => Navigator.pushNamed(context, route),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(about, style: dim),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (trend.isNotEmpty) ...[
                    Text(
                      sparkline(trend),
                      key: ValueKey('learn-trend-${kind.name}'),
                      style: TextStyle(color: c.primary, letterSpacing: 1),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      progress,
                      key: ValueKey('learn-progress-${kind.name}'),
                      style: dim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
