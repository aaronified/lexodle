import 'package:flutter/material.dart';

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
