import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'store.dart';
import 'ui.dart';

/// The next trophy of the achievement [id] for a count of [n]: the first level
/// whose target is above [n] (the "every word" level has no number, so it is
/// not one). Null when every level is earned or the achievement is not found.
int? nextTrophy(String id, int n) {
  try {
    for (final a in achievements) {
      if (a.id != id) continue;
      for (var i = 0; i < a.levels.length; i++) {
        final t = a.levels[i].target;
        if (t >= allWords) continue;
        if (t > n) return t;
      }
    }
  } catch (e) {
    appLog.w('words', 'could not find the next trophy: ${e.runtimeType}');
  }
  return null;
}

/// The floating banner of the words page: the count, a line on it, the next
/// trophy and a bar towards it. [list] is `saved` or `collected`; the cross
/// hides it for this target only.
class WordsBanner extends StatelessWidget {
  const WordsBanner({
    super.key,
    required this.list,
    required this.n,
    required this.target,
  });

  final String list;
  final int n;
  final int target;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final line = list == 'saved'
        ? 'the words you chose to keep'
        : 'every word you win is added here';
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return Container(
      key: ValueKey('words-banner-$list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        border: Border.fromBorderSide(hairline(c)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$n words $list',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$line · next trophy at $target',
                  style: TextStyle(fontSize: 11, color: dim),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (n / target).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: c.primary,
                    backgroundColor: c.surfaceContainerHigh,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const ValueKey('words-banner-dismiss'),
              tooltip: 'dismiss',
              padding: EdgeInsets.zero,
              onPressed: () {
                try {
                  appState.dismissWordBanner(list, target);
                } catch (e) {
                  appLog.w('words', 'could not dismiss: ${e.runtimeType}');
                }
              },
              icon: Icon(Icons.close, size: 18, color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
