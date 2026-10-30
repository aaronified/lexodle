import 'package:flutter/material.dart';

import 'guess_input.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'ui.dart';
import 'wiki_links.dart';

/// How to play, kept short: the rule, the colours, the blanks and the cursor,
/// and the one line of maths (every guess gains bits; skill, luck and risk). Anyone
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

    /// One guess, submitted: every tile has its colour, as the colours only
    /// appear once a guess is in. A line under it for each colour.
    Widget colours() {
      const guess = 'weary';
      final marks = evaluate('wheel', guess);
      Widget line(int at, String note) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: guess[at],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' $note'),
            ],
          ),
          style: const TextStyle(height: 1.4),
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: const ValueKey('colours-row'),
              children: [
                for (var i = 0; i < guess.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: MarkTile(guess[i], size: 44, mark: marks[i]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            line(0, 'is in the word and in the correct spot.'),
            line(1, 'is in the word but in the wrong spot.'),
            line(2, 'is not in the word in any spot.'),
          ],
        ),
      );
    }

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
                    padding: const EdgeInsets.fromLTRB(19, 0, 19, 32),
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
                      colours(),
                      Text(
                        'the examples are in english; every language plays the '
                        'same.',
                        style: dim,
                      ),
                      const SizedBox(height: 22),
                      heading('blanks, the cursor and locks'),
                      const HowToTry(),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 14),
                      heading('the maths'),
                      Text(
                        'every guess gains bits of information',
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
                        'is the bits a guess was expected to gain, against the best guess.',
                      ),
                      maths(
                        'luck',
                        'is whether the clues gained more or less than usual.',
                      ),
                      maths(
                        'risk',
                        'is how much you gambled on a rare big gain.',
                      ),
                      const SizedBox(height: 4),
                      const WikiLink(
                        WikiPage.skillLuckRisk,
                        label: 'how skill, luck and risk work',
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
                    padding: const EdgeInsets.fromLTRB(19, 8, 19, 16),
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

/// One live example for the blanks, the cursor and the locks: a row of tiles
/// that works as the game's does, so a player can try it right there, with
/// touch alone (a phone has no keyboard): tap a tile to move the cursor, double
/// tap it to lock its letter, or to unlock it.
class HowToTry extends StatefulWidget {
  const HowToTry({super.key});

  @override
  State<HowToTry> createState() => _HowToTryState();
}

class _HowToTryState extends State<HowToTry> {
  static final _letters = {
    for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) c,
  };
  late GuessInput _input = _start();

  /// `a ode` with the cursor on the blank, and nothing locked.
  GuessInput _start() {
    final g = GuessInput(5);
    for (final ch in 'a ode'.split('')) {
      g.type(ch == ' ' ? GuessInput.blank : ch, _letters);
    }
    g.select(1);
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final locked = [
      for (var i = 0; i < 5; i++)
        if (_input.isLocked(i)) i,
    ];
    final at = _input.cursor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const ValueKey('try-row'),
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: MarkTile(
                    _input.slot(i),
                    key: ValueKey('try-$i'),
                    size: 44,
                    cursor: i == at,
                    locked: _input.isLocked(i),
                    onTap: () => setState(() => _input.tap(i)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'not sure of a letter? press space (or _) to leave a blank. a '
            'blank cannot be submitted.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 6),
          const Text(
            'the outlined tile is the cursor: the next letter goes there. '
            'tap any tile to move it.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 6),
          const Text(
            'double tap a tile to lock its letter, again to unlock. a locked '
            'letter stays for the next guess. try it here.',
            key: ValueKey('try-lock-note'),
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  at >= 5
                      ? 'cursor: after the last tile'
                      : 'cursor on tile ${at + 1}'
                            '${locked.isEmpty ? '' : ' · locked: ${locked.map((i) => i + 1).join(', ')}'}',
                  key: const ValueKey('try-status'),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.onSurface.withValues(alpha: .65),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('try-reset'),
                onPressed: () => setState(() => _input = _start()),
                child: const Text('start again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
