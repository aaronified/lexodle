import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puzzle.dart';

/// The app bar button of a puzzle: a menu of two links to copy. One is the
/// puzzle (its words, hashed, so the link does not give them away); the other is
/// the puzzle with the guesses made so far, in plain, which opens already played.
class SharePuzzleButton extends StatelessWidget {
  const SharePuzzleButton(this.puzzleOf, {super.key});

  /// The puzzle, with the guesses so far when [withGuesses].
  final Puzzle Function(bool withGuesses) puzzleOf;

  @override
  Widget build(BuildContext context) => PopupMenuButton<bool>(
    key: const ValueKey('share-puzzle'),
    tooltip: 'share this puzzle',
    icon: const Icon(Icons.link),
    onSelected: (withGuesses) async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: puzzleOf(withGuesses).link));
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
}
