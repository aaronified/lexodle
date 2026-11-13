import '../main.dart' show appState;

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

/// Whether the first run is still to be shown: it is not finished, and the
/// player has no history (a veteran never sees it).
bool firstRunDue() =>
    !appState.firstRunDone &&
    appState.stats.played == 0 &&
    !appState.lex.veteran;
