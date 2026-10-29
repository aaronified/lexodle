import 'package:flutter/material.dart';

import 'achievements_page.dart';
import 'daily.dart';
import 'game.dart';
import 'history_page.dart';
import 'learn.dart';
import 'licences_page.dart';
import 'home.dart';
import 'how_to.dart';
import 'main.dart';
import 'multi_game.dart';
import 'multi_review.dart';
import 'multi_solver.dart';
import 'review.dart';
import 'game_modes_dialog.dart';
import 'playstyle_card.dart';
import 'puzzle.dart';
import 'settings_page.dart';
import 'solver.dart';
import 'ui.dart';
import 'words.dart';

/// Every screen has an address, so the browser's refresh and back buttons work
/// as they do on any site. The web build uses the hash strategy
/// (`index.html#/play`), which needs no server rewrite, so it also works on a
/// static host; on Android the same names drive the ordinary back stack.
///
/// Addresses nest: `/play/review` sits on `/play`, which sits on `/`. A page
/// opened by address (a refresh or a shared link) is built with those parents
/// under it, so back goes where it would have gone.
class Routes {
  const Routes._();
  static const home = '/';
  static const play = '/play';
  static const daily = '/daily';
  static const puzzle = '/puzzle';
  static const history = '/history';
  static const review = '/play/review';
  static const solver = '/solver';
  static const learn = '/learn';
  static const achievements = '/achievements';
  static const mastery = '/achievements/mastery';
  static const howTo = '/how-to';
  static const settings = '/settings';
  static const gameModes = '/game-modes';
  static const playstyle = '/playstyle';
  static const about = '/about';
}

/// The argument that tells the how-to page it is the first-visit onboarding.
const onboardingArgument = 'onboarding';

/// What the licences line and the about popup say.
const aboutText =
    'Words: wordfreq (CC BY-SA 4.0), filtered with spelling dictionaries. '
    'Definitions: Wiktionary (CC BY-SA 4.0). Font: JetBrains Mono (OFL). '
    'Icons: Tabler Icons (MIT). Every licence is listed below.';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = Uri.tryParse(settings.name ?? '/')?.path ?? '/';
  // the settings keep the name they were opened with
  final s = RouteSettings(name: name, arguments: settings.arguments);
  Route<dynamic> page(Widget w) =>
      MaterialPageRoute<void>(settings: s, builder: (_) => w);
  switch (name) {
    case Routes.play:
      return page(
        BankGate(
          builder: (bank) => appState.mode.multi
              ? MultiGamePage(bank: bank)
              : GamePage(bank: bank, mode: appState.mode),
        ),
      );
    case Routes.daily:
      // today's word for the saved language, at the fixed daily difficulty
      return page(
        BankGate(
          builder: (bank) {
            // each mode has a daily of its own: the mode in view decides
            final mode = appState.mode;
            if (mode.multi) {
              final m = DailyMulti.of(bank, mode);
              return m == null
                  ? const HomePage()
                  : MultiGamePage(bank: bank, daily: m);
            }
            final d = Daily.of(bank, null, mode);
            return d == null
                ? const HomePage()
                : GamePage(bank: bank, daily: d, mode: mode);
          },
        ),
      );
    case Routes.puzzle:
      // a daily puzzle named by a link: played as practice
      final puzzle = Puzzle.parse(Uri.tryParse(settings.name ?? '') ?? Uri());
      return page(
        puzzle == null ? const HomePage() : PuzzleGate(puzzle: puzzle),
      );
    case Routes.history:
      return page(const HistoryPage());
    case Routes.review:
      final record = settings.arguments;
      // a finished game cannot be rebuilt from an address
      return record is GameRecord
          ? page(ReviewPage(record: record))
          : record is MultiRecord
          ? page(MultiReviewPage(record: record))
          : page(const HomePage());
    case Routes.learn:
      return page(BankGate(builder: (bank) => LearnPage(bank: bank)));
    case Routes.solver:
      // the solver follows the mode: one board, or four that share the guesses
      return page(
        BankGate(
          builder: (bank) => appState.mode.multi
              ? MultiSolverPage(bank: bank)
              : SolverPage(bank: bank),
        ),
      );
    case Routes.achievements:
      return page(const AchievementsPage());
    case Routes.mastery:
      return page(const MasteryPage());
    case Routes.howTo:
      return page(
        HowToPage(onboarding: settings.arguments == onboardingArgument),
      );
    case Routes.settings:
      return page(const SettingsPage());
    case Routes.gameModes:
      return _dialog(s, const GameModesDialog());
    case Routes.playstyle:
      return _dialog(s, const PlaystyleDialog());
    case Routes.about:
      return page(const LicencesPage(about: aboutText));
    default:
      return page(const HomePage());
  }
}

