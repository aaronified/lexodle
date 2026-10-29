import 'package:flutter/material.dart';

import 'mode_wheel.dart' show modeIconName;
import 'modes.dart';
import 'ui.dart';
import 'words.dart';

/// The title of a game screen, the same in every mode and centred: the flag of
/// the language, the icon of the mode, and the date of a daily or else the
/// length and the tries ("5 · 6 tries"). No language name and no word "daily":
/// the date says it is one.
Widget gameTitle(
  BuildContext context, {
  required Language language,
  required GameMode mode,
  required String text,
}) {
  final c = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      FlagBadge(language.flag, size: 16),
      const SizedBox(width: 10),
      TablerIcon(modeIconName(mode), size: headerIconSize, color: c.primary),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          key: const ValueKey('game-title'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
        ),
      ),
    ],
  );
}

/// What the title says after the icon: the daily's date, or the length and
/// the tries. [date] is empty for an ordinary game and for a puzzle from a link.
String gameTitleText({
  required String date,
  required int length,
  required int tries,
}) => date.isNotEmpty ? date : '$length · $tries tries';
