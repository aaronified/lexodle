import 'package:flutter/material.dart';

import 'modes.dart';
import 'ui.dart';

/// Whether the word drills of learn (the opening, practice, choose the best,
/// closing, three words) fit [mode]: they teach single words with the usual
/// colours, so they fit the modes that play like that. The rest have the guide.
bool learnDrillsFit(GameMode mode) => switch (mode) {
  GameMode.classic ||
  GameMode.quartet ||
  GameMode.relay ||
  GameMode.lockdown ||
  GameMode.mastermind => true,
  GameMode.blind || GameMode.equations || GameMode.themed => false,
};

/// The strategy guide of [mode]: headed paragraphs on how to play it well.
List<(String, String)> modeGuide(GameMode mode) => switch (mode) {
  GameMode.classic => const [
    (
      'the first guesses',
      'open with a word of common, different letters: the first guesses are '
          'for finding which letters are in, not for winning. a letter you '
          'have not tried tells you more than one you have.',
    ),
    (
      'the middle',
      'play the word that splits the words left best, not the one that merely '
          'fits. when several words differ in one letter (_atch), a word that '
          'tests several of those letters at once beats guessing one by one.',
    ),
    (
      'the end',
      'with few words left and few tries, count them: guess a word that could '
          'still be the answer once it splits the rest well enough to finish '
          'in time.',
    ),
  ],
  GameMode.quartet => const [
    (
      'one guess, four boards',
      'every guess is played on all four, so spend the first ones on letters '
          'that are new to every board. the split keys show what each board '
          'knows about a letter.',
    ),
    (
      'order',
      'a solved board drops out, so get the clearest one first and let the '
          'letters you have learned work on the others. late in the game, '
          'prefer a word that could solve one board and still tells you about '
          'another.',
    ),
    (
      'tries',
      'you have a few more tries than for one word, not four times as many: '
          'do not repeat a word the boards have already answered.',
    ),
  ],
  GameMode.relay => const [
    (
      'the first board does double work',
      'later boards open with every earlier guess already played on them, so '
          'what you guess to solve the first also tests the rest. keep the '
          'early guesses varied.',
    ),
    (
      'free rides',
      'a board can be solved the moment it opens. when you are choosing '
          'between words that fit the board in play, a word that also fits the '
          'next one is worth more.',
    ),
    (
      'locks',
      'only the board in play can lock letters, and locks clear when it is '
          'solved: lock what you know, then let go.',
    ),
  ],
  GameMode.lockdown => const [
    (
      'greens are permanent',
      'a green letter stays in its tile for the rest of the game, so you are '
          'guessing the other tiles only. every guess has to fill the locked '
          'tiles, which narrows what you can play.',
    ),
    (
      'hearts',
      'a word that is not in the list costs a heart, though not a try. when '
          'the locked letters leave few words, check the word exists before '
          'you submit it.',
    ),
    (
      'tries',
      'there are six, whatever the hearts: use the early ones to find greens, '
          'since each one removes a tile from the problem.',
    ),
  ],
  GameMode.blind => const [
    (
      'what a count says',
      'green plus yellow is how many letters of the guess are in the word. '
          'zero rules every letter out, and the full length means the guess is '
          'an anagram of the answer.',
    ),
    (
      'comparing guesses',
      'change one letter between two guesses and compare the counts: if the '
          'total goes up the new letter is in, down and the old one was. if the '
          'green count moves, the position matters.',
    ),
    (
      'pencil',
      'pencil what you have worked out on the guesses. with the colour logic '
          'on, the game refuses colours that cannot be true, which is a check '
          'on your reasoning. the notes score nothing.',
    ),
  ],
  GameMode.equations => const [
    (
      'the shape',
      'the = sits somewhere in the row, and the number after it is the answer, '
          'so its length is what is left of the row. a long row with a short '
          'answer is mostly a big sum; with a long answer it is mostly '
          'multiplying.',
    ),
    (
      'the first guesses',
      'open with different digits and different signs: you need to know which '
          'signs are in at all. one guess with + − × ÷ each once tells you more '
          'than four with only +.',
    ),
    (
      'checking',
      'every guess must be true, so work the sum out before you submit: × and '
          '÷ first, then + and −, each left to right, and no number starts '
          'with 0. a wrong guess costs nothing but is told why.',
    ),
    (
      'using what you know',
      'a digit that is grey is out everywhere. a green sign pins the shape of '
          'the sum. ÷ needs numbers that divide, which limits the digits it can '
          'sit between.',
    ),
  ],
  GameMode.mastermind => const [
    (
      'a reply is a promise',
      'the replies always fit at least one word, so every guess shrinks the '
          'words left, and you win when one is left and you say it. nothing is '
          'hidden except which word.',
    ),
    (
      'splitting',
      'choose the guess that cuts the words left into many small groups, not '
          'one big one: the reply you get is a group, and bigger groups are '
          'likelier. a guess that is itself one of the words left can end the '
          'game, but only once the group is small.',
    ),
    (
      'the two pool choices',
      'with random, luck matters: a big group is likelier but a small one can '
          'come up. with largest the reply is always the biggest group, with '
          'fixed tie-breaks, so you can work out what any guess will be told, '
          'and plan the whole game.',
    ),
  ],
  GameMode.themed => const [
    (
      'places',
      'the words are place names with the spaces left out. think of the kinds '
          'there are: countries, cities, rivers, mountains, lakes. the first '
          'guesses are about letters, as in any word, but common place '
          'endings (land, ia, ton) are worth testing early.',
    ),
    (
      'the info dot',
      'every guess has a small i that says what the place is and where: use it '
          'to learn which kind of place the answer might be.',
    ),
  ],
};

/// The strategy guide of [mode] as a page.
class ModeGuidePage extends StatelessWidget {
  const ModeGuidePage({super.key, required this.mode});
  final GameMode mode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablerIcon(
            'school',
            size: headerIconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'learn · ${mode.label}',
            style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            key: const ValueKey('mode-guide'),
            padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
            children: [
              for (final (heading, body) in modeGuide(mode))
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Caption(heading),
                      const SizedBox(height: 6),
                      Text(body, style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
