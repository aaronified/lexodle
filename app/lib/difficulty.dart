import 'package:flutter/material.dart';

import 'ui.dart';

/// The difficulty has two dimensions. Tries run from easy to brutal, and the
/// word length from longest (the easiest: a long word gives more away in every
/// guess) to shortest.
const triesLevels = <(String name, int tries)>[
  ('easy', 8),
  ('normal', 6),
  ('hard', 4),
  ('brutal', 3),
];

const _labelWidth = 84.0;

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// A matrix to choose the difficulty from: tries across (easy to brutal), word
/// length down (longest, the easiest, first). The colour of a cell runs from
/// green at the easy corner to purple at the hard one, from the theme.
class DifficultyMatrix extends StatelessWidget {
  const DifficultyMatrix({
    super.key,
    required this.tries,
    required this.length,
    required this.lengths,
    required this.available,
    required this.onChanged,
    this.levels = triesLevels,
    this.unit = ('try', 'tries'),
    this.extra = '',
  });

  /// The chosen level: the tries, or in lockdown the hearts.
  final int tries;

  /// The levels across, easiest first, and what they count (singular, plural).
  final List<(String name, int value)> levels;
  final (String, String) unit;

  /// Added to the summary, after the level: what else is fixed ("6 tries").
  final String extra;
  final int length;

  /// The word lengths the language has.
  final List<int> lengths;

  /// Words the language has at the chosen length (null when not known).
  final int? available;
  final void Function(int tries, int length) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // longest first: the easiest row is at the top, the colour follows
    final rows = [...lengths]..sort((a, b) => b.compareTo(a));
    final cols = levels.length;
    String counted(int n) => '$n ${n == 1 ? unit.$1 : unit.$2}';
    final selCol = levels.indexWhere((l) => l.$2 == tries).clamp(0, cols - 1);
    final selRow = rows.indexOf(length).clamp(0, rows.length - 1);
    final span = (rows.length - 1 + cols - 1).clamp(1, 100);
    final selected = difficultyColor(c, (selCol + selRow) / span);
    final head = TextStyle(
      fontSize: 10,
      letterSpacing: .8,
      height: 1.25,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (final (name, n) in levels)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      counted(n),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(name, style: head, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows.length; r++)
          Row(
            children: [
              SizedBox(
                width: _labelWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${rows[r]} letters',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              for (var col = 0; col < cols; col++)
                Expanded(
                  child: _Cell(
                    color: difficultyColor(c, (r + col) / span),
                    selected: r == selRow && col == selCol,
                    label: '${counted(levels[col].$2)}, ${rows[r]} letters',
                    onTap: () => onChanged(levels[col].$2, rows[r]),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selected,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${levels[selCol].$1} · $length letters: ${counted(tries)}, '
                '$extra${available == null ? 'every word of this length' : '${_thousands(available!)} words of this length'}',
                key: const ValueKey('difficulty-summary'),
                style: TextStyle(
                  fontSize: 12,
                  color: c.onSurface.withValues(alpha: .8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: .32),
              border: Border.all(
                color: selected
                    ? onColor(c, color)
                    : color.withValues(alpha: .7),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: selected
                ? Icon(Icons.check, size: 18, color: onColor(c, color))
                : null,
          ),
        ),
      ),
    );
  }
}
