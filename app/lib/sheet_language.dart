import 'dart:async';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'language_picker.dart';
import 'language_switch.dart';
import 'main.dart';
import 'words.dart';

/// The language of the sheet on show. While history, achievements or the
/// playstyle is open, the top bar's language pill is that sheet's choice: it
/// has an all stop, and all is where it starts. The sheets read [selected] (a
/// code, or [allLanguages]); the app's own language is left as it is.
class SheetLanguage extends ChangeNotifier {
  int _open = 0;
  String _selected = allLanguages;
  bool _allowAll = true;

  /// Whether the pill has an all stop (the reminders are one language's).
  bool get allowAll => _allowAll;

  bool get active => _open > 0;
  String get selected => _selected;

  /// The language to look at: null for all of them.
  String? get language => _selected == allLanguages ? null : _selected;

  void open({bool all = true}) {
    if (_open == 0) {
      _allowAll = all;
      _selected = all ? allLanguages : appState.lang;
    }
    _open++;
    notifyListeners();
  }

  void close() {
    if (_open > 0) _open--;
    notifyListeners();
  }

  /// Back to the start (for tests).
  @visibleForTesting
  void reset() {
    _open = 0;
    _allowAll = true;
    _selected = allLanguages;
  }

  void select(String code) {
    _selected = code;
    notifyListeners();
  }
}

final sheetLanguage = SheetLanguage();

/// Makes [sheetLanguage] active for as long as [child] is on screen.
class SheetLanguageScope extends StatefulWidget {
  const SheetLanguageScope({super.key, required this.child, this.all = true});
  final Widget child;

  /// Whether the pill has an all stop (and starts on it).
  final bool all;

  @override
  State<SheetLanguageScope> createState() => _SheetLanguageScopeState();
}

class _SheetLanguageScopeState extends State<SheetLanguageScope> {
  @override
  void initState() {
    super.initState();
    // after this frame: opening notifies the top bar, which is being built
    scheduleMicrotask(() => sheetLanguage.open(all: widget.all));
  }

  @override
  void dispose() {
    scheduleMicrotask(sheetLanguage.close);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The languages a history, achievement or playstyle sheet can look at: the
/// ticked ones, then any other the player has played.
List<String> sheetLanguageCodes() => sheetLanguage.allowAll
    ? languageStops(
        {
          ...appState.playedLanguages,
          for (final g in appState.history.games) g.lang,
        }.toList()..sort(),
      )
    : languageStops();

/// The top bar's pill while a sheet language is active: all, then the languages.
class SheetLanguagePill extends StatefulWidget {
  const SheetLanguagePill({super.key});

  @override
  State<SheetLanguagePill> createState() => _SheetLanguagePillState();
}

class _SheetLanguagePillState extends State<SheetLanguagePill> {
  Map<String, Language> _langs = const {};

  @override
  void initState() {
    super.initState();
    WordBank.languages()
        .then((ls) {
          if (mounted) setState(() => _langs = {for (final l in ls) l.code: l});
        })
        .catchError((Object e) {
          appLog.w('language', 'sheet pill failed ${e.runtimeType}');
        });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([appState, sheetLanguage]),
    builder: (context, _) {
      final codes = sheetLanguageCodes();
      final sel = sheetLanguage.selected;
      return LanguagePicker(
        codes: codes,
        languages: _langs,
        selected:
            (sel == allLanguages && sheetLanguage.allowAll) ||
                codes.contains(sel)
            ? sel
            : (sheetLanguage.allowAll ? allLanguages : codes.first),
        showAll: sheetLanguage.allowAll,
        dots: false,
        pill: true,
        onSelect: sheetLanguage.select,
      );
    },
  );
}
