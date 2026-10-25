import 'package:flutter/material.dart';

import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'ui.dart';
import 'wiki_links.dart';

/// How to play, kept short: the rule, the colours, the blanks and the cursor,
/// and the one line of maths (skill + luck + daring = expected tries). Anyone
/// who wants more follows the link to the wiki.
///
/// On a first visit ([onboarding]) a "start playing" button is pinned under it,
/// which starts a default UK English game. Opened later from the footer it is
/// only a reference page, so it never overrides what the player has chosen.
class HowToPage extends StatelessWidget {
  const HowToPage({super.key, this.onboarding = false});
  final bool onboarding;

  /// The game the button starts: UK English, five letters, normal tries,
  /// classic. It replaces this page, so back from the game
  /// is the menu.
  static void startDefaultGame(BuildContext context) {
    appState.setup(lang: 'en', length: 5, tries: 6, mode: GameMode.classic);
    Navigator.pushReplacementNamed(context, Routes.play);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: .65),
    );

    /// A row of tiles: a letter, ' ' for a blank; [mark] colours the tile at
    /// [markAt], and [cursorAt] outlines the slot the next letter goes into.
    Widget tiles(
      String word, {
      int? markAt,
      Mark? mark,
      int? cursorAt,
      required String note,
      List<InlineSpan>? lead,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < word.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: MarkTile(
                    word[i],
                    size: 44,
                    mark: i == markAt ? mark : null,
                    cursor: i == cursorAt,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                ...?lead,
                TextSpan(text: note),
              ],
            ),
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );

    Widget colour(String word, int at, Mark mark, String note) => tiles(
      word,
      markAt: at,
      mark: mark,
      note: ' $note',
      lead: [
        TextSpan(
          text: word[at],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );

    Widget maths(String name, String what) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: TextStyle(fontWeight: FontWeight.bold, color: c.primary),
            ),
            TextSpan(text: ' $what'),
          ],
        ),
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    children: [
                      const Text(
                        'how to play',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'guess the word in as many tries as your difficulty '
                        'allows.',
                        style: TextStyle(fontSize: 16, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'every guess must be a real word of the right length.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      heading('the colours'),
                      colour(
                        'weary',
                        0,
                        Mark.correct,
                        'is in the word and in the correct spot.',
                      ),
                      colour(
                        'pills',
                        1,
                        Mark.present,
                        'is in the word but in the wrong spot.',
                      ),
                      colour(
                        'vague',
                        3,
                        Mark.absent,
                        'is not in the word in any spot.',
                      ),
                      Text(
                        'the examples are in english; every language plays the '
                        'same.',
                        style: dim,
                      ),
                      const SizedBox(height: 22),
                      heading('blanks and the cursor'),
                      tiles(
                        'a ode',
                        cursorAt: 1,
                        note:
                            'not sure of a letter? press space (or _) to leave '
                            'a blank. the outlined tile is the cursor: the next '
                            'letter goes there.',
                      ),
                      tiles(
                        'abode',
                        cursorAt: 2,
                        note:
                            'tap any tile to move the cursor. a blank cannot be '
                            'submitted.',
                      ),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 14),
                      heading('the maths'),
                      Text(
                        'skill + luck + daring = expected tries',
                        key: const ValueKey('maths-line'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      maths(
                        'skill',
                        'is how well your guesses narrowed the words.',
                      ),
                      maths('luck', 'is how kind the clues turned out to be.'),
                      maths(
                        'daring',
                        'is how much you went for the word itself.',
                      ),
                      const SizedBox(height: 4),
                      const WikiLink(
                        WikiPage.skillLuckDaring,
                        label: 'how skill, luck and daring work',
                      ),
                      const WikiLink(
                        WikiPage.howToPlay,
                        label: 'everything else, on the wiki',
                      ),
                    ],
                  ),
                ),
                if (onboarding)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: FilledButton(
                      onPressed: () => startDefaultGame(context),
                      child: const Text('start playing'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
