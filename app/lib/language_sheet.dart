import 'package:flutter/material.dart';

import 'app_log.dart';
import 'language_switch.dart';
import 'main.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

/// The popup items of languages: the slider shows a code and a flag, the popup
/// the language's own name and, under it, its name in English.
List<ChoiceItem<String>> languageItems(
  Iterable<String> codes,
  Map<String, Language> languages,
) => [
  for (final code in codes)
    ChoiceItem<String>(
      value: code,
      label: code,
      name: languages[code]?.name ?? code,
      sub:
          languages[code] == null ||
              languages[code]!.wikt == languages[code]!.name
          ? null
          : languages[code]!.wikt.toLowerCase(),
      leading: languages[code] == null
          ? null
          : FlagBadge(languages[code]!.flag, size: 14),
      popupLeading: languages[code] == null
          ? null
          : FlagBadge(languages[code]!.flag, size: 22),
    ),
];

/// The row that ends a language popup: it opens the sheet where the languages
/// of the sliders are ticked.
GroupRow languagesFooter(BuildContext context) => GroupRow(
  key: const ValueKey('choose-languages'),
  leading: const TonalTile('plus'),
  title: const Text('choose languages'),
  subtitle: const Text('tick the ones in the switchers'),
  onTap: () => showLanguagesChooser(context),
);

/// The one language picker, a sheet like every other: a row per language.
/// Tapping one closes it with that language's code; back, or a tap outside,
/// closes it with null.
Future<String?> showLanguageSheet(
  BuildContext context, {
  required List<Language> langs,
  required String current,
}) => showPickerSheet<String>(
  context,
  title: 'language',
  keyPrefix: 'language',
  selected: current,
  items: languageItems(
    [for (final l in langs) l.code],
    {for (final l in langs) l.code: l},
  ),
);

/// The sheet where the player ticks the languages they play: those are the
/// stops of every language slider. At least one stays ticked; unticking the
/// language in use moves to another.
Future<void> showLanguagesChooser(BuildContext context) async {
  try {
    final langs = await WordBank.languages();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LanguagesChooser(langs: langs),
    );
  } catch (e) {
    appLog.w('language', 'chooser failed ${e.runtimeType}');
  }
}

class _LanguagesChooser extends StatelessWidget {
  const _LanguagesChooser({required this.langs});
  final List<Language> langs;

  String? _sub(Language l) {
    final t = [
      if (l.wikt != l.name) l.wikt.toLowerCase(),
      if (l.code == appState.lang) 'in use',
    ].join(' · ');
    return t.isEmpty ? null : t;
  }

  Future<void> _toggle(Language l, bool on) async {
    try {
      if (!appState.setPlayLang(l.code, !on)) return;
      // the language in use is unticked: another one is in use now
      if (on && l.code == appState.lang) {
        final rest = appState.playLangs.where((c) => c != l.code);
        if (rest.isNotEmpty) await switchLanguage(rest.first);
      }
    } catch (e) {
      appLog.w('language', 'tick failed ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) {
      final ticked = appState.playLangs;
      return SheetFrame(
        title: 'languages',
        note:
            'tick the languages you play. they are the stops of every language '
            'switcher. at least one stays ticked.',
        child: GroupedList(
          rows: [
            for (final l in langs)
              GroupRow(
                key: ValueKey('tick-${l.code}'),
                leading: LeadTile(FlagBadge(l.flag, size: 22)),
                title: Text(l.name),
                subtitle: _sub(l) == null ? null : Text(_sub(l)!),
                trailing: TickBox(ticked.contains(l.code)),
                chevron: false,
                onTap: () => _toggle(l, ticked.contains(l.code)),
              ),
          ],
        ),
      );
    },
  );
}
