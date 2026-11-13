import '../ladder.dart' show openModes;
import '../main.dart' show appState;
import '../modes.dart';

/// Small facts the first run shares with the rest of the app.
class FirstRunSignals {
  const FirstRunSignals._();

  /// Set when the first run ends by "i know how lexodle works": Today opens the
  /// choose-dailies sheet once, then clears it.
  static bool chooseDailiesPending = false;

  /// Takes the flag: true once, then false.
  static bool takeChooseDailies() {
    final was = chooseDailiesPending;
    chooseDailiesPending = false;
    return was;
  }
}

/// Whether choosing dailies means anything yet: at least two modes are open.
bool twoModesOpen() {
  final loop = GameMode.loopFor(appState.lang);
  return openModes(appState.level).where(loop.contains).length >= 2;
}

/// Whether the first run is still to be shown: it is not finished, and the
/// player has no history (a veteran never sees it).
bool firstRunDue() =>
    !appState.firstRunDone &&
    appState.stats.played == 0 &&
    !appState.lex.veteran;
