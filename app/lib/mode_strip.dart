import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import 'app_log.dart';
import 'haptics.dart';
import 'mode_wheel.dart' show modeIconName, modeSwipeSpeed;
import 'modes.dart';
import 'ui.dart';

/// The width of one item's slot, in logical pixels.
const modeStripSlot = 140.0;

/// The fixed selection rectangle at the centre of the strip.
const _boxWidth = 136.0;
const _boxHeight = 48.0;

/// The width of the fade on a side that has more to scroll to.
const _fadeWidth = 28.0;

/// The free play slider of the Today tab: every open mode side by side, an
/// icon and a name each, with a fixed rectangle at the centre. The strip works
/// like a ratchet under the rectangle: it follows the finger, ticks as each
/// mode passes under it, and settles on the nearest mode when let go. A tap on
/// a neighbour moves to it; a tap on the rectangle calls [onTap].
class ModeStrip extends StatefulWidget {
  const ModeStrip({
    super.key,
    required this.modes,
    required this.selected,
    required this.onChanged,
    required this.onTap,
    this.height = 56,
  });

  final List<GameMode> modes;
  final GameMode selected;

  /// Called when the strip settles on a mode other than [selected].
  final ValueChanged<GameMode> onChanged;

  /// Called when the rectangle is tapped.
  final VoidCallback onTap;
  final double height;

  @override
  State<ModeStrip> createState() => _ModeStripState();
}

