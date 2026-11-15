import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import 'app_log.dart';
import 'haptics.dart';
import 'mode_wheel.dart' show modeSwipeSpeed;
import 'ui.dart';

/// The width of a chevron's hit area.
const _chevronWidth = 44.0;

/// The height of the swipe and dropdown boxes.
const _boxHeight = 58.0;

/// A choice among a few labelled values, like the free play strip in small:
/// a hairline box with the title over the chosen label, chevrons at both
/// sides. Dragging slides the labels like a ratchet (a tick for each one
/// passed) and settles on the nearest; the chevrons step one. It stops at the
/// first and the last choice and does not loop.
class SwipeChoice<T> extends StatefulWidget {
  const SwipeChoice({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  });

  final String title;
  final List<(T, String)> items;
  final T selected;

  /// Called when the box settles on a choice other than [selected].
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  State<SwipeChoice<T>> createState() => _SwipeChoiceState<T>();
}

class _SwipeChoiceState<T> extends State<SwipeChoice<T>>
    with SingleTickerProviderStateMixin {
  double _pos = 0;
  int _ticked = 0;
  double _from = 0, _to = 0;
  bool _dragging = false;
  double _slot = 100;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  int get _last => math.max(0, widget.items.length - 1);
  int get _selectedIndex {
    final i = widget.items.indexWhere((e) => e.$1 == widget.selected);
    return i < 0 ? 0 : i;
  }

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
  void didUpdateWidget(SwipeChoice<T> old) {
    super.didUpdateWidget(old);
    if (!_dragging &&
        !_anim.isAnimating &&
        (old.selected != widget.selected || old.items != widget.items)) {
      _pos = _selectedIndex.toDouble();
      _ticked = _selectedIndex;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _setPos(double p) {
    _pos = p.clamp(0.0, _last.toDouble());
    final k = _pos.round();
    if (k != _ticked) {
      _ticked = k;
      try {
        Haptics.fire(Haptic.tap);
      } catch (e) {
        appLog.w('swipe-choice', 'could not tick: ${e.runtimeType}');
      }
    }
  }

  /// Runs on to item [target]; with [notify], then reports the value it
  /// lands on, and slides back if the parent refuses it.
  void _goTo(int target, {bool notify = true}) {
    try {
      target = target.clamp(0, _last);
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      void settle() {
        if (!mounted) return;
        setState(() {
          _pos = target.toDouble();
          _ticked = target;
        });
        if (!notify || widget.items.isEmpty) return;
        final v = widget.items[target].$1;
        if (v != widget.selected) {
          try {
            widget.onChanged(v);
          } catch (e) {
            appLog.w(
              'swipe-choice',
              'could not change the choice: ${e.runtimeType}',
            );
          }
          // a refusal leaves `selected` as it was: slide back to it
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _dragging || _anim.isAnimating) return;
            if (_selectedIndex != _pos.round()) {
              _goTo(_selectedIndex, notify: false);
            }
          });
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
      appLog.w('swipe-choice', 'could not move: ${e.runtimeType}');
    }
  }

  void _start(DragStartDetails d) {
    _dragging = true;
    _anim.stop();
  }

  void _update(DragUpdateDetails d) {
    setState(() => _setPos(_pos - d.delta.dx / _slot));
  }

  void _end(double velocity) {
    _dragging = false;
    var target = _pos.round();
    if (velocity.abs() >= modeSwipeSpeed) {
      target = velocity < 0 ? _pos.floor() + 1 : _pos.ceil() - 1;
    }
    _goTo(target);
  }

  Widget _chevron(ColorScheme c, bool next, bool enabled) {
    final title = widget.title;
    return Positioned(
      top: 0,
      bottom: 0,
      left: next ? null : 0,
      right: next ? 0 : null,
      width: _chevronWidth,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('swipe-$title-${next ? 'next' : 'prev'}'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _goTo(_nearest + (next ? 1 : -1)) : null,
          child: Center(
            child: Text(
              next ? '›' : '‹',
              style: TextStyle(
                fontSize: 20,
                color: c.onSurface.withValues(alpha: enabled ? 1 : .35),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(ColorScheme c, int i) {
    final here = i == _nearest;
    final color = here ? c.onSurface : c.onSurface.withValues(alpha: dimAlpha);
    return SizedBox(
      width: _slot,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  letterSpacing: 1.2,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.items[i].$2,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: here ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final items = widget.items;
    if (items.isEmpty) return const SizedBox(height: _boxHeight);
    final many = items.length > 1;
    final n = _nearest;
    return Semantics(
      container: true,
      slider: many,
      label: widget.semanticLabel ?? widget.title,
      value: items[n].$2,
      increasedValue: items[math.min(n + 1, _last)].$2,
      decreasedValue: items[math.max(n - 1, 0)].$2,
      onIncrease: many && n < _last ? () => _goTo(n + 1) : null,
      onDecrease: many && n > 0 ? () => _goTo(n - 1) : null,
      child: GestureDetector(
        key: ValueKey('swipe-${widget.title}'),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: many ? _start : null,
        onHorizontalDragUpdate: many ? _update : null,
        onHorizontalDragEnd: many ? (d) => _end(d.primaryVelocity ?? 0) : null,
        onHorizontalDragCancel: many ? () => _end(0) : null,
        child: Container(
          width: double.infinity,
          height: _boxHeight,
          decoration: BoxDecoration(
            border: Border.fromBorderSide(hairline(c)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth.isFinite ? box.maxWidth : 180.0;
                _slot = math.max(60.0, w - 2 * _chevronWidth);
                final mid = _nearest;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        // the labels fade out a long way before the sides: only
                        // the middle third is solid
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => const LinearGradient(
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0xFFFFFFFF),
                              Color(0xFFFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [.12, .36, .64, .88],
                          ).createShader(r),
                          child: Stack(
                            children: [
                              for (
                                var i = math.max(0, mid - 2);
                                i <= math.min(_last, mid + 2);
                                i++
                              )
                                Positioned(
                                  left: w / 2 - _slot / 2 + (i - _pos) * _slot,
                                  top: 0,
                                  bottom: 0,
                                  width: _slot,
                                  child: _item(c, i),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _chevron(c, false, many && mid > 0),
                    _chevron(c, true, many && mid < _last),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A choice on a line: the title at the left, the chosen label (bold) and its
/// hint at the right, and a native slider with a stop for every item under it.
class LineSlider<T> extends StatelessWidget {
  const LineSlider({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.onDisabledTap,
  });

  final String title;
  final List<(T, String, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Greyed and still: a tap anywhere calls [onDisabledTap].
  final bool enabled;
  final VoidCallback? onDisabledTap;

  void _change(double v) {
    try {
      final i = v.round().clamp(0, items.length - 1);
      final value = items[i].$1;
      if (value != selected) onChanged(value);
    } catch (e) {
      appLog.w('line-slider', 'could not change the value: ${e.runtimeType}');
    }
  }

  void _tapDisabled() {
    try {
      onDisabledTap?.call();
    } catch (e) {
      appLog.w('line-slider', 'could not tap while off: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();
    final idx = math.max(0, items.indexWhere((e) => e.$1 == selected));
    final it = items[idx];
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final body = Opacity(
      opacity: enabled ? 1 : .35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: dim),
              ),
              const Spacer(),
              Text(
                it.$2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (it.$3.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(it.$3, style: TextStyle(fontSize: 11, color: dim)),
              ],
            ],
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                showValueIndicator: ShowValueIndicator.never,
                trackHeight: 2,
                activeTrackColor: c.primary,
                inactiveTrackColor: c.outlineVariant,
                thumbColor: c.primary,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                disabledActiveTrackColor: c.primary,
                disabledInactiveTrackColor: c.outlineVariant,
                disabledThumbColor: c.primary,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                key: ValueKey('slider-$title'),
                min: 0,
                max: math.max(1, items.length - 1).toDouble(),
                divisions: math.max(1, items.length - 1),
                value: idx.toDouble(),
                label: null,
                semanticFormatterCallback: (_) => it.$2,
                onChanged: enabled && items.length > 1 ? _change : null,
              ),
            ),
          ),
        ],
      ),
    );
    if (enabled) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tapDisabled,
      child: AbsorbPointer(child: body),
    );
  }
}

/// A full-width hairline box with the title over [child] (the caller's flag and
/// code), a ▾ at the right edge; a tap calls [onTap].
class DropdownBox extends StatelessWidget {
  const DropdownBox({
    super.key,
    required this.title,
    required this.child,
    required this.onTap,
  });

  final String title;
  final Widget child;
  final VoidCallback onTap;

  void _tap() {
    try {
      onTap();
    } catch (e) {
      appLog.w('dropdown-box', 'could not open: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        key: ValueKey('dropdown-$title'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          width: double.infinity,
          height: _boxHeight,
          decoration: BoxDecoration(
            border: Border.fromBorderSide(hairline(c)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      letterSpacing: 1.2,
                      color: dim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    child: child,
                  ),
                ],
              ),
              Positioned(
                right: 12,
                child: Text('▾', style: TextStyle(fontSize: 13, color: dim)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
