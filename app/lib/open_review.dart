import 'package:flutter/material.dart';

import 'app_log.dart';
import 'equations.dart';
import 'geography.dart';
import 'history.dart';
import 'modes.dart';
import 'replay.dart';
import 'routes.dart';
import 'words.dart';

/// Opens the review of the game [g] kept in the history, rebuilt from its
/// guesses (the way the history list does it). Returns why it could not, or
/// null when it did (or when the game has nothing to review).
Future<String?> openGameReview(
  BuildContext context,
  History history,
  GameRow g,
  Language lang,
) async {
  // (a practice game timed out before any guess has nothing to review)
  if (history.guessesOf(g.id).isEmpty) return null;
  final navigator = Navigator.of(context);
  try {
    final bank = g.mode == GameMode.themed
        ? await Geography.load(lang)
        : g.mode == GameMode.equations
        ? await Equations.load(lang)
        : await WordBank.load(lang);
    final rows = history.guessesOf(g.id);
    final record = !g.mode.multi
        ? replayClassic(bank, g, rows)
        : replayMulti(bank, g, rows);
    if (!navigator.mounted) return null;
    await navigator.pushNamed(Routes.review, arguments: record);
    return null;
  } catch (e) {
    appLog.w('review', 'could not rebuild a game: ${e.runtimeType}');
    return 'could not rebuild that game';
  }
}

/// The games kept for the dailies of [mode] in [lang], by date: where a day has
/// several, the scored one, the latest.
Map<String, GameRow> dailyGamesOf(History history, String lang, GameMode mode) {
  final out = <String, GameRow>{};
  try {
    for (final g in history.games) {
      if (g.daily.isEmpty || g.lang != lang || g.mode != mode) continue;
      final best = out[g.daily];
      if (best == null ||
          (best.unscored && !g.unscored) ||
          (best.unscored == g.unscored && g.at >= best.at)) {
        out[g.daily] = g;
      }
    }
  } catch (e) {
    appLog.w('review', 'could not list the daily games: ${e.runtimeType}');
  }
  return out;
}
