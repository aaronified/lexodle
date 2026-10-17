import 'package:flutter/material.dart';

import 'logic.dart';

/// Fixed feedback colours, the same in light and dark: green is the right
/// letter in the right place, yellow the right letter in the wrong place.
/// Absent letters recede into the surface.
(Color fill, Color fg) markColors(ColorScheme c, Mark m) => switch (m) {
      Mark.correct => (const Color(0xFF4C8C3A), Colors.white),
      Mark.present => (const Color(0xFFE0B83A), const Color(0xFF2A2200)),
      Mark.absent => (
          c.surfaceContainerHighest,
          c.onSurface.withValues(alpha: .4)
        ),
    };

/// One letter tile, coloured by [mark]; tappable when [onTap] is given.
class MarkTile extends StatelessWidget {
  const MarkTile(this.ch, {super.key, this.mark, required this.size, this.onTap});
  final String ch;
  final Mark? mark;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Color? fill;
    Color fg = c.onSurface;
    var border = ch.isEmpty ? c.outlineVariant : c.onSurface;
    if (mark != null) {
      (fill, fg) = markColors(c, mark!);
      border = fill;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(ch,
            style: TextStyle(
                fontSize: size * .5, fontWeight: FontWeight.bold, color: fg)),
      ),
    );
  }
}

/// Small tracked lowercase caption, the section label of the whole app.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.textAlign});
  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
        ),
      );
}

/// A bordered, selectable text cell used for the length and difficulty rows.
class Choice extends StatelessWidget {
  const Choice(this.label, {super.key, required this.selected, required this.onTap, this.sub});
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.primary : null,
            border: Border.all(color: selected ? c.primary : c.outline),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected ? c.onPrimary : c.onSurface)),
              if (sub != null)
                Text(sub!,
                    style: TextStyle(
                        fontSize: 11,
                        color: (selected ? c.onPrimary : c.onSurface)
                            .withValues(alpha: .7))),
            ],
          ),
        ),
      ),
    );
  }
}
