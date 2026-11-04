import 'haptics.dart';

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// The panel over a finished game. The boards behind it never move: they are
/// laid out for the panel's starting height ([restHeight]) and the panel is
/// drawn over them from the bottom, so a taller one covers the lower rows.
///
/// The bar and the [header] row under it stay in place and are the handle:
/// drag them to resize the panel, or double tap to make it as tall as it can be
/// (and back). The [child] under them scrolls, and the scroll and the panel
/// are one movement: scrolling it up first raises the panel, up to
/// [maxShare] of the screen, and then scrolls the text; scrolling it down first
/// takes the text back to the top, and then lowers the panel. It rises from the
/// bottom when it first appears, with a hairline on top (square) and a shadow
/// on the boards.
class ResizablePanel extends StatefulWidget {
  const ResizablePanel({super.key, required this.header, required this.child});

  /// The row under the bar, part of the handle.
  final Widget header;

  /// What scrolls.
  final Widget child;

  /// The share of the screen the panel can take at most.
  static const maxShare = .75;

  /// The least the panel can be: the bar, the header and a little of the text.
  static const minHeight = 120.0;

  /// The height the panel starts at, which the screen under it keeps free.
  static double restHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * .5;

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel>
    with TickerProviderStateMixin {
  double? _height;
  double _max = ResizablePanel.minHeight;
  double _flung = 0;

  final _scroll = ScrollController();

  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final AnimationController _fling = AnimationController.unbounded(
    vsync: this,
  )..addListener(_flingStep);

  @override
  void initState() {
    super.initState();
    _rise.forward();
  }

  @override
  void dispose() {
    _fling.dispose();
    _rise.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _rest => min(ResizablePanel.restHeight(context), _max);

  double get _current =>
      (_height ?? _rest).clamp(ResizablePanel.minHeight, _max).toDouble();

  void _resize(double by) {
    final before = _current;
    final next = (before + by).clamp(ResizablePanel.minHeight, _max).toDouble();
    // a tick when it reaches the top or the bottom of its travel
    final ends = [ResizablePanel.minHeight, _max];
    if (ends.any((e) => (next - e).abs() < 0.5 && (before - e).abs() >= 0.5)) {
      Haptics.fire(Haptic.tap);
    }
    setState(() => _height = next);
  }

  /// Moves the panel and its text by [d] (positive shows more of the text:
  /// finger up, wheel down): the panel rises, then the text scrolls; or the
  /// text goes back to the top, then the panel drops. Returns how much was
  /// used.
  double _scrollBy(double d) {
    var used = 0.0;
    final pos = _scroll.hasClients ? _scroll.position : null;
    if (d > 0) {
      final g = min(d, _max - _current);
      if (g > 0) {
        _resize(g);
        used += g;
        d -= g;
      }
      if (d > 0 && pos != null) {
        final s = min(d, pos.maxScrollExtent - pos.pixels);
        if (s > 0) {
          pos.jumpTo(pos.pixels + s);
          used += s;
        }
      }
    } else if (d < 0) {
      d = -d;
      if (pos != null) {
        final s = min(d, pos.pixels);
        if (s > 0) {
          pos.jumpTo(pos.pixels - s);
          used += s;
          d -= s;
        }
      }
      final g = min(d, _current - ResizablePanel.minHeight);
      if (g > 0) {
        _resize(-g);
        used += g;
      }
    }
    return used;
  }

  void _startFling(double velocity) {
    if (velocity.abs() < 50) return;
    _flung = 0;
    _fling.value = 0;
    _fling.animateWith(FrictionSimulation(.135, 0, velocity));
  }

  void _flingStep() {
    final d = _fling.value - _flung;
    _flung = _fling.value;
    if (_scrollBy(d) == 0) _fling.stop();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (MediaQuery.disableAnimationsOf(context)) _rise.value = 1;
    return LayoutBuilder(
      builder: (context, box) {
        final screen = MediaQuery.sizeOf(context).height;
        _max = max(
          ResizablePanel.minHeight + 40,
          min(screen * ResizablePanel.maxShare, box.maxHeight),
        );
        final panel = Column(
          children: [
            Semantics(
              label: 'resize the analysis',
              child: GestureDetector(
                key: const ValueKey('panel-handle'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => _resize(-d.delta.dy),
                onDoubleTap: () => setState(
                  () => _height = _current >= _max - 1 ? null : _max,
                ),
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _scroll.hasClients && _scroll.offset > .5
                              ? c.outlineVariant
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 10,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: c.onSurface.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(19, 0, 19, 8),
                          child: widget.header,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    GestureBinding.instance.pointerSignalResolver.register(e, (
                      _,
                    ) {
                      _fling.stop();
                      _scrollBy(e.scrollDelta.dy);
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => _fling.stop(),
                  onVerticalDragUpdate: (d) =>
                      _scrollBy(-(d.primaryDelta ?? 0)),
                  onVerticalDragEnd: (d) =>
                      _startFling(-(d.primaryVelocity ?? 0)),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: c.outlineVariant)),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow.withValues(alpha: .35),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _rise,
                  curve: Curves.easeOutCubic,
                ),
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: const ValueKey('over-panel'),
                  height: _current,
                  child: panel,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
