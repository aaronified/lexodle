import 'package:flutter/material.dart';

import 'ui.dart';
import 'words.dart';

/// The one language picker: a tall bottom sheet with a row per language.
/// Tapping one closes it with that language's code; back, or a tap outside,
/// closes it with null.
Future<String?> showLanguageSheet(
  BuildContext context, {
  required List<Language> langs,
  required String current,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  elevation: 0,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
  surfaceTintColor: Colors.transparent,
  shadowColor: Colors.transparent,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .92,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    side: hairline(Theme.of(context).colorScheme),
  ),
  builder: (_) => _LanguageSheet(langs: langs, current: current),
);

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.langs, required this.current});
  final List<Language> langs;
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('language-sheet'),
      height: MediaQuery.sizeOf(context).height * .92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 0, 8, 0),
            child: Row(
              children: [
                const Expanded(child: Caption('language')),
                IconButton(
                  key: const ValueKey('language-close'),
                  tooltip: 'close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final l in langs) _row(context, c, l),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ColorScheme c, Language l) {
    final selected = l.code == current;
    return InkWell(
      key: ValueKey('language-${l.code}'),
      onTap: () => Navigator.pop(context, l.code),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 19),
        color: selected ? c.secondaryContainer : null,
        child: Row(
          children: [
            FlagBadge(l.flag, size: 22),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                l.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.wikt,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: c.onSurface),
          ],
        ),
      ),
    );
  }
}
