import 'dart:math';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'ui.dart';

/// The on-screen keyboard: QWERTY for the letters the language uses, then the
/// language's own extra letters (accents and the like), with keys coloured by
/// what the game has learned about them.
class LetterKeyboard extends StatelessWidget {
  const LetterKeyboard({
    super.key,
    required this.letters,
    required this.onLetter,
    required this.onEnter,
    required this.onBack,
    this.marks = const {},
    this.enterLabel = 'enter',
  });

  final Set<String> letters;
  final Map<String, Mark> marks;
  final void Function(String) onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBack;
  final String enterLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const base = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    final extra = letters.where((l) => !base.join().contains(l)).toList()
      ..sort();
    final rows = <List<String>>[
      for (final r in base) r.split('').where(letters.contains).toList(),
      for (var i = 0; i < extra.length; i += 10)
        extra.sublist(i, min(i + 10, extra.length)),
    ];

    Widget key(String label, VoidCallback tap, {Mark? mark, double flex = 1}) {
      Color? fill;
      Color fg = c.onSurface;
      if (mark != null) (fill, fg) = markColors(c, mark);
      return Expanded(
        flex: (flex * 10).round(),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: fill ?? c.outline),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: label.length > 1 ? 11 : 16,
                      fontWeight: FontWeight.bold,
                      color: fg)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++)
          Row(children: [
            if (i == 2) key(enterLabel, onEnter, flex: 1.6),
            for (final l in rows[i]) key(l, () => onLetter(l), mark: marks[l]),
            if (i == 2) key('⌫', onBack, flex: 1.6),
          ]),
      ]),
    );
  }
}
