import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puzzle.dart';

/// The app bar button of a daily puzzle: copies its link, so it can be sent to
/// anyone, who then plays the same words as practice.
class SharePuzzleButton extends StatelessWidget {
  const SharePuzzleButton(this.puzzle, {super.key});
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('share-puzzle'),
    tooltip: 'copy a link to this puzzle',
    icon: const Icon(Icons.link),
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: puzzle.link));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('link copied')));
    },
  );
}
