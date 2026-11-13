import 'modes.dart';

/// The slow introduction: what a new player meets, and on which game of theirs it
/// opens, one thing at a time. A veteran has all of it from the start.
enum StepKind { mode, feature }

class LadderStep {
  const LadderStep(
    this.games,
    this.kind,
    this.name,
    this.note, {
    this.mode,
    this.card = true,
  });

  /// The number of games played when it opens.
  final int games;
  final StepKind kind;
  final String name;
  final String note;

  /// The mode it opens, for a [StepKind.mode].
  final GameMode? mode;

  /// Whether a Today card may introduce it.
  final bool card;
}

/// In order of [LadderStep.games]. The copy is a draft.
const ladder = <LadderStep>[
  LadderStep(
    0,
    StepKind.feature,
    'theme',
    'light, dark or the system',
    card: false,
  ),
  LadderStep(
    0,
    StepKind.feature,
    'language',
    'the language of the words',
    card: false,
  ),
  LadderStep(
    0,
    StepKind.feature,
    'settings',
    'the app settings, in you',
    card: false,
  ),
  LadderStep(
    0,
    StepKind.feature,
    'backup',
    'save and restore your data',
    card: false,
  ),
  LadderStep(
    0,
    StepKind.feature,
    "what's new",
    'what changed in this version',
    card: false,
  ),
  LadderStep(
    1,
    StepKind.feature,
    'lex and hints',
    'lex, and a hint for a lex',
    card: false,
  ),
  LadderStep(
    1,
    StepKind.feature,
    'how to play',
    'how to play each mode, in learn',
    card: false,
  ),
  LadderStep(
    2,
    StepKind.feature,
    'skill, luck and risk',
    'a score for each game, on the review screen after it',
  ),
  LadderStep(
    2,
    StepKind.feature,
    'reminders',
    'a daily nudge, in you',
    card: false,
  ),
  LadderStep(
    3,
    StepKind.feature,
    'achievements',
    'medals for what you do. open them in you',
  ),
  LadderStep(
    4,
    StepKind.mode,
    'quartet',
    'four words at once',
    mode: GameMode.quartet,
  ),
  LadderStep(
    5,
    StepKind.feature,
    'your numbers',
    'history and your playstyle, in you',
  ),
  LadderStep(
    5,
    StepKind.feature,
    'friends',
    'play the same daily as a friend',
    card: false,
  ),
  LadderStep(
    6,
    StepKind.feature,
    'every mode',
    'choose dailies names all the modes',
  ),
  LadderStep(
    6,
    StepKind.feature,
    'solver',
    'find the word that fits',
    card: false,
  ),
  LadderStep(6, StepKind.feature, 'diy', 'make your own daily', card: false),
  LadderStep(
    6,
    StepKind.feature,
    'mode settings',
    'free play settings of each mode',
    card: false,
  ),
  LadderStep(
    7,
    StepKind.mode,
    'lockdown',
    'greens lock, bad words cost hearts',
    mode: GameMode.lockdown,
  ),
  LadderStep(7, StepKind.feature, 'support', 'support the app', card: false),
  LadderStep(
    9,
    StepKind.feature,
    'my words',
    'save and collect the words you meet',
  ),
  LadderStep(
    12,
    StepKind.mode,
    'relay race',
    'four words, one after the other',
    mode: GameMode.relay,
  ),
  LadderStep(
    14,
    StepKind.mode,
    'blind',
    'only counts, no tile colours',
    mode: GameMode.blind,
  ),
  LadderStep(
    16,
    StepKind.mode,
    'equations',
    'find the true equation',
    mode: GameMode.equations,
  ),
  LadderStep(
    19,
    StepKind.mode,
    'mastermind',
    'the word dodges you',
    mode: GameMode.mastermind,
  ),
  LadderStep(
    22,
    StepKind.mode,
    'geography',
    'place names, in english',
    mode: GameMode.themed,
  ),
  LadderStep(24, StepKind.feature, 'learn', 'drills for every mode, in learn'),
];

/// The game on which [m] opens: classic is open from the first.
int gamesToOpen(GameMode m) {
  for (final s in ladder) {
    if (s.mode == m) return s.games;
  }
  return 1;
}

/// Whether [m] is open to a player with [games] played ([veteran]: everything).
bool isOpen(GameMode m, int games, {bool veteran = false}) =>
    veteran || m == GameMode.classic || games >= gamesToOpen(m);

/// The modes open to a player with [games] played, in the app's own order.
List<GameMode> openModes(int games, {bool veteran = false}) => [
  for (final m in GameMode.loopFor('en'))
    if (isOpen(m, games, veteran: veteran)) m,
];

/// The games at which the step [name] opens.
int gamesOf(String name) {
  for (final s in ladder) {
    if (s.name == name) return s.games;
  }
  assert(() {
    throw StateError('no ladder step named $name');
  }());
  return 1 << 30;
}

/// Whether the step [name] is open at teaching [level] ([veteran]: everything).
bool stepOpen(String name, int level, {bool veteran = false}) =>
    veteran || level >= gamesOf(name);

/// The steps with a card that a player at [level] has reached: those that opened
/// at a game, not at the start.
List<LadderStep> reached(int level, {bool veteran = false}) => [
  for (final s in ladder)
    if (s.card && s.games > 0 && (veteran || s.games <= level)) s,
];

/// What opens next after [games] played, or null when everything is open.
LadderStep? nextStep(int games) {
  for (final s in ladder) {
    if (s.games > games) return s;
  }
  return null;
}
