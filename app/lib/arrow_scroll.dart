import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets the up and down arrow keys scroll, as the mouse wheel does: whatever
/// scrolls under the pointer moves, so with a list in one place and a popup in
/// another, the keys go to the one the mouse is over. With no mouse seen yet
/// they act at the middle of the window.
///
/// It does it by sending the scroll the wheel would send, at the pointer's
/// position, so the usual rules hold (the innermost scrollable under it takes
/// it; one that cannot move any further passes nothing on). The keys are used
/// only when nothing closer wanted them first: an open dropdown, or a slider
/// with the focus, keeps its own arrows. Held with Ctrl, Alt or Meta they are
/// left alone.
class ArrowScroll extends StatefulWidget {
  const ArrowScroll({super.key, required this.child, this.step = 60});
  final Widget child;

  /// How far a press scrolls, in logical pixels (a key held repeats it).
  final double step;

  @override
  State<ArrowScroll> createState() => _ArrowScrollState();
}

class _ArrowScrollState extends State<ArrowScroll> {
  Offset? _pointer;

  void _seen(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse ||
        e.kind == PointerDeviceKind.trackpad) {
      _pointer = e.position;
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!down && e.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final k = HardwareKeyboard.instance;
    if (k.isControlPressed || k.isAltPressed || k.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final view = View.of(context);
    final at =
        _pointer ??
        Offset(
          view.physicalSize.width / view.devicePixelRatio / 2,
          view.physicalSize.height / view.devicePixelRatio / 2,
        );
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: at,
        scrollDelta: Offset(0, down ? widget.step : -widget.step),
        viewId: view.viewId,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerHover: _seen,
    onPointerMove: _seen,
    child: Focus(
      // it never takes the focus: it only hears the keys nothing nearer used
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: widget.child,
    ),
  );
}
