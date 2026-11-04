import 'package:flutter/material.dart';

import 'modes.dart';
import 'ui.dart';

/// How to play [mode], as headed paragraphs: its rules, then what the keys and
/// the board do (blanks, locks and the rest), which are part of playing it.
/// [daily] adds what a daily is.
List<(String, String)> modeHelp(GameMode mode, {bool daily = false}) {
  final colours =
      'green: the right letter in the right place. yellow: the letter is in '
      'the word, in another place. grey: it is not in the word (or not as many '
      'times as you typed it).';
  final rules = switch (mode) {
    GameMode.classic => (
      'the rules',
      'find the hidden word before the tries run out. every guess has to be a '
          'word of the list, with every tile filled.\n\n$colours',
    ),
    GameMode.quartet => (
      'the rules',
      'four words are hidden, and every guess is played on all four boards at '
          'once. you have a few more tries than for one word. a board that is '
          'solved drops out. every key is split in four, one part for each board, '
          'coloured by what that board says about the letter.\n\n$colours',
    ),
    GameMode.relay => (
      'the rules',
      'four words are hidden, played one after the other. only the first board '
          'is open: when it is solved the next opens with every earlier guess '
          'already played on it, which can solve it at once. you have a few '
          'more tries than for one word.\n\n$colours',
    ),
    GameMode.lockdown => (
      'the rules',
      'find the hidden word. every letter you get in the right place is locked '
          'in its tile for the rest of the game, and cannot be taken off. a '
          'word that is not in the list costs a heart and does not use a try; '
          'with no hearts left the game is lost.\n\n$colours',
    ),
    GameMode.blind => (
      'the rules',
      'find the hidden word, with no colours on the tiles. next to each guess '
          'are two counts: the green one is how many letters are right and in '
          'place, the yellow one how many are in the word but elsewhere. it '
          'never says which.\n\n'
          'to keep track, tap a letter of a guess you made to pencil a colour '
          'on it: green, yellow, grey, then none. the control key does the same '
          'to the letter under the cursor. with the colour logic on, what the '
          'counts settle is marked for you and only colours that can be true '
          'can be pencilled. the notes score nothing.',
    ),
    GameMode.equations => (
      'the rules',
      'find the hidden equation. every guess has to be a true equation: one =, '
          'a sum on the left and one whole number on the right. × and ÷ are '
          'done before + and −, and each kind left to right. no number starts with 0, no sign comes before '
          'a number, and a lone 0 is not allowed (10 is). the keys are a number '
          'pad, and x on a keyboard types ×.\n\n'
          'the colours are for the digits and signs. $colours',
    ),
    GameMode.mastermind => (
      'the rules',
      'no word is chosen. every guess is answered as one of the words still '
          'possible would answer it, so the colours always fit at least one '
          'word. you win by guessing the word that is left. there is no limit '
          'on guesses: fewer is better.\n\n'
          'the game modes screen has the pool choice. random draws one of the '
          'words still possible, so the reply that keeps the most words is the '
          'likeliest. largest always gives the reply that keeps the most words, '
          'with no chance in it.\n\n$colours',
    ),
    GameMode.themed => (
      'the rules',
      'the words are place names, spaces left out, and only place names are '
          'valid guesses. every guess has a small i that says what the place is '
          'and links to its page.\n\n$colours',
    ),
  };
  final blind = mode == GameMode.blind;
  final lockdown = mode == GameMode.lockdown;
  final relay = mode == GameMode.relay;
  return [
    rules,
    (
      'typing',
      'type on your keyboard or the keys on the screen. the tile with the thick '
          'border is the cursor: tap a tile, or use the arrow keys, to move it. '
          'backspace (or delete) clears a tile. drag along the space key to move it. swipe from right to left over '
          'the row you are typing, or press shift and backspace, to erase the '
          'whole row.',
    ),
    (
      'spaces',
      'the space key (the _ key on the screen) types a blank: a pencil mark for '
          'a tile you have not worked out yet. the cursor skips on to it when you '
          'have typed the rest. a row with a blank cannot be submitted until it '
          'is filled.',
    ),
    (
      'locks',
      'double tap a tile of the row you are typing, or press shift on the '
          'cursor, to lock its letter. a locked letter stays for your next guess '
          'and is not typed over; double tap again to unlock it.'
          '${lockdown ? ' the green locks are the game\'s: they cannot be taken off.' : ''}'
          '${blind ? ' double tap the counts to lock every letter you have pencilled green.' : ' double tap the guesses you have made to lock every green found so far, in place of your own locks (the other letters typed in the row are cleared).'}'
          '${relay ? ' only the board in play can lock.' : ''}',
    ),
    if (daily)
      (
        'the daily',
        'the same for everyone on a date, with fixed settings, and played once a '
            'day: closing the page does not reroll it. the next one comes at '
            'midnight, your time.',
      ),
  ];
}

/// The help button of a game screen, at the top right: the rules of [mode].
class ModeHelpButton extends StatelessWidget {
  const ModeHelpButton({super.key, required this.mode, this.daily = false});
  final GameMode mode;
  final bool daily;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('help-button'),
    tooltip: 'how to play',
    icon: TablerIcon(
      'info-circle',
      size: 24,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    onPressed: () => showModeHelp(context, mode, daily: daily),
  );
}

/// Shows the rules of [mode] in a dialog.
Future<void> showModeHelp(
  BuildContext context,
  GameMode mode, {
  bool daily = false,
}) {
  final c = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      key: const ValueKey('help-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'how to play · ${mode.label}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('help-close'),
                    tooltip: 'close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (heading, body) in modeHelp(mode, daily: daily))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Caption(heading),
                            const SizedBox(height: 6),
                            Text(body, style: const TextStyle(height: 1.4)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
