import 'package:flutter/material.dart';

import 'analysis.dart';

/// The colour of each line: skill, luck and daring, from the scheme.
Map<PeriodSeries, Color> seriesColors(ColorScheme c) => {
  PeriodSeries.skill: c.primary,
  PeriodSeries.luck: c.secondary,
  PeriodSeries.daring: c.tertiary,
  PeriodSeries.guesses: c.onSurface,
};

/// How skill, luck and daring changed over the periods (50 weeks or months,
/// oldest first), a line for each of the [shown], on one axis from 0 to 100.
/// Luck is drawn about the middle (a faint line marks a luck of 0%). The
/// expected guesses, when shown, have a scale of their own at the right edge,
/// from 1 to 7. A period
/// with nothing to show breaks the line, and a period alone is a dot, so a
/// quiet stretch is seen as one. The [selected] period is picked out, and
/// tapping or dragging along the chart picks another.
class PeriodChart extends StatelessWidget {
  const PeriodChart({
    super.key,
    required this.periods,
    required this.shown,
    required this.selected,
    required this.onSelect,
    this.height = 120,
  });

  final List<Period> periods;
  final Set<PeriodSeries> shown;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colors = seriesColors(c);
    return LayoutBuilder(
      builder: (context, box) {
        void pick(Offset at) {
          final right = shown.contains(PeriodSeries.guesses)
              ? _ChartPainter.rightAxis
              : 0.0;
          if (periods.isEmpty || box.maxWidth <= _ChartPainter.axis + right) {
            return;
          }
          final plotW = box.maxWidth - _ChartPainter.axis - right;
          final i = ((at.dx - _ChartPainter.axis) / plotW * periods.length)
              .floor();
          onSelect(i.clamp(0, periods.length - 1));
        }

        return GestureDetector(
          key: const ValueKey('period-chart'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition),
          onHorizontalDragUpdate: (d) => pick(d.localPosition),
          child: CustomPaint(
            size: Size(box.maxWidth, height),
            painter: _ChartPainter(
              lines: {
                for (final s in PeriodSeries.values)
                  if (shown.contains(s))
                    s: [for (final p in periods) s.plot(p.stats)],
              },
              colors: colors,
              selected: selected,
              grid: c.outlineVariant,
              base: c.outline,
              label: c.onSurface.withValues(alpha: .6),
              font: DefaultTextStyle.of(context).style.fontFamily,
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.lines,
    required this.colors,
    required this.selected,
    required this.grid,
    required this.base,
    required this.label,
    required this.font,
  });

  /// Room at the left for the numbers of the axis, and at the right for those
  /// of the guesses (only when they are drawn).
  static const axis = 26.0;
  static const rightAxis = 16.0;

  /// Per line, its value at each period (0 to 100, null for none).
  final Map<PeriodSeries, List<double?>> lines;
  final Map<PeriodSeries, Color> colors;
  final int selected;
  final Color grid, base, label;
  final String? font;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0, bottom = 4.0;
    final guessed = lines.containsKey(PeriodSeries.guesses);
    final right = guessed ? rightAxis : 0.0;
    final plotW = size.width - axis - right;
    final plotH = size.height - top - bottom;
    double y(double v) => top + plotH * (1 - v / 100);

    // the axis: 0, 50 (also a luck of 0%) and 100
    for (final v in const [0.0, 50.0, 100.0]) {
      canvas.drawLine(
        Offset(axis, y(v)),
        Offset(size.width - right, y(v)),
        Paint()
          ..color = v == 0 ? base : grid
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: v.round().toString(),
          style: TextStyle(fontSize: 9, color: label, fontFamily: font),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(axis - tp.width - 4, y(v) - tp.height / 2));
      if (guessed) {
        // the right scale: 1, 4 and 7 guesses on the same three lines
        final g = TextPainter(
          text: TextSpan(
            text: (1 + v / 100 * 6).round().toString(),
            style: TextStyle(
              fontSize: 9,
              color: colors[PeriodSeries.guesses],
              fontFamily: font,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        g.paint(canvas, Offset(size.width - right + 4, y(v) - g.height / 2));
      }
    }

    final n = lines.values.isEmpty ? 0 : lines.values.first.length;
    if (n == 0) return;
    final slot = plotW / n;
    double x(int i) => axis + slot * (i + .5);

    // the picked period: a line down through every series
    canvas.drawLine(
      Offset(x(selected), top),
      Offset(x(selected), top + plotH),
      Paint()
        ..color = base
        ..strokeWidth = 1,
    );

    for (final e in lines.entries) {
      final color = colors[e.key]!;
      final values = e.value;
      final line = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      // a run of consecutive periods with something to show is one stroke; a
      // gap breaks it
      Path? run;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) {
          if (run != null) canvas.drawPath(run, line);
          run = null;
          continue;
        }
        if (run == null) {
          run = Path()..moveTo(x(i), y(v));
        } else {
          run.lineTo(x(i), y(v));
        }
      }
      if (run != null) canvas.drawPath(run, line);
      // a dot at each, so a period on its own is not lost, a bigger one at the
      // picked period
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        canvas.drawCircle(
          Offset(x(i), y(v)),
          i == selected ? 3.5 : 1.8,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.lines.toString() != lines.toString() ||
      old.selected != selected ||
      old.colors.toString() != colors.toString();
}
