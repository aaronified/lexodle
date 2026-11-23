import 'package:flutter/material.dart';

import 'review_plots.dart';
import 'ui.dart';

/// The plot of a guess in a [CalcSpec]: the outcomes it could give (the one
/// that gains least first), the column the answer landed in (when it is known),
/// the guess's expected gain H and the best guess's H*.
class PlotSpec {
  const PlotSpec({
    required this.outcomes,
    required this.expected,
    this.best,
    this.landed,
    this.word = '',
    this.sizes,
  });
  final List<Outcome> outcomes;
  final double expected;
  final double? best;
  final int? landed;

  /// The word the landed column is named after in the plot.
  final String word;

  /// How many words each outcome holds, in the order of [outcomes], when known:
  /// the readout then says "12 words" and not only its chance.
  final List<int>? sizes;
}

/// What an info dot of learn shows: the idea, the numbers as lines, the result
/// in the colour of its measure, a note and, for a guess, its plot.
class CalcSpec {
  const CalcSpec({
    required this.metric,
    required this.title,
    required this.intro,
    this.rows = const [],
    this.result,
    this.note,
    this.plot,
  });

  /// 'skill', 'luck', 'risk' or 'bits': the colour of the dialog.
  final String metric;
  final String title;
  final String intro;
  final List<(String, String)> rows;
  final (String, String)? result;
  final String? note;
  final PlotSpec? plot;
}

/// The lines of a calculation: the idea, the numbers, the result and the note.
/// Also what a row of a list can show when it is opened in place.
class CalcBody extends StatelessWidget {
  const CalcBody(this.spec, {super.key});
  final CalcSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colour = metricColor(c, spec.metric);
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final mono = TextStyle(fontSize: 12, height: 1.4, color: c.onSurface);
    Widget line(String a, String b, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: measureSpans(c, a)),
                  style: mono.copyWith(
                    color: color ?? c.onSurface.withValues(alpha: .85),
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                b,
                style: mono.copyWith(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: measureSpans(c, spec.intro)),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        if (spec.rows.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 6),
            child: Caption('the numbers'),
          ),
          for (final (a, b) in spec.rows) line(a, b),
        ],
        if (spec.result != null) ...[
          Divider(height: 12, color: c.outlineVariant),
          line(spec.result!.$1, spec.result!.$2, color: colour, bold: true),
        ],
        if (spec.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(children: measureSpans(c, spec.note!)),
              style: TextStyle(fontSize: 11, height: 1.5, color: dim),
            ),
          ),
        if (spec.plot != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 6),
            child: Caption('the plot'),
          ),
          InteractiveGainPlot(spec.plot!),
        ],
      ],
    );
  }
}

/// The dialog of a calculation, in the app's hairline look, its title in the
/// colour of the measure it is about.
Future<void> showCalc(BuildContext context, CalcSpec spec) {
  final c = Theme.of(context).colorScheme;
  return showHairlineDialog<void>(
    context,
    title: spec.title,
    titleColor: metricColor(c, spec.metric),
    children: [CalcBody(spec)],
  );
}

/// A small round "i" that opens [spec] in a dialog: the look of [InfoDot], for
/// text that is a calculation with a plot.
class CalcDot extends StatelessWidget {
  const CalcDot(this.spec, {super.key});
  final CalcSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return Semantics(
      button: true,
      label: 'explain',
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => showCalc(context, spec),
        radius: 16,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceContainerHighest,
          ),
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: dim,
            ),
          ),
        ),
      ),
    );
  }
}

/// The review's gain plot that can be read: a tap or a hover over a column says
/// how likely that outcome is, how many bits it gains and, when the sizes are
/// known, how many words are in it.
class InteractiveGainPlot extends StatefulWidget {
  const InteractiveGainPlot(this.spec, {super.key});
  final PlotSpec spec;

  @override
  State<InteractiveGainPlot> createState() => _InteractiveGainPlotState();
}

class _InteractiveGainPlotState extends State<InteractiveGainPlot> {
  // the painter's own margins (see GainPainter.paint)
  static const _left = 30.0, _right = 4.0;
  int? _at;

  void _read(double dx, double width) {
    final o = widget.spec.outcomes;
    if (o.isEmpty) return;
    final w = width - _left - _right;
    final x = ((dx - _left) / w).clamp(0.0, 1.0);
    var acc = 0.0;
    for (var i = 0; i < o.length; i++) {
      acc += o[i].chance;
      if (x <= acc + 1e-12 || i == o.length - 1) {
        if (_at != i) setState(() => _at = i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final i = _at;
    String readout = 'tap or hover a column: its chance, its bits and its size';
    if (i != null && i < s.outcomes.length) {
      final o = s.outcomes[i];
      final n = s.sizes != null && i < s.sizes!.length ? s.sizes![i] : null;
      readout =
          '${n == null ? '' : '$n ${n == 1 ? 'word' : 'words'} · '}'
          'chance ${(o.chance * 100).toStringAsFixed(o.chance < .01 ? 2 : 1)}% · '
          'gains ${o.gain.toStringAsFixed(2)} bits'
          '${i == s.landed ? ' · where the answer fell' : ''}'
          ' · ${o.gain > s.expected + 1e-9 ? 'more' : 'less'} than expected';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) => MouseRegion(
            onHover: (e) => _read(e.localPosition.dx, box.maxWidth),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _read(d.localPosition.dx, box.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _read(d.localPosition.dx, box.maxWidth),
              child: GainPlot(
                outcomes: s.outcomes,
                landed: s.landed ?? -1,
                expected: s.expected,
                best: s.best,
                word: s.word,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          readout,
          key: const ValueKey('plot-readout'),
          style: TextStyle(fontSize: 12, height: 1.4, color: dim),
        ),
        const SizedBox(height: 4),
        Text(
          'each column is one outcome: as wide as its chance, as tall as the '
          'bits it gains. the area under them is H, the expected gain '
          '(dashed). the yellow line splits the chance in half, where luck is 0. '
          'green columns gain more than expected.',
          style: TextStyle(fontSize: 11, height: 1.5, color: dim),
        ),
      ],
    );
  }
}
