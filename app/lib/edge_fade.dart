import 'package:flutter/material.dart';

/// A row that scrolls sideways, with its edges faded only where there is more to
/// scroll to: never at the very start or the very end.
class EdgeFade extends StatefulWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.scrollKey,
    this.padding = EdgeInsets.zero,
    this.fade = 16,
  });

  final Widget child;

  /// The key of the scroll view inside, for tests.
  final Key? scrollKey;
  final EdgeInsets padding;

  /// The width of the fade, in logical pixels.
  final double fade;

  @override
  State<EdgeFade> createState() => EdgeFadeState();
}

class EdgeFadeState extends State<EdgeFade> {
  final _controller = ScrollController();
  bool fadeLeft = false;
  bool fadeRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final l = p.pixels > .5;
    final r = p.pixels < p.maxScrollExtent - .5;
    if (l != fadeLeft || r != fadeRight) {
      setState(() {
        fadeLeft = l;
        fadeRight = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // only the alpha of these matters (the mask keeps or hides what is under it)
    final solid = Theme.of(context).colorScheme.surface;
    final clear = solid.withValues(alpha: 0);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _update());
        return false;
      },
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) {
          final f = r.width <= 0 ? 0.0 : (widget.fade / r.width).clamp(0.0, .5);
          return LinearGradient(
            colors: [
              fadeLeft ? clear : solid,
              solid,
              solid,
              fadeRight ? clear : solid,
            ],
            stops: [0, f, 1 - f, 1],
          ).createShader(r);
        },
        child: SingleChildScrollView(
          key: widget.scrollKey,
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
