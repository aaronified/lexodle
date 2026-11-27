import 'package:flutter/material.dart';

import 'language_sheet.dart';
import 'language_switch.dart';
import 'app_log.dart';
import 'main.dart';
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
    this.dots = true,
    this.pill = false,
  });

  /// The slider as the round pill of the top bar (see [ChoiceSlider.pill]).
  final bool pill;

  /// Whether the dots show under the slider.
  final bool dots;

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
      pill: pill,
      dots: dots && !pill,
      selected: selected,
      onChanged: onSelect,
      title: 'language',
      footer: languagesFooter(context),
      items: [
        if (showAll)
          const ChoiceItem<String>(
            value: allLanguages,
            label: 'all',
            name: 'all languages',
          ),
        ...languageItems(codes, languages),
      ],
    );
  }
}

/// The language slider of the tab screens: the languages the player ticked in
/// the You tab, the one in use on show. Choosing another makes it the language
/// in use, for the dailies, free play and learn alike.
class LanguageBar extends StatefulWidget {
  const LanguageBar({super.key, this.pill = false});

  /// As the pill of the top bar.
  final bool pill;

  @override
  State<LanguageBar> createState() => _LanguageBarState();
}

class _LanguageBarState extends State<LanguageBar> {
  Map<String, Language> _langs = const {};

  @override
  void initState() {
    super.initState();
    WordBank.languages()
        .then((ls) {
          if (mounted) setState(() => _langs = {for (final l in ls) l.code: l});
        })
        .catchError((Object e) {
          appLog.w('language', 'bar failed ${e.runtimeType}');
        });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) => LanguagePicker(
      codes: appState.playLangs,
      languages: _langs,
      selected: appState.lang,
      dots: false,
      pill: widget.pill,
      onSelect: switchLanguage,
    ),
  );
}
