import 'dart:math';

import 'package:flutter/material.dart';

/// The panel under a finished game, with a bar on top of it: drag the bar down
/// to give the guesses more room, up (or double tap) to make the panel as tall
/// as it can be and read about the words. Until it is dragged it is as tall as
/// its [child] needs, up to half the screen.
class ResizablePanel extends StatefulWidget {
  const ResizablePanel({super.key, required this.child});
  final Widget child;

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  double? _height;

  double get _screen => MediaQuery.sizeOf(context).height;

  /// The most the panel can take: what is above it keeps a little room.
  double get _max => max(120, _screen - 260);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final half = _screen * .5;
    final h = _height;
    return Column(
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
              height: 24,
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
  }
}
