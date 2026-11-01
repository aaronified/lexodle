import 'package:flutter/material.dart';

import 'store.dart';
import 'ui.dart';

/// The achievements a game or a piece of learning has just earned, one row each:
/// the icon, what it is called and what it asked.
class EarnedRows extends StatelessWidget {
  const EarnedRows(this.earned, {super.key});
  final List<Achievement> earned;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('earned-rows'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in earned)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                TablerIcon(a.icon, size: 30, color: c.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${a.title}  —  ${a.description}',
                    style: TextStyle(color: c.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
