import 'package:flutter/material.dart';

/// Small tracked lowercase caption, the section label of the whole app.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
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
