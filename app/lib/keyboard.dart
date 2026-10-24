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
    this.onBlank,
    this.marks = const {},
    this.quadMarks = const {},
    this.enterLabel = 'enter',
  });

  final Set<String> letters;
  final Map<String, Mark> marks;

  /// For the games with several boards: per letter, what each board says about
  /// it. A key with any of these is split into equal parts, one per board in
  /// reading order (top left, top right, bottom left, bottom right), each in
  /// that board's feedback colour, with no edge or gap between them.
  final Map<String, List<Mark?>> quadMarks;
  final void Function(String) onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBack;

  /// Types a blank, a pencil mark for a letter not worked out yet. When set, a
  /// wide key for it sits on a row of its own under the letters.
  final VoidCallback? onBlank;
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

    // Letters take the feedback colours; the two action keys have colours of
    // their own, from the scheme: enter is the accent, backspace the error
    // container, so neither can be mistaken for a letter or its feedback.
    Widget key(
      String label,
      VoidCallback tap, {
      Mark? mark,
      double flex = 1,
      (Color fill, Color fg)? colors,
      List<Mark?>? quad,
    }) {
      if (quad != null && quad.any((m) => m != null)) {
        return Expanded(
          flex: (flex * 10).round(),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(3),
              child: _QuadKey(label: label, marks: quad),
            ),
          ),
        );
      }
      Color? fill;
      Color fg = c.onSurface;
      Color? edge;
      var edgeWidth = 1.0;
      if (mark != null) {
        (fill, fg) = markColors(c, mark);
        edge = markBorder(c, mark);
        edgeWidth = markBorderWidth(mark);
      }
      if (colors != null) (fill, fg) = colors;
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
                border: Border.all(
                  color: edge ?? fill ?? c.outline,
                  width: edgeWidth,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: label.length > 1 ? 11 : 16,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Row(
              children: [
                if (i == 2)
                  key(
                    enterLabel,
                    onEnter,
                    flex: 1.6,
                    colors: (c.primary, c.onPrimary),
                  ),
                for (final l in rows[i])
                  key(l, () => onLetter(l), mark: marks[l], quad: quadMarks[l]),
                if (i == 2)
                  key(
                    '⌫',
                    onBack,
                    flex: 1.6,
                    colors: (c.errorContainer, c.onErrorContainer),
                  ),
              ],
            ),
          if (onBlank != null)
            Row(
              children: [
                const Spacer(flex: 20),
                key('_', onBlank!, flex: 6),
                const Spacer(flex: 20),
              ],
            ),
        ],
      ),
    );
  }
}

/// One key split in four by board: a 2 x 2 of the boards' colours, the letter
/// over it in whichever of the page's two text colours reads best on their
/// average. The parts are painted without anti-aliasing at their shared edges,
/// so no seam shows between them.
class _QuadKey extends StatelessWidget {
  const _QuadKey({required this.label, required this.marks});
  final String label;
  final List<Mark?> marks;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colors = [
      for (var i = 0; i < 4; i++)
        i < marks.length && marks[i] != null
            ? markColors(c, marks[i]!).$1
            : null,
    ];
    // the average of what is behind the letter, an unset part being the page
    final shown = [for (final x in colors) x ?? c.surface];
    final avg = Color.fromARGB(
      255,
      shown.map((x) => (x.r * 255).round()).reduce((a, b) => a + b) ~/ 4,
      shown.map((x) => (x.g * 255).round()).reduce((a, b) => a + b) ~/ 4,
      shown.map((x) => (x.b * 255).round()).reduce((a, b) => a + b) ~/ 4,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 46,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              key: ValueKey('quad-$label'),
              painter: QuadPainter(colors),
            ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onColor(c, avg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints [colors] (null = leave clear) as the four quarters of its box.
class QuadPainter extends CustomPainter {
  QuadPainter(this.colors);
  final List<Color?> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 2, h = size.height / 2;
    for (var i = 0; i < 4; i++) {
      final color = colors[i];
      if (color == null) continue;
      final x = (i % 2) * w, y = (i ~/ 2) * h;
      canvas.drawRect(
        Rect.fromLTWH(x, y, w + (i % 2 == 0 ? .5 : 0), h + (i < 2 ? .5 : 0)),
        Paint()
          ..color = color
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(QuadPainter old) =>
      old.colors.toString() != colors.toString();
}
