import 'package:flutter/material.dart';

import 'app_log.dart';
import 'blind_solver.dart';
import 'diy.dart' show diyLengths;
import 'diy_controls.dart';
import 'equation_solver.dart';
import 'equations.dart' show equationLengths;
import 'geography.dart';
import 'ladder.dart';
import 'language_sheet.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_solver.dart';
import 'routes.dart';
import 'settings_button.dart';
import 'solver.dart';
import 'solver_exclusions.dart';
import 'ui.dart';
import 'words.dart';

/// The page behind the solver: the solver of the mode chosen. The mode, the
/// language and the length are chosen in the solver settings sheet, and change
/// only this page, never the mode in view or the saved settings. Every solver
/// leaves out the answers of games in progress and of dailies not finished (see
/// [SolverExclusions]).
class SolverHubPage extends StatefulWidget {
  const SolverHubPage({super.key});

  @override
  State<SolverHubPage> createState() => _SolverHubPageState();
}

class _SolverHubPageState extends State<SolverHubPage> {
  late GameMode _mode = _first();

  // The solver's own settings: null until chosen, then the default is used.
  String? _lang;
  int? _length;
  List<Language> _langs = WordBank.loadedLanguages ?? const [];

  @override
  void initState() {
    super.initState();
    if (_langs.isEmpty) {
      WordBank.languages()
          .then((l) {
            if (mounted) setState(() => _langs = l);
          })
          .catchError((Object e) {
            appLog.w(
              'solver',
              'could not list the languages: ${e.runtimeType}',
            );
          });
    }
  }

  List<GameMode> get _modes => [
    for (final m in openModes(appState.level))
      if (GameMode.loopFor(appState.lang).contains(m)) m,
  ];

  GameMode _first() {
    final m = appState.mode;
    return _modes.contains(m) ? m : GameMode.classic;
  }

  bool get _fixedLanguage =>
      _mode == GameMode.themed || _mode == GameMode.equations;

  String get _language => _fixedLanguage ? 'en' : (_lang ?? appState.lang);

  Language? get _languageInfo {
    for (final l in _langs) {
      if (l.code == _language) return l;
    }
    return null;
  }

  /// The lengths the slider offers for the mode.
  List<int> get _lengths {
    switch (_mode) {
      case GameMode.themed:
        return Geography.counts.keys.toList()..sort();
      case GameMode.equations:
        return equationLengths;
      default:
        final l = _languageInfo;
        final have = [
          for (final n in diyLengths)
            if (l == null || l.lengths.contains(n)) n,
        ];
        return have.isEmpty ? diyLengths : have;
    }
  }

  int get _defaultLength =>
      _mode == GameMode.equations ? appState.eqLength : appState.length;

  int get _lengthNow {
    final l = _lengths;
    final n = _length;
    if (n != null && l.contains(n)) return n;
    if (l.contains(_defaultLength)) return _defaultLength;
    return l.isEmpty ? _defaultLength : l.first;
  }

  int get _defaultTries => switch (_mode) {
    GameMode.lockdown => lockdownTries,
    GameMode.mastermind => 99,
    GameMode.blind => appState.blindTries,
    GameMode.equations => appState.eqTries,
    GameMode.quartet || GameMode.relay => triesFor(_mode, appState.tries),
    _ => appState.tries,
  };

  /// The tries the game of the mode starts with: the solver does not change
  /// them (they only shape its advice near the end).
  int get _triesNow => _defaultTries;

