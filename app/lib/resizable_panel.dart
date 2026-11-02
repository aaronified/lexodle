import 'dart:math';

import 'package:flutter/material.dart';

/// The panel under a finished game, with a bar on top of it: drag the bar down
/// to give the guesses more room, up (or double tap) to make the panel as tall
/// as it can be and read about the words. Until it is dragged it is as tall as
/// its [child] needs, up to half the screen. It rises from the bottom when it
/// first appears, with a hairline on top (square) and a shadow on the guesses.
class ResizablePanel extends StatefulWidget {
  const ResizablePanel({super.key, required this.child});
  final Widget child;

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel>
    with SingleTickerProviderStateMixin {
  double? _height;

  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _rise.forward();
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  double get _screen => MediaQuery.sizeOf(context).height;

  /// The most the panel can take: what is above it keeps a little room.
  double get _max => max(120, _screen - 260);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final half = _screen * .5;
    final h = _height;
    if (MediaQuery.disableAnimationsOf(context)) _rise.value = 1;
    final panel = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'resize the analysis',
          child: GestureDetector(
            key: const ValueKey('panel-handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => setState(
              () =>
                  _height = ((_height ?? half) - d.delta.dy).clamp(96.0, _max),
            ),
            onDoubleTap: () => setState(
              () => _height = (_height ?? half) >= _max - 1 ? null : _max,
            ),
            child: SizedBox(
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
          ),
        ),
        h == null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: half),
                child: widget.child,
              )
            : SizedBox(
                key: const ValueKey('over-panel'),
                height: h,
                child: widget.child,
              ),
      ],
    );
    return DecoratedBox(
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
        sizeFactor: CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic),
        alignment: Alignment.bottomCenter,
        child: panel,
      ),
    );
  }
}
