import 'package:flutter/material.dart';

import 'logic.dart';
import 'store.dart';
import 'ui.dart';

/// How to play, in the manner of the NYT's: the rule, then three worked
/// examples with tiles, then the parts of this game that are its own.
class HowToPage extends StatelessWidget {
  const HowToPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: .65),
    );

    Widget bullet(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(t, style: const TextStyle(height: 1.45))),
        ],
      ),
    );

    Widget example(String word, int at, Mark mark, String note) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
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
                    mark: i == at ? mark : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: word[at],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' $note'),
              ],
            ),
          ),
        ],
      ),
    );

    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption(title),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                const Text(
                  'how to play',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'guess the word in as many tries as your difficulty '
                  'allows.',
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 20),
                bullet(
                  'each guess must be a valid word, of the length and in '
                  'the language you chose.',
                ),
                bullet(
                  'the colour of the tiles shows how close your guess was '
                  'to the word.',
                ),
                const SizedBox(height: 14),
                const Text(
                  'examples',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                example(
                  'weary',
                  0,
                  Mark.correct,
                  'is in the word and in the correct spot.',
                ),
                example(
                  'pills',
                  1,
                  Mark.present,
                  'is in the word but in the wrong spot.',
                ),
                example(
                  'vague',
                  3,
                  Mark.absent,
                  'is not in the word in any spot.',
                ),
                Text(
                  'the examples are in english; every language plays the same.',
                  style: dim,
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 18),
                section(
                  'setup',
                  'choose a language, 4 to 8 letters (slide or tap the arrows) and a difficulty from the '
                      '4 x 4 grid. across is the number of tries: easy 8, normal '
                      '6, hard 4, brutal 3. down is the word pool the answer is '
                      'drawn from: its 500, 1,500, 3,000 or 6,000 most common '
                      'words (fewer where a language has fewer). the colour runs '
                      'from green for the easiest to purple for the hardest.',
                ),
                section(
                  'skill and luck',
                  'skill says how well a guess narrowed the words still '
                      'possible: 100 is the best split available, 0 tells you '
                      'nothing. luck says how much smaller (+, green) or larger '
                      '(-, red) than average the pool you landed in was; 0% is '
                      'exactly average. the helper setting decides how much of '
                      'this you see while you play. when the game ends you see '
                      'all of it.',
                ),
                section(
                  'review',
                  'after a game, review walks through your guesses one by one: '
                      'how each guess divided the possible words, the pool you '
                      'landed in against the average pool, and the best picks at '
                      'that point.',
                ),
                section(
                  'solver',
                  'playing somewhere else? the solver narrows the words that '
                      'fit the guesses you tell it about, and suggests the next '
                      'one.',
                ),
                section(
                  'achievements',
                  '${achievements.length} to collect. they are kept in this browser only.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
