import 'app_shell.dart';

import 'package:flutter/material.dart';

import 'achievements_page.dart';
import 'clue_page.dart';
import 'daily.dart';
import 'diy.dart';
import 'first_run/first_run_flow.dart' show practiceRoute;
import 'equations.dart';
import 'drill_page.dart';
import 'game.dart';
import 'history_page.dart';
import 'learn.dart';
import 'learn_guide.dart';
import 'learn_home.dart';
import 'learn_log.dart';
import 'mode_settings_page.dart';
import 'opening_page.dart';
import 'sequence_page.dart';
import 'styles_page.dart';
import 'licences_page.dart';
import 'how_to.dart';
import 'main.dart';
import 'multi_game.dart';
import 'multi_review.dart';
import 'review.dart';
import 'game_modes_dialog.dart';
import 'playstyle_card.dart';
import 'puzzle.dart';
import 'reminders_page.dart';
import 'settings_page.dart';
import 'solver_hub.dart';
import 'ui.dart';
import 'geography.dart';
import 'modes.dart';
import 'collected_word_page.dart';
import 'collection.dart';
import 'saved_words.dart';
import 'word_page.dart';
import 'words.dart';
import 'words_page.dart';

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
  // the first game played again from the you tab
  static const firstGame = '/first-game';
  static const play = '/play';
  static const daily = '/daily';
  static const puzzle = '/puzzle';
  static const history = '/history';
  static const review = '/play/review';
  static const solver = '/solver';
  static const learn = '/learn';
  static const learnFree = '/learn/free';
  static const learnChoose = '/learn/choose';
  static const learnClosing = '/learn/closing';
  static const learnClue = '/learn/clue';
  static const learnOpening = '/learn/opening';
  static const learnSequence = '/learn/sequence';
  static const learnStyles = '/learn/styles';
  static const learnGuide = '/learn/guide';
  static const achievements = '/achievements';
  static const mastery = '/achievements/mastery';
  static const howTo = '/how-to';
  static const settings = '/settings';
  static const gameModes = '/game-modes';
  static const modeSettings = '/mode-settings';
  static const diy = '/diy';
  static const playstyle = '/playstyle';
  static const about = '/about';
  static const words = '/words';
  static const reminders = '/reminders';

  /// One saved word; it travels as the route's argument, so an address alone
  /// shows the list instead.
  static const word = '/words/entry';

  /// One collected word, which travels as a [CollectedRef].
  static const collected = '/words/collected';
}

/// The argument that tells the how-to page it is the first-visit onboarding.
const onboardingArgument = 'onboarding';

/// What the licences line and the about popup say.
const aboutText =
    'Words: wordfreq (CC BY-SA 4.0), filtered with spelling dictionaries. '
    'Definitions: Wiktionary (CC BY-SA 4.0). Font: JetBrains Mono (OFL). '
    'Icons: Tabler Icons (MIT). Every licence is listed below.';

