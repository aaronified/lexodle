import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puzzle.dart';
import 'ui.dart';

/// The app bar button of a puzzle: a menu of two links to copy. One is the
/// puzzle (its words, hashed, so the link does not give them away); the other is
/// the puzzle with the guesses made so far, in plain, which opens already played.
class SharePuzzleButton extends StatelessWidget {
  const SharePuzzleButton(this.puzzleOf, {super.key, this.compact = false});

  /// A smaller button, for a row of a list.
  final bool compact;

  /// The puzzle, with the guesses so far when [withGuesses].
  final Puzzle Function(bool withGuesses) puzzleOf;

  @override
  Widget build(BuildContext context) {
    final button = PopupMenuButton<bool>(
      key: const ValueKey('share-puzzle'),
      tooltip: 'share this puzzle',
      icon: TablerIcon(
        'link',
        size: compact ? 20 : 24,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      // the menu opens under the button, which stays in sight
      position: PopupMenuPosition.under,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      onSelected: (withGuesses) async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(
          ClipboardData(text: puzzleOf(withGuesses).link),
        );
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('link copied')));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          key: ValueKey('share-word'),
          value: false,
          child: Text('the puzzle (the word is hashed)'),
        ),
        PopupMenuItem(
          key: ValueKey('share-guesses'),
          value: true,
          child: Text('the puzzle and my guesses'),
        ),
      ],
    );
    // in a row of a list the button is smaller than the app bar's
    return compact ? SizedBox(width: 32, height: 32, child: button) : button;
  }
}
