import 'modes.dart';

/// The slow introduction: what a new player meets, and on which game of theirs it
/// opens, one thing at a time. A veteran has all of it from the start.
enum StepKind { mode, feature }

class LadderStep {
  const LadderStep(this.games, this.kind, this.name, this.note, {this.mode});

  /// The number of games played when it opens.
  final int games;
  final StepKind kind;
  final String name;
  final String note;

  /// The mode it opens, for a [StepKind.mode].
  final GameMode? mode;
}

/// In order of [LadderStep.games]. The copy is a draft.
const ladder = <LadderStep>[
  LadderStep(
    2,
    StepKind.feature,
    'skill, luck and risk',
    'a score for each game, on the review screen after it',
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
    6,
    StepKind.feature,
    'every mode',
    'the game modes screen names all eight modes',
  ),
  LadderStep(
    7,
    StepKind.mode,
    'lockdown',
    'greens lock, bad words cost hearts',
    mode: GameMode.lockdown,
  ),
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
  for (final m in GameMode.values)
    if (isOpen(m, games, veteran: veteran)) m,
];

/// What opens on exactly game [games]: the "new" cards of Today.
List<LadderStep> justOpened(int games) => [
  for (final s in ladder)
    if (s.games == games) s,
];

/// What opens next after [games] played, or null when everything is open.
LadderStep? nextStep(int games) {
  for (final s in ladder) {
    if (s.games > games) return s;
  }
  return null;
}
