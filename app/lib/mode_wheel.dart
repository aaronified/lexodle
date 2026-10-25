import 'package:flutter/material.dart';

import 'modes.dart';

/// How far a drag must go, as a share of the button's width, to change the
/// mode on release.
const wheelThreshold = .35;

/// A fling faster than this (logical pixels a second) changes the mode too.
const wheelFlingSpeed = 700.0;

/// The play button, which is also a looped wheel of the game modes: classic,
/// quartet, relay race, and round to classic again, in both directions. A
/// horizontal drag turns it: the button's content (play, and the mode's name
/// under it) follows the finger, with the next mode sliding in from the side
/// being dragged towards. On release, past [wheelThreshold] of the width or a
/// fast fling, it finishes the turn from where the finger left it and calls
/// [onChanged]; otherwise it springs back. A tap plays ([onPlay]).
///
/// Dragging right brings in the previous mode, dragging left the next.
class ModeWheel extends StatefulWidget {
  const ModeWheel({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.onPlay,
    this.height = 52,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onChanged;
  final VoidCallback onPlay;
  final double height;

  /// The mode [steps] along the loop from [from] (negative goes back).
  static GameMode step(GameMode from, int steps) {
    const all = GameMode.values;
    return all[(from.index + steps) % all.length];
  }

  @override
  State<ModeWheel> createState() => _ModeWheelState();
}

class _ModeWheelState extends State<ModeWheel>
    with SingleTickerProviderStateMixin {
  /// The turn so far as a share of the width: 0 at rest, +1 a whole button to
  /// the right (the previous mode is in), -1 a whole button to the left.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  double _width = 1;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) => _turn.stop();

  void _update(DragUpdateDetails d) {
    _turn.value = (_turn.value + d.delta.dx / _width).clamp(-1.0, 1.0);
  }

  Future<void> _end(DragEndDetails d) async {
    final v = d.primaryVelocity ?? 0;
    final f = _turn.value;
    var dir = 0;
    if (f.abs() >= wheelThreshold) {
      dir = f.sign.toInt();
    } else if (v.abs() >= wheelFlingSpeed) {
      dir = v.sign.toInt();
    }
    if (dir == 0) {
      await _turn.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
      );
      return;
    }
    await _turn.animateTo(
      dir.toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    // right brings the previous mode in, left the next
    widget.onChanged(ModeWheel.step(widget.mode, -dir));
    _turn.value = 0;
  }

  // padded so it never runs under the chevrons
  Widget _face(GameMode m) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('play'),
          Text(
            m.label,
            key: ValueKey('wheel-mode-${m.name}'),
            style: const TextStyle(fontSize: 11, height: 1.1),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final chevron = Theme.of(context).colorScheme.onPrimary
        .withValues(alpha: .65);
    return GestureDetector(
      key: const ValueKey('mode-wheel'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _start,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: FilledButton(
        style: FilledButton.styleFrom(
          fixedSize: Size.fromHeight(widget.height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
        onPressed: widget.onPlay,
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, box) {
              _width = box.maxWidth <= 0 ? 1 : box.maxWidth;
              return ClipRect(
                child: AnimatedBuilder(
                  animation: _turn,
                  builder: (context, _) {
                    final f = _turn.value;
                    final w = _width;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          child: Icon(Icons.chevron_left, color: chevron),
                        ),
                        Positioned(
                          right: 4,
                          child: Icon(Icons.chevron_right, color: chevron),
                        ),
                        Transform.translate(
                          offset: Offset(f * w, 0),
                          child: _face(widget.mode),
                        ),
                        // dragged right: the previous mode comes in from the
                        // left; dragged left: the next from the right
                        if (f != 0)
                          Transform.translate(
                            offset: Offset(f * w - f.sign * w, 0),
                            child: _face(
                              ModeWheel.step(widget.mode, -f.sign.toInt()),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
