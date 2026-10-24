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

/// The pool a language really offers at a length: at most the level's size.
int poolFor(int size, int? available) =>
    available == null ? size : min(size, available);

/// The pool sizes a language offers at a length: only those it has that many
/// words for, so "obscure" (6,000) is never a shorter list under a bigger name.
/// All of them when the count is not known, and always at least the smallest.
List<int> poolsOffered(int? available) {
  if (available == null) return poolSizes;
  final offered = [
    for (final s in poolSizes)
      if (s <= available) s,
  ];
  return offered.isEmpty ? [poolSizes.first] : offered;
}

/// The pool a [preferred] size means for a language and length: the largest
/// one offered that is no bigger, or the smallest offered when all are.
int effectivePool(int preferred, int? available) {
  final offered = poolsOffered(available);
  return offered.lastWhere((s) => s <= preferred, orElse: () => offered.first);
}

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
    // only the rows the language can fill; a row keeps the colour of its level
    // (its place among all four) so green to purple still means easy to hard
    final rows = [
      for (final s in poolsOffered(available))
        poolLevels.indexWhere((l) => l.$2 == s),
    ];
    final shown = effectivePool(pool, available);
    final selCol = triesLevels.indexWhere((l) => l.$2 == tries).clamp(0, 3);
    final selLevel = poolLevels.indexWhere((l) => l.$2 == shown).clamp(0, 3);
    final selected = difficultyColor(c, (selCol + selLevel) / 6);
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
        for (final r in rows)
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
                        '${_thousands(poolLevels[r].$2)} words',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(poolLevels[r].$1, style: head),
                    ],
                  ),
                ),
              ),
              for (var col = 0; col < 4; col++)
                Expanded(
                  child: _Cell(
                    color: difficultyColor(c, (r + col) / 6),
                    selected: r == selLevel && col == selCol,
                    label:
                        '${triesLevels[col].$2} tries, '
                        '${poolLevels[r].$2} words',
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
                '${triesLevels[selCol].$1} · ${poolLevels[selLevel].$1}: $tries tries, '
                'answers from the ${_thousands(shown)} most common words',
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
