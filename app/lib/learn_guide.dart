import 'package:flutter/material.dart';

import 'help.dart';
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
List<HelpSection> modeGuide(GameMode mode) => switch (mode) {
  GameMode.classic => const [
    HelpSection('the first guesses', [
      'open with common, different letters.',
      'you are finding letters, not winning.',
      'a new letter tells you more than an old one.',
    ], crop: 'opening'),
    HelpSection('the middle', [
      'play the word that splits the rest best.',
      'not the one that merely fits.',
      '_atch: test several letters at once.',
    ], crop: 'groups'),
    HelpSection('the end', [
      'count the words left and the tries left.',
      'a word that could win and still splits is best.',
    ]),
  ],
  GameMode.quartet => const [
    HelpSection('one guess, four boards', [
      'every guess plays on all four.',
      'spend the first on letters new to every board.',
      'the split keys show what each board knows.',
    ], crop: 'split'),
    HelpSection('order', [
      'solve the clearest board first.',
      'its letters then work on the others.',
      'late on, one word can solve one and test another.',
    ]),
    HelpSection('tries', [
      'a few more than for one word, not four times.',
      'do not repeat what the boards have answered.',
    ]),
  ],
  GameMode.relay => const [
    HelpSection('the first board does double work', [
      'later boards open with every guess played.',
      'so keep the early guesses varied.',
    ], crop: 'relay'),
    HelpSection('free rides', [
      'a board can be solved the moment it opens.',
      'prefer a word that fits the next board too.',
    ]),
    HelpSection('locks', [
      'only the board in play locks.',
      'locks clear when it is solved.',
      'lock what you know, then let go.',
    ]),
  ],
  GameMode.lockdown => const [
    HelpSection('greens are permanent', [
      'a green stays in its tile for good.',
      'you guess the other tiles only.',
      'every guess must fill the locked tiles.',
    ], crop: 'lockdown'),
    HelpSection('hearts', [
      'a word not in the list costs a heart, not a try.',
      'few words fit? check it exists first.',
    ]),
    HelpSection('tries', [
      'six, whatever the hearts.',
      'find greens early: each removes a tile.',
    ]),
  ],
  GameMode.blind => const [
    HelpSection('what a count says', [
      'green plus yellow: letters of the guess in the word.',
      'zero rules every letter out.',
      'all of them: an anagram of the answer.',
    ], crop: 'counts'),
    HelpSection('comparing guesses', [
      'change one letter and compare the counts.',
      'the total up: the new letter is in.',
      'the total down: the old one was.',
      'green moves: the place matters.',
    ], crop: 'compare'),
    HelpSection('pencil', [
      'pencil what you worked out.',
      'the game refuses colours that cannot be true.',
      'notes score nothing.',
    ], crop: 'pencil'),
  ],
  GameMode.equations => const [
    HelpSection('the shape', [
      'the = sits in the row; the number after it is the answer.',
      'a long row, a short answer: a big sum.',
      'a long answer: mostly multiplying.',
    ], crop: 'equation'),
    HelpSection('the first guesses', [
      'open with different digits and different signs.',
      'one guess with + − × ÷ once tells most.',
    ], crop: 'signs'),
    HelpSection('checking', [
      'work the sum out before you submit.',
      '× and ÷ first, then + and −.',
      'no number starts with 0.',
      'a wrong guess costs nothing, and says why.',
    ]),
    HelpSection('using what you know', [
      'a grey digit is out everywhere.',
      'a green sign pins the shape.',
      '÷ needs numbers that divide.',
    ]),
  ],
  GameMode.mastermind => const [
    HelpSection('a reply is a promise', [
      'every reply fits at least one word.',
      'each guess shrinks the words left.',
      'win when one is left and you say it.',
    ], crop: 'reply'),
    HelpSection('splitting', [
      'pick the guess that makes many small groups.',
      'the reply you get is one group.',
      'big groups are likelier.',
      'a word that could be it ends the game, once the group is small.',
    ], crop: 'groups'),
    HelpSection('the two pools', [
      'random: luck matters.',
      'largest: the reply is always the biggest group.',
      'so you can plan the whole game.',
    ]),
  ],
  GameMode.themed => const [
    HelpSection('places', [
      'the words are places, spaces left out.',
      'think of the kinds: countries, cities, rivers.',
      'test endings early: land, ia, ton.',
    ], crop: 'place'),
    HelpSection('the info dot', [
      'every guess has a small i.',
      'it says what the place is, and where.',
      'use it to learn the kind of place.',
    ]),
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
              for (final sec in modeGuide(mode))
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Caption(sec.heading),
                      const SizedBox(height: 8),
                      if (sec.crop != null) ...[
                        HelpCrop(sec.crop!),
                        const SizedBox(height: 8),
                      ],
                      for (final line in sec.lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(line),
                        ),
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
