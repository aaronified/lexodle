import 'app_log.dart';
import 'daily.dart';
import 'main.dart';
import 'modes.dart';
import 'words.dart';

/// The answers a solver must not know, so that it cannot solve a game in
/// progress: the target of every unfinished game saved on this device (a free
/// game kept for resuming) and today's daily answer of every mode this player
/// has not finished yet. A finished daily is not excluded: the player knows its
/// answer. The mastermind has no fixed answer, so it adds nothing.
///
/// A daily is drawn from the date alone, so working it out needs the bank it is
/// drawn from: pass [bank] (the language's words, the equations or the places,
/// as the solver has it). Without one only the saved games are found.
///
/// Nothing here throws: a failure is logged (its type only, never a word) and
/// what was found so far is returned.
class SolverExclusions {
  const SolverExclusions._();

  /// The modes played with the words of a language and a daily of their own.
  static const _wordModes = [
    GameMode.classic,
    GameMode.lockdown,
    GameMode.blind,
    GameMode.quartet,
    GameMode.relay,
  ];

  /// The words of [lang] and [length] that a solver of a word mode must not
  /// know. [bank] is [lang]'s word bank, for the dailies.
  static Set<String> words(String lang, int length, {WordBank? bank}) {
    final out = <String>{};
    _saved(
      out,
      (l, m, n) => l == lang && n == length && _wordModes.contains(m),
    );
    if (bank != null && bank.language.code == lang && length == dailyLength) {
      for (final m in _wordModes) {
        _daily(out, bank, m, length);
      }
    }
    return out;
  }

  /// The equations of [length] that an equations solver must not know. [bank]
  /// is the equations bank, for the daily. An equation is the same in every
  /// language, so the saved games of all of them count.
  static Set<String> equations(int length, {WordBank? bank}) {
    final out = <String>{};
    _saved(out, (l, m, n) => m == GameMode.equations && n == length);
    if (bank != null) _daily(out, bank, GameMode.equations, length);
    return out;
  }

  /// The places that a geography solver must not know, of any length. [bank] is
  /// the places bank, for the daily.
  static Set<String> places({WordBank? bank}) {
    final out = <String>{};
    _saved(out, (l, m, n) => m == GameMode.themed);
    if (bank != null) _daily(out, bank, GameMode.themed, null);
    return out;
  }

  /// Adds to [out] the answers of the saved free games [want] picks, by
  /// language, mode and length. Free games are kept under
  /// `p|language|mode|length|tries`: a word as the answer, or a list of them
  /// for a quartet or a relay race.
  static void _saved(
    Set<String> out,
    bool Function(String lang, GameMode mode, int length) want,
  ) {
    try {
      for (final e in appState.progress.entries) {
        try {
          final k = e.key.split('|');
          if (k.length < 5 || k[0] != 'p') continue;
          final mode = GameMode.values.where((m) => m.name == k[2]).firstOrNull;
          final n = int.tryParse(k[3]);
          if (mode == null || mode == GameMode.mastermind || n == null) {
            continue;
          }
          if (!want(k[1], mode, n)) continue;
          final a = e.value['a'];
          for (final w in a is List ? a : [a]) {
            if (w is String && w.isNotEmpty) out.add(w);
          }
        } catch (err) {
          appLog.w('solver exclusions', 'bad saved game: ${err.runtimeType}');
        }
      }
    } catch (err) {
      appLog.w('solver exclusions', 'could not read saves: ${err.runtimeType}');
    }
  }

  /// Adds to [out] today's daily answer(s) of [mode] in [bank]'s language, when
  /// this player has not finished it and the answers have [length] (any when
  /// null).
  static void _daily(
    Set<String> out,
    WordBank bank,
    GameMode mode,
    int? length,
  ) {
    try {
      final today = dailyDate();
      if (appState.dailyFor(bank.language.code, today, mode)?.over ?? false) {
        return;
      }
      final answers = mode.multi
          ? DailyMulti.of(bank, mode, today)?.answers ?? const <String>[]
          : [Daily.of(bank, today, mode)?.answer ?? ''];
      for (final w in answers) {
        if (w.isNotEmpty && (length == null || w.length == length)) out.add(w);
      }
    } catch (err) {
      appLog.w(
        'solver exclusions',
        'could not draw a daily: ${err.runtimeType}',
      );
    }
  }
}
