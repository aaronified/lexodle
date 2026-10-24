import 'package:flutter/material.dart';

import 'ui.dart';
import 'words.dart';

/// What [LanguagePicker.selected] is when every language is picked.
const allLanguages = '*';

/// A row of language badges (the flags) to pick which language a page is about.
/// Each language has its own history, playstyle, streak and achievements, so the
/// pages that show them say which it is and let the player look at another.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.codes,
    required this.languages,
    required this.selected,
    required this.onSelect,
    this.showAll = false,
  });

  /// Offers "all" before the languages: every language at once.
  final bool showAll;

  /// The languages to offer, in the order shown.
  final List<String> codes;

  /// What is known of each language (for its flag); a language not known yet
  /// shows its code.
  final Map<String, Language> languages;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (showAll)
          Semantics(
            button: true,
            selected: selected == allLanguages,
            label: 'all languages',
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('lang-all'),
              onTap: () => onSelect(allLanguages),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected == allLanguages
                        ? c.primary
                        : c.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected == allLanguages
                        ? FontWeight.bold
                        : null,
                  ),
                ),
              ),
            ),
          ),
        for (final code in codes)
          Semantics(
            button: true,
            selected: code == selected,
            label: languages[code]?.name ?? code,
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('lang-$code'),
              onTap: () => onSelect(code),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: code == selected ? c.primary : c.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (languages[code] case final l?) ...[
                      FlagBadge(l.flag, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: code == selected ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