/// The route inside an address. A link opened by the Android app arrives as
/// the whole address, `https://…/lexodle/#/puzzle?l=en…`, and the route is
/// its fragment; a plain route (`/puzzle?l=en…`) is its own.
String routeOf(String? raw) {
  final uri = Uri.tryParse(raw ?? '/');
  if (uri == null) return '/';
  if (uri.fragment.startsWith('/')) return uri.fragment;
  return uri.hasScheme ? '/' : raw ?? '/';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final full = routeOf(settings.name);
  settings = RouteSettings(name: full, arguments: settings.arguments);
  var name = Uri.tryParse(full)?.path ?? '/';
  // a learn address names its mode (/equations/learn/free): opening it chooses
  // that mode, and the page is the same as the plain /learn/free
  final segs = name.split('/').where((p) => p.isNotEmpty).toList();
  final named = segs.length >= 2 && segs[1] == 'learn'
      ? GameMode.values.where((m) => m.name == segs[0]).firstOrNull
      : null;
  if (named != null) {
    if (appState.mode != named) appState.setup(mode: named);
    name = '/${segs.skip(1).join('/')}';
  }
  // the settings keep the name they were opened with, a learn page with its
  // mode in front, so each mode's learn pages have addresses of their own
  final s = RouteSettings(
    name: name == Routes.learn || name.startsWith('${Routes.learn}/')
        ? '/${appState.mode.name}$name'
        : name,
    arguments: settings.arguments,
  );
  Route<dynamic> page(Widget w) =>
      MaterialPageRoute<void>(settings: s, builder: (_) => w);
  switch (name) {
    case Routes.play:
      return page(
        BankGate(
          places: appState.mode == GameMode.themed,
          equations: appState.mode == GameMode.equations,
          builder: (bank) => appState.mode.multi
              ? MultiGamePage(bank: bank)
              : GamePage(bank: bank, mode: appState.mode),
        ),
      );
    case Routes.daily:
      // today's word for the saved language, at the fixed daily difficulty.
      // each mode has a daily of its own: the route argument names it, and
      // the mode in view (the free play one) is only the default
      final arg = settings.arguments;
      final dailyMode = arg is GameMode ? arg : appState.mode;
      return page(
        BankGate(
          places: dailyMode == GameMode.themed,
          equations: dailyMode == GameMode.equations,
          builder: (bank) {
            if (dailyMode.multi) {
              final m = DailyMulti.of(bank, dailyMode);
              return m == null
                  ? const HomeSwitch()
                  : MultiGamePage(bank: bank, daily: m);
            }
            final d = Daily.of(bank, null, dailyMode);
            return d == null
                ? const HomeSwitch()
                : GamePage(bank: bank, daily: d, mode: dailyMode);
          },
        ),
      );
    case Routes.diy:
      // a made wordle opened by a link, or the screen that makes one
      final diy = DiyPuzzle.parse(Uri.tryParse(settings.name ?? '') ?? Uri());
      return page(diy == null ? const DiyPage() : DiyGate(puzzle: diy));
    case Routes.puzzle:
      // a daily puzzle named by a link: played as practice
      final puzzle = Puzzle.parse(Uri.tryParse(settings.name ?? '') ?? Uri());
      return page(
        puzzle == null ? const HomeSwitch() : PuzzleGate(puzzle: puzzle),
      );
    case Routes.history:
      return page(const HistoryPage());
    case Routes.words:
      return page(const WordsPage());
    case Routes.collected:
      final ref = settings.arguments;
      return page(
        ref is CollectedRef ? CollectedWordPage(ref: ref) : const WordsPage(),
      );
    case Routes.word:
      final entry = settings.arguments;
      return page(
        entry is SavedWord ? WordPage(entry: entry) : const WordsPage(),
      );
    case Routes.review:
      final record = settings.arguments;
      // a finished game cannot be rebuilt from an address
      return record is GameRecord
          ? page(ReviewPage(record: record))
          : record is MultiRecord
          ? page(MultiReviewPage(record: record))
          : page(const HomeSwitch());
    case Routes.learn:
      return page(learnGate(builder: (bank) => LearnHomePage(bank: bank)));
    case Routes.learnFree:
      return page(
        learnGate(
          page: 'free',
          builder: (bank) => LearnPage(bank: bank),
        ),
      );
    case Routes.learnChoose:
      return page(
        learnGate(
          page: 'choose',
          builder: (bank) => DrillPage(bank: bank),
        ),
      );
    case Routes.learnClue:
      return page(
        learnGate(
          page: 'clue',
          builder: (bank) => CluePage(bank: bank),
        ),
      );
    case Routes.learnClosing:
      return page(
        learnGate(
          page: 'closing',
          builder: (bank) => DrillPage(bank: bank, kind: LearnKind.closing),
        ),
      );
    case Routes.learnOpening:
      return page(
        learnGate(
          page: 'opening',
          builder: (bank) => OpeningPage(bank: bank),
        ),
      );
    case Routes.learnSequence:
      return page(
        learnGate(
          page: 'sequence',
          builder: (bank) => SequencePage(bank: bank),
        ),
      );
    case Routes.learnGuide:
      return page(ModeGuidePage(mode: appState.mode));
    case Routes.learnStyles:
      return page(
        learnGate(
          page: 'styles',
          builder: (bank) => StylesPage(bank: bank),
        ),
      );
    case Routes.solver:
      return page(const SolverHubPage());
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
    case Routes.modeSettings:
      return page(const ModeSettingsPage());
    case Routes.gameModes:
      return _dialog(s, const GameModesDialog());
    case Routes.playstyle:
      return page(const PlaystylePage());
    case Routes.reminders:
      return page(const RemindersPage());
    case Routes.about:
      return page(const LicencesPage(about: aboutText));
    case Routes.firstGame:
      return practiceRoute();
    default:
      return page(const HomeSwitch());
  }
}

