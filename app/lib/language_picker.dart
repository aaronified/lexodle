import 'package:flutter/material.dart';

import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

/// What [LanguagePicker.selected] is when every language is picked.
const allLanguages = '*';

/// Picks which language a page is about: the one slider of the app
/// ([ChoiceSlider], compact), with the flag and the code of the language on show.
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
    return ChoiceSlider<String>(
      key: const ValueKey('language-picker'),
      id: 'language-slider',
      compact: true,
      selected: selected,
      onChanged: onSelect,
      items: [
        if (showAll)
          const ChoiceItem<String>(value: allLanguages, label: 'all'),
        for (final code in codes)
          ChoiceItem<String>(
            value: code,
            label: code,
            leading: languages[code] == null
                ? null
                : FlagBadge(languages[code]!.flag, size: 14),
          ),
      ],
    );
  }
}
