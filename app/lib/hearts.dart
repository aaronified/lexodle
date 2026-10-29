import 'dart:math';

import 'package:flutter/material.dart';

import 'modes.dart';
import 'ui.dart';

/// The hearts of a lockdown game: [total] of them, [left] still whole. When a
/// heart is lost it breaks in two, the halves falling away; when [throbHearts]
/// or fewer are left, the ones left throb. A lost heart is an outline and does
/// not move.
class HeartsRow extends StatefulWidget {
  const HeartsRow({super.key, required this.total, required this.left});
  final int total;
  final int left;

  @override
  State<HeartsRow> createState() => _HeartsRowState();
}

class _HeartsRowState extends State<HeartsRow> with TickerProviderStateMixin {
  late final AnimationController _break = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  /// The hearts that are breaking now: the ones from [left] up to where it was.
  int _from = 0, _to = 0;

  @override
  void initState() {
    super.initState();
    _beat.addListener(() {
      if (_throbbing) setState(() {});
    });
    _break.addListener(() => setState(() {}));
    _break.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _from = _to = 0);
    });
    _sync();
  }

  bool get _throbbing => widget.left > 0 && widget.left <= throbHearts;

  @override
  void didUpdateWidget(HeartsRow old) {
    super.didUpdateWidget(old);
    if (widget.left < old.left) {
      _from = widget.left;
      _to = min(old.left, widget.total);
      _break.forward(from: 0);
    } else if (widget.left > old.left) {
      _from = _to = 0; // a new game
      _break.value = 0;
    }
    _sync();
  }

  /// Runs the beat while it is wanted, and not at all when the player has
  /// turned animations off.
  void _sync() {
    final calm = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (_throbbing && !calm) {
      if (!_beat.isAnimating) _beat.repeat();
    } else {
      _beat.stop();
      _beat.value = 0;
    }
  }

  @override
  void dispose() {
    _break.dispose();
    _beat.dispose();
    super.dispose();
  }

  /// How big a whole heart is now: a double beat, then a rest.
  double get _scale {
    final t = _beat.value;
    double bump(double at, double w, double h) =>
        t < at || t > at + w ? 0 : sin((t - at) / w * pi) * h;
    return 1 + bump(0, .24, .24) + bump(.24, .3, .16);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('hearts'),
      container: true,
      label: '${widget.left} ${widget.left == 1 ? 'heart' : 'hearts'} left',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(width: 24, height: 22, child: _heart(c, i)),
            ),
        ],
      ),
    );
  }

  Widget _heart(ColorScheme c, int i) {
    final breaking = i >= _from && i < _to && _break.isAnimating;
    final whole = i < widget.left;
    return CustomPaint(
      key: ValueKey(
        breaking
            ? 'heart-$i-breaking'
            : whole
            ? (_throbbing ? 'heart-$i-throbbing' : 'heart-$i-whole')
            : 'heart-$i-lost',
      ),
      painter: _HeartPainter(
        color: heartColor(c),
        outline: c.outlineVariant,
        state: breaking
            ? _HeartState.breaking
            : whole
            ? _HeartState.whole
            : _HeartState.lost,
        t: breaking ? _break.value : 0,
        scale: whole && _throbbing ? _scale : 1,
      ),
    );
  }
}

enum _HeartState { whole, breaking, lost }

class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required this.color,
    required this.outline,
    required this.state,
    required this.t,
    required this.scale,
  });
  final Color color, outline;
  final _HeartState state;
  final double t, scale;

  /// The heart of the icon set, on a 24 by 22 box.
  static Path _heart() => Path()
    ..moveTo(12, 21.2)
    ..lineTo(10.6, 19.9)
    ..cubicTo(5.4, 15.2, 2, 12.1, 2, 8.3)
    ..cubicTo(2, 5.2, 4.4, 2.8, 7.5, 2.8)
    ..cubicTo(9.2, 2.8, 10.9, 3.6, 12, 4.9)
    ..cubicTo(13.1, 3.6, 14.8, 2.8, 16.5, 2.8)
    ..cubicTo(19.6, 2.8, 22, 5.2, 22, 8.3)
    ..cubicTo(22, 12.1, 18.6, 15.2, 13.4, 19.9)
    ..lineTo(12, 21.2)
    ..close();

  /// The two halves, cut along a crack.
  static Path _left() => Path()
    ..moveTo(0, 0)
    ..lineTo(12.5, 0)
    ..lineTo(10, 6.6)
    ..lineTo(14, 11.4)
    ..lineTo(10.6, 16.7)
    ..lineTo(12.5, 22)
    ..lineTo(0, 22)
    ..close();
  static Path _right() => Path()
    ..moveTo(12.5, 0)
    ..lineTo(24, 0)
    ..lineTo(24, 22)
    ..lineTo(12.5, 22)
    ..lineTo(10.6, 16.7)
    ..lineTo(14, 11.4)
    ..lineTo(10, 6.6)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 22);
    final fill = Paint()..color = color;
    switch (state) {
      case _HeartState.lost:
        canvas.drawPath(
          _heart(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = outline,
        );
      case _HeartState.whole:
        if (scale != 1) {
          canvas.translate(12, 12);
          canvas.scale(scale);
          canvas.translate(-12, -12);
        }
        canvas.drawPath(_heart(), fill);
      case _HeartState.breaking:
        final e = Curves.easeIn.transform(t);
        final lean = t < .25 ? t / .25 : 1.0;
        final fade = 1 - e;
        void half(Path clip, double dir, double ox) {
          canvas.save();
          canvas.translate(ox, 22);
          canvas.translate(dir * (2 * lean + 12 * e), 1 * lean + 46 * e);
          canvas.rotate(dir * (8 * lean + 30 * e) * pi / 180);
          canvas.translate(-ox, -22);
          canvas.clipPath(clip);
          canvas.drawPath(
            _heart(),
            Paint()..color = color.withValues(alpha: fade),
          );
          canvas.restore();
        }

        half(_left(), -1, 4.8);
        half(_right(), 1, 19.2);
        // a ring spreads from the crack and is gone before the halves land
        if (t < .5) {
          final r = t / .5;
          canvas.drawCircle(
            const Offset(12, 11),
            6 + 14 * r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: .9 * (1 - r)),
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.state != state ||
      old.t != t ||
      old.scale != scale ||
      old.color != color;
}
