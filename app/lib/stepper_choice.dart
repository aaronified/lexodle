import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A one-at-a-time slider, `‹ skill only ›`, with a label and a subtitle.
///
/// It changes by the chevrons, by the arrow keys, by horizontal scrolling (a
/// wheel with shift, or a trackpad), and by dragging or swiping. A drag moves
/// the value with the pointer: the current one slides away and fades while its
/// neighbour slides in and fades up, and letting go either completes the step
/// or settles back. The chevrons dim at either end.
class StepperChoice<T> extends StatefulWidget {
  const StepperChoice({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  });

  final List<(T value, String label, String? sub)> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  State<StepperChoice<T>> createState() => _StepperChoiceState<T>();
}

class _StepperChoiceState<T> extends State<StepperChoice<T>>
    with SingleTickerProviderStateMixin {
  late int _index = _indexOf(widget.selected);
  final _focus = FocusNode();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  /// How far the current value is dragged, in pixels (negative is leftwards).
  double _dx = 0;
  double _width = 1;
  double _from = 0, _to = 0;
  bool _busy = false;

  double _wheel = 0;

  /// A step by wheel is followed by a short pause, so a trackpad's coasting
  /// does not carry on through several values.
  Timer? _cooldown;

  int _indexOf(T v) => max(0, widget.items.indexWhere((i) => i.$1 == v));

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _dx = _from + (_to - _from) * t);
    });
  }

  @override
  void didUpdateWidget(StepperChoice<T> old) {
    super.didUpdateWidget(old);
    if (!_busy && widget.items[_index].$1 != widget.selected) {
      _index = _indexOf(widget.selected);
    }
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _anim.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _can(int dir) => _index + dir >= 0 && _index + dir < widget.items.length;

  /// Slides to the neighbour in direction [dir] (+1 next, -1 previous).
  void _step(int dir) {
    if (_busy) return;
    if (!_can(dir)) return _settle();
    _busy = true;
    _from = _dx;
    _to = dir > 0 ? -_width : _width;
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _index += dir;
        _dx = 0;
        _busy = false;
      });
      widget.onChanged(widget.items[_index].$1);
    });
  }

  /// Slides back to rest.
  void _settle() {
    if (_busy || _dx == 0) return;
    _busy = true;
    _from = _dx;
    _to = 0;
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _dx = 0;
        _busy = false;
      });
    });
  }

  void _drag(double delta) {
    if (_busy) return;
    final dir = (_dx + delta) < 0 ? 1 : -1;
    // no neighbour that way: pull against a rubber band
    final d = _can(dir) ? delta : delta * .3;
    setState(() => _dx = (_dx + d).clamp(-_width, _width));
  }

  void _release(double velocity) {
    if (_busy) return;
    final byVelocity = velocity.abs() > 500;
    final dir = byVelocity ? (velocity < 0 ? 1 : -1) : (_dx < 0 ? 1 : -1);
    if ((byVelocity || _dx.abs() > _width * .3) && _can(dir)) {
      _step(dir);
    } else {
      _settle();
    }
  }

  void _scroll(PointerScrollEvent e) {
    final horizontal = e.scrollDelta.dx.abs() > e.scrollDelta.dy.abs();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final d = horizontal ? e.scrollDelta.dx : (shift ? e.scrollDelta.dy : 0.0);
    if (d == 0) return;
    // claim the event so the page does not also scroll
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      _wheel += d;
      if (_wheel.abs() > 30 && !_busy && _cooldown == null) {
        _step(_wheel > 0 ? 1 : -1);
        _wheel = 0;
        _cooldown = Timer(const Duration(milliseconds: 140), () {
          _cooldown = null;
        });
      }
    });
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _item(ColorScheme c, int i, {Key? key}) {
    final (_, label, sub) = widget.items[i];
    return SizedBox(
      key: key,
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (sub != null)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: c.onSurface.withValues(alpha: .65),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = widget.items.length;
    final dir = _dx < 0 ? 1 : -1;
    final p = (_dx.abs() / _width).clamp(0.0, 1.0);

    Widget chevron(int d, IconData icon, String tip) => IconButton(
      tooltip: tip,
      onPressed: _can(d) ? () => _step(d) : null,
      icon: Icon(icon),
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.items[_index].$2,
      increasedValue: _can(1) ? widget.items[_index + 1].$2 : null,
      decreasedValue: _can(-1) ? widget.items[_index - 1].$2 : null,
      onIncrease: _can(1) ? () => _step(1) : null,
      onDecrease: _can(-1) ? () => _step(-1) : null,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        child: Column(
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(color: c.outline),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  chevron(-1, Icons.chevron_left, 'previous'),
                  Expanded(
                    child: Listener(
                      onPointerSignal: (e) {
                        if (e is PointerScrollEvent) _scroll(e);
                      },
                      onPointerPanZoomUpdate: (e) => _drag(e.panDelta.dx),
                      onPointerPanZoomEnd: (_) => _release(0),
                      child: GestureDetector(
                        key: const ValueKey('step-viewport'),
                        behavior: HitTestBehavior.opaque,
                        // a click puts the arrow keys on this slider
                        onTapDown: (_) => _focus.requestFocus(),
                        onHorizontalDragUpdate: (d) => _drag(d.delta.dx),
                        onHorizontalDragEnd: (d) =>
                            _release(d.primaryVelocity ?? 0),
                        onHorizontalDragCancel: () => _release(0),
                        child: ClipRect(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              _width = max(1, box.maxWidth);
                              return SizedBox(
                                height: 64,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(_dx, 0),
                                      child: Opacity(
                                        key: const ValueKey('step-current'),
                                        opacity: 1 - p,
                                        child: _item(c, _index),
                                      ),
                                    ),
                                    if (_dx != 0 && _can(dir))
                                      Transform.translate(
                                        offset: Offset(
                                          _dx + (dir > 0 ? _width : -_width),
                                          0,
                                        ),
                                        child: Opacity(
                                          key: const ValueKey('step-incoming'),
                                          opacity: p,
                                          child: _item(c, _index + dir),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  chevron(1, Icons.chevron_right, 'next'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? c.primary : c.outlineVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
