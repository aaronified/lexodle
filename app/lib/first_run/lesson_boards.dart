import 'dart:math';

import 'package:flutter/material.dart';

import '../equations.dart' show faceOf;
import '../geography.dart';
import '../guess_input.dart';
import '../logic.dart';
import '../modes.dart';
import '../place_info.dart';
import '../swipe_clear.dart';
import '../ui.dart';
import 'lesson_game.dart';

/// A tile of a lesson, drawn as the real game draws it (game.dart): the
/// feedback colours, the cursor in the ink colour, a lock in the top right
/// corner: the player's own in the accent, the game's own (lockdown) green.
class LessonTile extends StatelessWidget {
  const LessonTile(
    this.ch, {
    super.key,
    this.mark,
    required this.size,
    this.active = false,
    this.cursor = false,
    this.locked = false,
    this.fixed = false,
    this.onTap,
  });

  final String ch;
  final Mark? mark;
  final double size;
  final bool active, cursor, locked, fixed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Color? fill;
    Color fg = c.onSurface;
    Color border = active
        ? c.onSurface.withValues(alpha: .5)
        : c.outlineVariant;
    final lockColor = fixed ? markColors(c, Mark.correct).$1 : c.primary;
    if (mark != null) {
      (fill, fg) = markColors(c, mark!);
      border = markBorder(c, mark!);
    } else if (ch.isNotEmpty) {
      border = locked ? lockColor : c.onSurface;
    }
    var borderWidth = 1.0;
    if (cursor) {
      border = c.onSurface;
      borderWidth = 2;
    }
    final isBlank = ch == GuessInput.blank;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: borderWidth),
          borderRadius: BorderRadius.circular(3),
        ),
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                isBlank ? '_' : faceOf(ch),
                style: TextStyle(
                  fontSize: size * .5,
                  fontWeight: FontWeight.bold,
                  color: isBlank ? fg.withValues(alpha: dimAlpha) : fg,
                ),
              ),
              if (locked)
                Positioned(
                  top: 3,
                  right: 3,
                  child: TablerIcon(
                    'lock',
                    key: const ValueKey('locked'),
                    size: size * .22,
                    color: lockColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The board of the one-board lessons: lockdown, blind, equations, mastermind
/// and geography. Submitted rows, then the row being typed (unless the game is
/// done); no empty rows and no tries.
class LessonBoard extends StatelessWidget {
  const LessonBoard({
    super.key,
    required this.game,
    required this.input,
    required this.onSelect,
    required this.onClear,
    this.onLockGreens,
    this.onPencil,
    this.fixAt,
    this.deduced = const {},
  });

  final LessonGame game;
  final GuessInput input;
  final void Function(int) onSelect;
  final VoidCallback onClear;
  final VoidCallback? onLockGreens;

  /// A blind game: a tap on tile [i] of submitted row [r].
  final void Function(int r, int i)? onPencil;

  /// The tile that has the one-letter-fix arrow under it.
  final int? fixAt;

  /// A blind game's counts that settle letters outright.
  final Map<String, Mark> deduced;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final len = game.length;
    final blind = game.mode == GameMode.blind;
    final themed = game.mode == GameMode.themed;
    final lockdown = game.mode == GameMode.lockdown;
    final rows = game.boards[0];
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        const dotSlot = 26.0;
        final tile = blind
            ? min(56.0, (box.maxWidth - 32 - gap * (len - 1) - 14) / (len + 2))
            : min(
                56.0,
                (box.maxWidth -
                        32 -
                        (themed ? 2 * dotSlot : 0) -
                        gap * (len - 1)) /
                    len,
              );

        Widget submitted(int r) {
          final row = rows[r];
          Widget line = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < len; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                LessonTile(
                  row.word[i],
                  mark: blind
                      ? game.pencil.shown(row.word[i], i, deduced)
                      : row.marks[i],
                  size: tile,
                  key: ValueKey('tile-$r-$i'),
                  onTap: blind && onPencil != null
                      ? () => onPencil!(r, i)
                      : null,
                ),
              ],
            ],
          );
          if (blind) {
            Widget count(int n, Mark m, String kind) => Container(
              key: ValueKey('count-$r-$kind'),
              width: tile,
              height: tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: markColors(c, m).$1,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: tile * .5,
                  fontWeight: FontWeight.bold,
                  color: markColors(c, m).$2,
                ),
              ),
            );
            line = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                line,
                const SizedBox(width: 8),
                count(row.green, Mark.correct, 'g'),
                const SizedBox(width: 6),
                count(row.yellow, Mark.present, 'y'),
              ],
            );
          } else if (themed) {
            final place = Geography.placeOf(row.word);
            line = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: dotSlot),
                line,
                SizedBox(
                  width: dotSlot,
                  child: place == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: PlaceDot(place, key: ValueKey('place-dot-$r')),
                        ),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: line,
          );
        }

        Widget current() {
          Widget line = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < len; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    LessonTile(
                      input.slot(i),
                      size: tile,
                      active: true,
                      key: ValueKey('tile-${rows.length}-$i'),
                      cursor: i == input.cursor,
                      locked: input.isLocked(i),
                      fixed: input.isFixed(i),
                      onTap: () => onSelect(i),
                    ),
                    if (i == fixAt)
                      Positioned(
                        top: tile + 2,
                        child: Text(
                          '↑ change',
                          key: const ValueKey('fix-arrow'),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 11, color: c.primary),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
          if (blind) {
            // the room of the two counts, so the row stays where it is
            line = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                line,
                SizedBox(width: 8 + 6 + 2 * tile),
              ],
            );
          } else if (themed) {
            line = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: dotSlot),
                line,
                const SizedBox(width: dotSlot),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: SwipeClear(onClear: onClear, child: line),
          );
        }

        return SingleChildScrollView(
          key: const ValueKey('boards-scroll'),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          child: Center(
            child: Column(
              children: [
                if (rows.isNotEmpty)
                  GestureDetector(
                    key: const ValueKey('greens-area'),
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: lockdown || blind ? null : onLockGreens,
                    child: Column(
                      children: [
                        for (var r = 0; r < rows.length; r++) submitted(r),
                      ],
                    ),
                  ),
                if (!game.done) current(),
                if (fixAt != null) const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The boards of the quartet and the relay: a two by two, as the real game
/// draws them, with no empty rows. A relay's later words wait dimmed.
class LessonMultiBoard extends StatelessWidget {
  const LessonMultiBoard({
    super.key,
    required this.game,
    required this.input,
    required this.onSelect,
    required this.onClear,
    required this.onLockGreens,
  });

  final LessonGame game;
  final GuessInput input;
  final void Function(int) onSelect;
  final VoidCallback onClear;
  final void Function(int board) onLockGreens;

  @override
  Widget build(BuildContext context) {
    final len = game.length;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 3.0;
        final boardWidth = (box.maxWidth - 32 - 14) / 2;
        final tile = min(40.0, (boardWidth - gap * (len - 1)) / len);
        return SingleChildScrollView(
          key: const ValueKey('boards-scroll'),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          child: Column(
            children: [
              for (var row = 0; row < 4; row += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _board(context, row, tile, gap),
                      _board(context, row + 1, tile, gap),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _board(BuildContext context, int i, double tile, double gap) {
    final len = game.length;
    final rows = game.boards[i];
    final live = game.isLive(i);
    final relay = game.mode == GameMode.relay;
    // a relay word that has not come yet waits, dimmed
    final waiting = relay && !game.solved[i] && i != game.active && !game.done;
    Widget tileRow(
      int r,
      String Function(int) ch,
      Mark? Function(int) mark, {
      bool typing = false,
    }) {
      final line = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < len; k++) ...[
            if (k > 0) SizedBox(width: gap),
            LessonTile(
              ch(k),
              mark: mark(k),
              size: tile,
              active: typing,
              key: ValueKey('b$i-tile-$r-$k'),
              cursor: typing && k == input.cursor,
              locked: typing && input.isLocked(k),
              onTap: typing ? () => onSelect(k) : null,
            ),
          ],
        ],
      );
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: typing ? SwipeClear(onClear: onClear, child: line) : line,
      );
    }

    final caption = game.solved[i]
        ? '${i + 1} · solved in ${rows.length}'
        : relay && live
        ? '${i + 1} · now'
        : '${i + 1}';
    return Opacity(
      opacity: waiting ? .35 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: tile * len + gap * (len - 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Caption(caption, key: ValueKey('board-caption-$i')),
              ),
            ),
          ),
          if (rows.isNotEmpty)
            GestureDetector(
              key: ValueKey('greens-area-$i'),
              behavior: HitTestBehavior.opaque,
              onDoubleTap: live ? () => onLockGreens(i) : null,
              child: Column(
                children: [
                  for (var r = 0; r < rows.length; r++)
                    tileRow(r, (k) => rows[r].word[k], (k) => rows[r].marks[k]),
                ],
              ),
            ),
          if (live)
            tileRow(rows.length, input.slot, (_) => null, typing: true)
          else if (waiting && rows.isEmpty)
            tileRow(0, (_) => '', (_) => null),
        ],
      ),
    );
  }
}