/// The routes to start with for an address: its parents first, so back works.
/// A review is built only from a finished game, so by address it is just home.
List<Route<dynamic>> onGenerateInitialRoutes(String initial) {
  final path = Uri.tryParse(initial)?.path ?? '/';
  if (path == Routes.review) {
    return [onGenerateRoute(const RouteSettings(name: Routes.home))];
  }
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final query = Uri.tryParse(initial)?.query ?? '';
  return [
    onGenerateRoute(const RouteSettings(name: Routes.home)),
    for (var i = 1; i <= parts.length; i++)
      if (_known.contains('/${parts.take(i).join('/')}'))
        onGenerateRoute(
          RouteSettings(
            // the last page keeps its query: a puzzle link is all in it
            name:
                '/${parts.take(i).join('/')}'
                '${i == parts.length && query.isNotEmpty ? '?$query' : ''}',
          ),
        ),
  ];
}

const _known = {
  Routes.play,
  Routes.daily,
  Routes.puzzle,
  Routes.history,
  Routes.mastery,
  Routes.solver,
  Routes.learn,
  Routes.achievements,
  Routes.howTo,
  Routes.settings,
  Routes.gameModes,
  Routes.playstyle,
  Routes.about,
};

/// A popup as a route. The scrim is tinted from the theme (no colour is
/// hard-coded) and a tap on it closes the popup, as a dialog's barrier does.
Route<void> _dialog(RouteSettings settings, Widget dialog) =>
    RawDialogRoute<void>(
      settings: settings,
      barrierLabel: 'close',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, _, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
          child: SafeArea(
            child: Center(
              // taps on the popup itself must not reach the scrim
              child: GestureDetector(onTap: () {}, child: dialog),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// Loads the word list of the saved language before building a screen that
/// needs it, waiting first for the saved settings, since a page opened by
/// address (a refresh) starts before they are read.
class BankGate extends StatefulWidget {
  const BankGate({super.key, required this.builder});
  final Widget Function(WordBank bank) builder;

  @override
  State<BankGate> createState() => _BankGateState();
}

class _BankGateState extends State<BankGate> {
  Future<WordBank>? _bank;

  Future<WordBank> _load() async {
    final langs = await WordBank.languages();
    final lang = langs.firstWhere(
      (l) => l.code == appState.lang,
      orElse: () => langs.first,
    );
    return WordBank.load(lang);
  }

  Widget _waiting(String text) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Caption(text)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.loaded) return _waiting('loading…');
        return FutureBuilder<WordBank>(
          future: _bank ??= _load(),
          builder: (context, snap) {
            if (snap.hasError) return _waiting('could not load the words');
            final bank = snap.data;
            return bank == null ? _waiting('loading…') : widget.builder(bank);
          },
        );
      },
    );
  }
}

/// Opens the puzzle a link names: loads the language it is in (whatever the
/// player's own language is), then plays that day's daily of that mode as
/// practice. A language the app does not have goes home.
class PuzzleGate extends StatefulWidget {
  const PuzzleGate({super.key, required this.puzzle});
  final Puzzle puzzle;

  @override
  State<PuzzleGate> createState() => _PuzzleGateState();
}

class _PuzzleGateState extends State<PuzzleGate> {
  late final Future<WordBank?> _bank = _load();

  Future<WordBank?> _load() async {
    final langs = await WordBank.languages();
    final found = langs.where((l) => l.code == widget.puzzle.lang);
    return found.isEmpty ? null : WordBank.load(found.first);
  }

  Widget _waiting(String text) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Caption(text)),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WordBank?>(
      future: _bank,
      builder: (context, snap) {
        if (snap.hasError) return _waiting('could not load the words');
        if (snap.connectionState != ConnectionState.done) {
          return _waiting('loading…');
        }
        final bank = snap.data;
        if (bank == null) return const HomePage();
        final p = widget.puzzle;
        final answers = p.answersIn(bank);
        if (answers == null || answers.isEmpty) return const HomePage();
        if (p.mode.multi) {
          return MultiGamePage(
            bank: bank,
            practice: true,
            replay: p.guesses,
            daily: DailyMulti(
              '',
              p.mode,
              answers,
              length: p.length,
              tries: p.tries,
            ),
          );
        }
        return GamePage(
          bank: bank,
          mode: p.mode,
          practice: true,
          replay: p.guesses,
          daily: Daily('', answers.first, length: p.length, tries: p.tries),
        );
      },
    );
  }
}