  Future<void> _openOptions() async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          side: hairline(Theme.of(context).colorScheme),
        ),
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, setSheet) => _options(sheet, () {
            setState(() {});
            setSheet(() {});
          }),
        ),
      );
    } catch (e) {
      appLog.w('solver', 'could not open the settings: ${e.runtimeType}');
    }
  }

  Future<void> _pickLanguage(BuildContext sheet, VoidCallback refresh) async {
    try {
      final code = await showLanguageSheet(
        sheet,
        langs: _langs,
        current: _language,
      );
      if (!mounted || code == null || code == _language) return;
      _lang = code;
      // the lengths of the new language may not include the one chosen
      refresh();
    } catch (e) {
      appLog.w('solver', 'could not pick the language: ${e.runtimeType}');
    }
  }

  Widget _options(BuildContext sheet, VoidCallback refresh) {
    final c = Theme.of(sheet).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final lang = _languageInfo;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(19, 0, 19, 19),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'solver settings',
                      style: TextStyle(fontSize: 14, letterSpacing: 1.5),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('solver-options-close'),
                    tooltip: 'close',
                    icon: TablerIcon('x', size: 20, color: c.onSurface),
                    onPressed: () => Navigator.of(sheet).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwipeChoice<GameMode>(
                title: 'solver',
                items: [for (final m in _modes) (m, m.label)],
                selected: _mode,
                onChanged: (m) {
                  _mode = m;
                  refresh();
                },
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: _fixedLanguage ? .35 : 1,
                child: DropdownBox(
                  title: 'language',
                  onTap: () {
                    if (_fixedLanguage || _langs.isEmpty) return;
                    _pickLanguage(sheet, refresh);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lang != null) ...[
                        FlagBadge(lang.flag, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Text(_language),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LineSlider<int>(
                title: 'length',
                items: [for (final n in _lengths) (n, '$n', '')],
                selected: _lengthNow,
                onChanged: (n) {
                  _length = n;
                  refresh();
                },
              ),
              const SizedBox(height: 14),
              Text(
                'answers of your games in progress and of dailies you have '
                'not finished are left out.',
                style: TextStyle(fontSize: 11, color: dim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == GameMode.classic ? 'solver' : 'solver · ${_mode.label}',
          key: const ValueKey('solver-title'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('solver-options'),
            tooltip: 'solver settings',
            icon: TablerIcon(
              'adjustments-horizontal',
              size: 24,
              color: c.onSurface,
            ),
            onPressed: _openOptions,
          ),
          const SettingsButton(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [Expanded(child: _solver(_mode))]),
          ),
        ),
      ),
    );
  }

  /// The solver of [m], keyed by the mode, language, length and tries so that
  /// a change of any rebuilds it (and its guesses are lost).
  Widget _solver(GameMode m) {
    final lang = _language;
    final n = _lengthNow;
    final t = _triesNow;
    final key = ValueKey('${m.name}-$lang-$n-$t');
    switch (m) {
      case GameMode.equations:
        return BankGate(
          bare: true,
          key: key,
          equations: true,
          lang: lang,
          builder: (bank) => EquationSolverPage(
            bank: bank,
            length: n,
            tries: t,
            excluded: SolverExclusions.equations(n, bank: bank),
          ),
        );
      case GameMode.themed:
        return BankGate(
          bare: true,
          key: key,
          places: true,
          lang: lang,
          builder: (bank) => SolverPage(
            key: ValueKey('places-$n'),
            bank: bank,
            mode: GameMode.themed,
            length: n,
            tries: t,
            excluded: SolverExclusions.places(bank: bank),
          ),
        );
      default:
        return BankGate(
          bare: true,
          key: key,
          lang: lang,
          builder: (bank) => _words(m, bank, n, t),
        );
    }
  }

  Widget _words(GameMode m, WordBank bank, int n, int t) {
    final excluded = SolverExclusions.words(bank.language.code, n, bank: bank);
    switch (m) {
      case GameMode.quartet:
      case GameMode.relay:
        return MultiSolverPage(
          bank: bank,
          mode: m,
          length: n,
          tries: t,
          excluded: excluded,
        );
      case GameMode.blind:
        return BlindSolverPage(
          bank: bank,
          length: n,
          tries: t,
          excluded: excluded,
        );
      case GameMode.mastermind:
        // no fixed answer to hide; unlimited tries, so a large number
        return SolverPage(bank: bank, mode: m, length: n, tries: 99);
      default:
        return SolverPage(
          bank: bank,
          mode: m,
          length: n,
          tries: t,
          excluded: excluded,
        );
    }
  }
}
