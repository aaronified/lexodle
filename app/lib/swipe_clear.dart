import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import 'haptics.dart';

/// A swipe from right to left over [child], the row being typed, calls
/// [onClear]: far enough, or fast enough, to be meant. Taps pass through to the
/// tiles.
class SwipeClear extends StatefulWidget {
  const SwipeClear({super.key, required this.onClear, required this.child});

  final VoidCallback onClear;
  final Widget child;

  /// How far (logical pixels) a slow swipe goes, and how fast (pixels a second)
  /// a short one.
  static const distance = 60.0;
  static const speed = 500.0;

  /// Whether a swipe that moved [dx] (negative is to the left) and ended at
  /// [velocity] is a clear.
  static bool counts(double dx, double velocity) =>
      dx <= -distance || (dx < -20 && velocity <= -speed);

  @override
  State<SwipeClear> createState() => _SwipeClearState();
}

class _SwipeClearState extends State<SwipeClear> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => _dx = 0,
    onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
    onHorizontalDragEnd: (d) {
      if (SwipeClear.counts(_dx, d.primaryVelocity ?? 0)) widget.onClear();
      _dx = 0;
    },
    child: widget.child,
  );
}

/// A drag along [child], the on-screen keyboard, moves the cursor of the row
/// being typed, as a drag along the space bar does on a phone's keyboard: one
/// tile for each [step] pixels, to the right or to the left with the finger,
/// each with a tick. A tap on a key still types it.
class CursorDrag extends StatefulWidget {
  const CursorDrag({super.key, required this.onMove, required this.child});

  /// Moves the cursor by this many tiles (negative is to the left).
  final void Function(int by) onMove;
  final Widget child;

  /// How far a finger goes for one tile, in logical pixels.
  static const step = 26.0;

  /// The whole tiles in [travel] pixels of drag (the rest stays to be carried).
  static int tiles(double travel) => (travel / step).truncate();

  @override
  State<CursorDrag> createState() => _CursorDragState();
}

class _CursorDragState extends State<CursorDrag> {
  double _travel = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    // tracked from where the finger went down, so it follows it 1:1
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: (_) => _travel = 0,
    onHorizontalDragUpdate: (d) {
      _travel += d.delta.dx;
      final n = CursorDrag.tiles(_travel);
      if (n == 0) return;
      _travel -= n * CursorDrag.step;
      Haptics.fire(Haptic.tap);
      widget.onMove(n);
    },
    child: widget.child,
  );
}