class _ModeStripState extends State<ModeStrip>
    with SingleTickerProviderStateMixin {
  /// Where the ratchet is, in items from the first (fractional while the finger
  /// is on it), and the item that last ticked.
  double _pos = 0;
  int _ticked = 0;
  double _from = 0, _to = 0;
  bool _dragging = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  List<GameMode> get _modes =>
      widget.modes.isEmpty ? [widget.selected] : widget.modes;
  int get _last => _modes.length - 1;
  int get _selectedIndex => math.max(0, _modes.indexOf(widget.selected));
  int get _nearest => _pos.round().clamp(0, _last);

  @override
  void initState() {
    super.initState();
    _pos = _selectedIndex.toDouble();
    _ticked = _selectedIndex;
    _anim.addListener(() {
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _setPos(_from + (_to - _from) * t));
    });
  }

  @override
  void didUpdateWidget(ModeStrip old) {
    super.didUpdateWidget(old);
    // moved from outside (or the modes changed): follow it when at rest
    if (!_dragging &&
        !_anim.isAnimating &&
        (old.selected != widget.selected || old.modes != widget.modes)) {
      _pos = _selectedIndex.toDouble();
      _ticked = _selectedIndex;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Moves the ratchet to [p] items, with a tick for each one crossed.
  void _setPos(double p) {
    _pos = p.clamp(0.0, _last.toDouble());
    final k = _pos.round();
    if (k != _ticked) {
      _ticked = k;
      try {
        Haptics.fire(Haptic.tap);
      } catch (e) {
        appLog.w('mode-strip', 'could not tick: ${e.runtimeType}');
      }
    }
  }

  /// Runs on to item [target], then reports the mode it lands on.
  void _goTo(int target) {
    try {
      target = target.clamp(0, _last);
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      void settle() {
        if (!mounted) return;
        setState(() {
          _pos = target.toDouble();
          _ticked = target;
        });
        final m = _modes[target];
        if (m != widget.selected) {
          try {
            widget.onChanged(m);
          } catch (e) {
            appLog.w(
              'mode-strip',
              'could not change the mode: ${e.runtimeType}',
            );
          }
        }
      }

      if (reduced || _pos == target.toDouble()) {
        _anim.stop();
        setState(() => _setPos(target.toDouble()));
        settle();
        return;
      }
      _from = _pos;
      _to = target.toDouble();
      _anim.forward(from: 0).then((_) => settle());
    } catch (e) {
      appLog.w('mode-strip', 'could not move: ${e.runtimeType}');
    }
  }

  void _start(DragStartDetails d) {
    _dragging = true;
    _anim.stop();
  }

  void _update(DragUpdateDetails d) {
    // dragged left brings the next mode
    setState(() => _setPos(_pos - d.delta.dx / modeStripSlot));
  }

  void _end(double velocity) {
    _dragging = false;
    var target = _pos.round();
    // a fast flick goes one item further in its direction
    if (velocity.abs() >= modeSwipeSpeed) {
      target = velocity < 0 ? _pos.floor() + 1 : _pos.ceil() - 1;
    }
    _goTo(target);
  }

  Widget _item(ColorScheme c, int i) {
    final m = _modes[i];
    final here = i == _nearest;
    final color = here ? c.onSurface : c.onSurface.withValues(alpha: .62);
    return GestureDetector(
      key: ValueKey('mode-strip-${m.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTo(i),
      child: SizedBox(
        width: modeStripSlot,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TablerIcon(modeIconName(m), size: 20, color: color),
                const SizedBox(width: 8),
                if (here)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'free play',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.1,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                      Text(
                        m.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    m.label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13, color: color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _track(ColorScheme c, double width) {
    final solid = c.surface;
    final clear = solid.withValues(alpha: 0);
    final fadeLeft = _pos > .01;
    final fadeRight = _pos < _last - .01;
    final f = width <= 0 ? 0.0 : (_fadeWidth / width).clamp(0.0, .5);
    return ShaderMask(
      // the key says which sides fade, for the tests
      key: ValueKey(
        'mode-strip-fade-${fadeLeft ? 'l' : '-'}${fadeRight ? 'r' : '-'}',
      ),
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        colors: [
          fadeLeft ? clear : solid,
          solid,
          solid,
          fadeRight ? clear : solid,
        ],
        stops: [0, f, 1 - f, 1],
      ).createShader(r),
      child: Stack(
        children: [
          for (var i = 0; i < _modes.length; i++)
            Positioned(
              left: width / 2 - modeStripSlot / 2 + (i - _pos) * modeStripSlot,
              top: 0,
              bottom: 0,
              width: modeStripSlot,
              child: _item(c, i),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final many = _modes.length > 1;
    final shown = _modes[_nearest];
    return Semantics(
      container: true,
      slider: many,
      label: 'free play mode',
      value: shown.label,
      increasedValue: _modes[math.min(_nearest + 1, _last)].label,
      decreasedValue: _modes[math.max(_nearest - 1, 0)].label,
      onIncrease: many && _nearest < _last ? () => _goTo(_nearest + 1) : null,
      onDecrease: many && _nearest > 0 ? () => _goTo(_nearest - 1) : null,
      child: GestureDetector(
        key: const ValueKey('mode-strip'),
        behavior: HitTestBehavior.translucent,
        // tracked from where the finger went down, so the strip follows it 1:1
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: many ? _start : null,
        onHorizontalDragUpdate: many ? _update : null,
        onHorizontalDragEnd: many ? (d) => _end(d.primaryVelocity ?? 0) : null,
        onHorizontalDragCancel: many ? () => _end(0) : null,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.fromBorderSide(hairline(c)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth.isFinite ? box.maxWidth : modeStripSlot;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(child: _track(c, w)),
                    ),
                    Center(
                      child: Semantics(
                        container: true,
                        button: true,
                        label: 'free play ${shown.label}',
                        excludeSemantics: true,
                        onTap: _tapBox,
                        child: GestureDetector(
                          key: const ValueKey('mode-strip-box'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _tapBox,
                          child: Container(
                            width: _boxWidth,
                            height: _boxHeight,
                            decoration: BoxDecoration(
                              border: Border.all(color: c.onSurface),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _tapBox() {
    try {
      widget.onTap();
    } catch (e) {
      appLog.w('mode-strip', 'could not open free play: ${e.runtimeType}');
    }
  }
}