/// The routes to start with for an address: its parents first, so back works.
/// A review is built only from a finished game, so by address it is just home.
List<Route<dynamic>> onGenerateInitialRoutes(String initialAddress) {
  final initial = routeOf(initialAddress);
  final path = Uri.tryParse(initial)?.path ?? '/';
  if (path == Routes.review) {
    return [onGenerateRoute(const RouteSettings(name: Routes.home))];
  }
  var parts = path.split('/').where((p) => p.isNotEmpty).toList();
  // a learn address names its mode: /equations/learn/free
  if (parts.length >= 2 &&
      parts[1] == 'learn' &&
      GameMode.values.any((m) => m.name == parts[0])) {
    final m = GameMode.values.firstWhere((m) => m.name == parts[0]);
    if (appState.mode != m) appState.setup(mode: m);
    parts = parts.skip(1).toList();
  }
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
  Routes.diy,
  Routes.play,
  Routes.daily,
  Routes.puzzle,
  Routes.history,
  Routes.mastery,
  Routes.solver,
  Routes.learn,
  Routes.learnFree,
  Routes.learnChoose,
  Routes.learnClosing,
  Routes.learnClue,
  Routes.learnOpening,
  Routes.learnSequence,
  Routes.learnStyles,
  Routes.learnGuide,
  Routes.achievements,
  Routes.howTo,
  Routes.settings,
  Routes.gameModes,
  Routes.modeSettings,
  Routes.playstyle,
  Routes.about,
  Routes.words,
  Routes.reminders,
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
/// The gate of a learn page: the words of the mode in view (the equations, the
/// places, or the words of the language).
Widget learnGate({
  required Widget Function(WordBank bank) builder,
  String? page,
}) => BankGate(
  equations: appState.mode == GameMode.equations,
  places: appState.mode == GameMode.themed,
  builder: (bank) => Builder(
    // only the page on top names the tab: the pages under it (a learn page
    // under the guide) are built later, when their words have come, and would
    // otherwise rename it
    builder: (context) => (ModalRoute.of(context)?.isCurrent ?? true)
        ? Title(
            // the tab says where you are: classic/learn, equations/learn/opening
            title: '${appState.mode.name}/learn${page == null ? '' : '/$page'}',
            color: Theme.of(context).colorScheme.surface,
            child: builder(bank),
          )
        : builder(bank),
  ),
);

class BankGate extends StatefulWidget {
  const BankGate({
    super.key,
    required this.builder,
    this.places = false,
    this.equations = false,
  });
  final Widget Function(WordBank bank) builder;

  /// Whether the words are the equations of the equations mode.
  final bool equations;

  /// Whether the words are the place names of the themed wordle, in English.
  final bool places;

  @override
  State<BankGate> createState() => _BankGateState();
}

class _BankGateState extends State<BankGate> {
  Future<WordBank>? _bank;

  Future<WordBank> _load() async {
    final langs = await WordBank.languages();
    if (widget.places) {
      return Geography.load(langs.firstWhere((l) => l.code == 'en'));
    }
    final lang = langs.firstWhere(
      (l) => l.code == appState.lang,
      orElse: () => langs.first,
    );
    return widget.equations ? Equations.load(lang) : WordBank.load(lang);
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
    if (found.isEmpty) return null;
    // a themed puzzle's word is a place, not a word of the list
    return widget.puzzle.mode == GameMode.themed
        ? Geography.load(found.first)
        : WordBank.load(found.first);
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
        if (bank == null) return const HomeSwitch();
        final p = widget.puzzle;
        final answers = p.answersIn(bank);
        if (answers == null || answers.isEmpty) return const HomeSwitch();
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
