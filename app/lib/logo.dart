import 'package:flutter/material.dart';

import 'ui.dart';

/// The logo mark: three tiles climbing from grey to yellow to green, the
/// feedback colours of the game itself. The geometry matches
/// tools/make_icons.py, which draws the favicon and web icons.
class LexodleLogo extends StatelessWidget {
  const LexodleLogo({super.key, this.width = 52});

  /// Width of the mark; its height follows (50 : 78).
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(width, width * 50 / 78),
      painter: _LogoPainter(
        grey: c.onSurface.withValues(alpha: .3),
        yellow: yellowOf(c),
        green: c.secondary,
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.grey, required this.yellow, required this.green});
  final Color grey, yellow, green;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 78;
    // (x, y) of each tile in the 96-unit logo, minus the mark's own offset
    for (final (x, y, color) in [
      (9.0, 51.0, grey),
      (37.0, 37.0, yellow),
      (65.0, 23.0, green),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((x - 9) * k, (y - 23) * k, 22 * k, 22 * k),
          Radius.circular(4 * k),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.grey != grey || old.yellow != yellow || old.green != green;
}
