import 'package:flutter/material.dart';

import 'blind_solver.dart';
import 'equation_solver.dart';
import 'geography.dart';
import 'ladder.dart';
import 'main.dart';
import 'mode_filter.dart';
import 'modes.dart';
import 'multi_solver.dart';
import 'routes.dart';
import 'settings_button.dart';
import 'solver.dart';
import 'solver_exclusions.dart';
import 'ui.dart';
import 'words.dart';

/// The page behind the solver: a row of the modes open to the player and the
/// solver of the one chosen. Choosing a mode here changes only this page, never
/// the mode in view. Every solver leaves out the answers of games in progress
/// and of dailies not finished (see [SolverExclusions]).
class SolverHubPage extends StatefulWidget {
  const SolverHubPage({super.key});

  @override
  State<SolverHubPage> createState() => _SolverHubPageState();
}

class _SolverHubPageState extends State<SolverHubPage> {
  late GameMode _mode = _first();

  /// The length of the place names being solved; null until one is chosen.
  int? _placeLength;

  List<GameMode> get _modes => [
    for (final m in openModes(appState.level))
      if (GameMode.loopFor(appState.lang).contains(m)) m,
  ];

  GameMode _first() {
    final m = appState.mode;
    return _modes.contains(m) ? m : GameMode.classic;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('solver'),
        actions: [const SettingsButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 4, 19, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ModeFilter(
                      selected: _mode,
                      showAll: false,
                      modes: _modes,
                      onSelect: (m) {
                        if (m != null) setState(() => _mode = m);
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(19, 8, 19, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Caption(
                      'answers of your games in progress and of dailies you '
                      'have not finished are left out.',
                    ),
                  ),
                ),
                Expanded(child: _solver(_mode)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The solver of [m], keyed by the mode so that a change rebuilds it.
  Widget _solver(GameMode m) {
    final key = ValueKey(m);
    switch (m) {
      case GameMode.equations:
        return BankGate(
          key: key,
          equations: true,
          builder: (bank) => EquationSolverPage(
            bank: bank,
            excluded: SolverExclusions.equations(appState.eqLength, bank: bank),
          ),
        );
      case GameMode.themed:
        return BankGate(
          key: key,
          places: true,
          builder: (bank) => _places(bank),
        );
      default:
        return BankGate(key: key, builder: (bank) => _words(m, bank));
    }
  }

  Widget _words(GameMode m, WordBank bank) {
    final excluded = SolverExclusions.words(
      bank.language.code,
      appState.length,
      bank: bank,
    );
    switch (m) {
      case GameMode.quartet:
      case GameMode.relay:
        return MultiSolverPage(bank: bank, mode: m, excluded: excluded);
      case GameMode.blind:
        return BlindSolverPage(bank: bank, excluded: excluded);
      case GameMode.lockdown:
        return SolverPage(
          bank: bank,
          mode: m,
          tries: lockdownTries,
          excluded: excluded,
        );
      case GameMode.mastermind:
        // no fixed answer to hide; unlimited tries, so a large number
        return SolverPage(bank: bank, mode: m, tries: 99);
      default:
        return SolverPage(bank: bank, mode: m, excluded: excluded);
    }
  }

  /// The places solver, with a row to choose the length of the names.
  Widget _places(WordBank bank) {
    final lengths = Geography.counts.keys.toList()..sort();
    final n = lengths.contains(_placeLength)
        ? _placeLength!
        : lengths.contains(appState.length)
        ? appState.length
        : (lengths.isEmpty ? appState.length : lengths.first);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 0, 19, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in lengths) ...[
                    ChoiceChip(
                      key: ValueKey('places-$l'),
                      label: Text('$l'),
                      selected: l == n,
                      onSelected: (_) => setState(() => _placeLength = l),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SolverPage(
            key: ValueKey('places-$n'),
            bank: bank,
            mode: GameMode.themed,
            length: n,
            excluded: SolverExclusions.places(bank: bank),
          ),
        ),
      ],
    );
  }
}
