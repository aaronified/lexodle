import 'dart:math';

import 'package:flutter/material.dart';

import 'ui.dart';
import 'words.dart';

/// The two difficulty dimensions. Tries run from easy to brutal; the pool is
/// how many of a language's most common words of the chosen length the answer
/// can be drawn from, so a small pool means familiar words.
const triesLevels = <(String name, int tries)>[
  ('easy', 8),
  ('normal', 6),
  ('hard', 4),
  ('brutal', 3),
];

const _poolNames = ['common', 'familiar', 'wide', 'obscure'];
final poolLevels = <(String name, int size)>[
  for (var i = 0; i < poolSizes.length; i++) (_poolNames[i], poolSizes[i]),
];

const _labelWidth = 104.0;

/// Whether the language has fewer words than the level's size.
bool _isCapped(int size, int? available) =>
    available != null && available < size;

/// The pool a language really offers at a length: at most the level's size.
int poolFor(int size, int? available) =>
    available == null ? size : min(size, available);

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// A 4 x 4 matrix to choose the difficulty from: tries across (easy to
/// brutal), pool size down (common to obscure). The colour of a cell runs from
/// green at the easy corner to purple at the hard one, from the theme.
class DifficultyMatrix extends StatelessWidget {
  const DifficultyMatrix({
    super.key,
    required this.tries,
    required this.pool,
    required this.available,
    required this.onChanged,
  });

  final int tries;
  final int pool;

  /// Words the language has at the chosen length (null when not known).
  final int? available;
  final void Function(int tries, int pool) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final selCol = triesLevels.indexWhere((l) => l.$2 == tries).clamp(0, 3);
    final selRow = poolLevels.indexWhere((l) => l.$2 == pool).clamp(0, 3);
    final selected = difficultyColor(c, (selCol + selRow) / 6);
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
            for (final (name, n) in triesLevels)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$n tries',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(name, style: head),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < 4; r++)
          Row(
            children: [
              SizedBox(
                width: _labelWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_thousands(poolFor(poolLevels[r].$2, available))} words',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        // a language with fewer words than the level asks for
                        // offers all it has, and the row says so
                        _isCapped(poolLevels[r].$2, available)
                            ? '${poolLevels[r].$1} · all'
                            : poolLevels[r].$1,
                        style: head,
                      ),
                    ],
                  ),
                ),
              ),
              for (var col = 0; col < 4; col++)
                Expanded(
                  child: _Cell(
                    color: difficultyColor(c, (r + col) / 6),
                    selected: r == selRow && col == selCol,
                    label:
                        '${triesLevels[col].$2} tries, '
                        '${poolFor(poolLevels[r].$2, available)} words',
                    onTap: () =>
                        onChanged(triesLevels[col].$2, poolLevels[r].$2),
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
                '${triesLevels[selCol].$1} · ${poolLevels[selRow].$1}: $tries tries, '
                'answers from ${_isCapped(pool, available) ? 'all ' : 'the '}'
                '${_thousands(poolFor(pool, available))} most common words',
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
