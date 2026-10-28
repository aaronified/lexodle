import 'dart:math';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'review_text.dart';
import 'ui.dart';
import 'wiki_links.dart';

String _n(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// One way a guess could have come out: the chance of it and the bits it would
/// gain (-log2 of the chance).
class Outcome {
  const Outcome(this.chance, this.gain);
  final double chance;
  final double gain;
}

/// Every outcome of [guess] against [eligible] under [weights], the one that
/// gains least first (the biggest group), and the index of the outcome that
/// [answer] gave.
({List<Outcome> outcomes, int landed}) outcomesOf(
  List<String> eligible,
  String guess,
  String answer,
  Map<String, int>? weights,
) {
  final mass = <int, double>{};
  var total = 0.0;
  for (final w in eligible) {
    final x = weights == null ? 1.0 : max(weights[w] ?? 1, 1).toDouble();
    mass[patternCode(w, guess)] = (mass[patternCode(w, guess)] ?? 0) + x;
    total += x;
  }
  final key = patternCode(answer, guess);
  final keys = mass.keys.toList()
    ..sort((a, b) {
      final c = mass[b]!.compareTo(mass[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return (
    outcomes: [
      for (final k in keys) Outcome(mass[k]! / total, bitsOf(mass[k]! / total)),
    ],
    landed: max(0, keys.indexOf(key)),
  );
}

/// Skill, risk and luck on one plot of a guess: a column for every way it could
/// have come out, as wide as its chance and as tall as the bits it would gain,
/// the one that gains least on the left. The area under the columns is the
/// expected gain, H (the dashed line is its mean height), and H* (dotted) is
/// the best guess's. The columns that gain more than expected are green, the
/// tail a risky guess gambles on. The yellow line splits the chance in half, the
/// middle outcome, where luck is 0, and the column you landed in is outlined,
/// named by the guess.
class GainPlot extends StatelessWidget {
  const GainPlot({
    super.key,
    required this.outcomes,
    required this.landed,
    required this.expected,
    required this.best,
    required this.word,
  });
  final List<Outcome> outcomes;
  final int landed;
  final double expected;
  final double? best;
  final String word;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('gain-plot'),
        painter: GainPainter(
          outcomes,
          landed,
          expected,
          best,
          word,
          less: c.outline,
          more: riskColor(c).withValues(alpha: .6),
          even: c.onSurface.withValues(alpha: dimAlpha),
          skill: skillColor(c),
          luck: luckColor(c),
          ink: c.onSurface,
          axis: c.outline,
          label: c.onSurface.withValues(alpha: dimAlpha),
          font: DefaultTextStyle.of(context).style.fontFamily,
        ),
      ),
    );
  }
}

class GainPainter extends CustomPainter {
  GainPainter(
    this.outcomes,
    this.landed,
    this.expected,
    this.best,
    this.word, {
    required this.less,
    required this.more,
    required this.even,
    required this.skill,
    required this.luck,
    required this.ink,
    required this.axis,
    required this.label,
    required this.font,
  });
  final List<Outcome> outcomes;
  final int landed;
  final double expected;
  final double? best;
  final String word;
  final Color less, more, even, skill, luck, ink, axis, label;
  final String? font;

  void _text(
    Canvas canvas,
    String t,
    Offset at, {
    Color? color,
    TextAlign align = TextAlign.left,
    double fontSize = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: fontSize,
          color: color ?? label,
          fontFamily: font,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => -tp.width,
      TextAlign.center => -tp.width / 2,
      _ => 0.0,
    };
    tp.paint(canvas, at + Offset(dx, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (outcomes.isEmpty) return;
    const left = 30.0, right = 4.0, top = 8.0, bottom = 38.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    final topGain = max(outcomes.last.gain, best ?? 0);
    final max_ = max(topGain, 1e-9) * 1.08;
    double y(double g) => top + h - g / max_ * h;

    var x = left;
    Rect? yours;
    for (var i = 0; i < outcomes.length; i++) {
      final o = outcomes[i];
      final cw = o.chance * w;
      final r = Rect.fromLTRB(x, y(o.gain), x + max(cw - .4, .3), top + h);
      final color = o.gain > expected + 1e-9
          ? more
          : o.gain < expected - 1e-9
          ? less
          : even;
      canvas.drawRect(r, Paint()..color = color);
      if (i == landed) {
        yours = Rect.fromLTRB(
          r.left,
          min(r.top, top + h - 1.5),
          max(r.right, r.left + 1.5),
          top + h,
        );
      }
      x += cw;
    }
    canvas.drawLine(
      Offset(left, top + h),
      Offset(size.width - right, top + h),
      Paint()..color = axis,
    );
    // the expected gain (dashed), the best guess's (dotted)
    void dashed(double v, double on, double off, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      var dx = left;
      while (dx < size.width - right) {
        canvas.drawLine(
          Offset(dx, y(v)),
          Offset(min(dx + on, size.width - right), y(v)),
          p,
        );
        dx += on + off;
      }
    }

    dashed(expected, 5, 3, skill);
    if (best != null) dashed(best!, 1.5, 2.5, skill);
    // luck 0: the middle of the chance
    final mid = left + w / 2;
    canvas.drawLine(
      Offset(mid, top),
      Offset(mid, top + h),
      Paint()
        ..color = luck
        ..strokeWidth = 1.5,
    );
    _text(
      canvas,
      'luck 0',
      Offset(mid - 4, top),
      color: luck,
      align: TextAlign.right,
    );
    final hLabel =
        'H ${expected.toStringAsFixed(2)}'
        '${best == null ? '' : ' · H* ${best!.toStringAsFixed(2)}'}';
    _text(
      canvas,
      hLabel,
      Offset(size.width - right, y(max(expected, best ?? expected)) - 12),
      color: skill,
      align: TextAlign.right,
    );
    if (yours != null) {
      canvas.drawRect(
        yours,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final cx = yours.center.dx;
      final tri = Path()
        ..moveTo(cx - 5, top + h + 12)
        ..lineTo(cx + 5, top + h + 12)
        ..lineTo(cx, top + h + 4)
        ..close();
      canvas.drawPath(tri, Paint()..color = ink);
      _text(
        canvas,
        word,
        Offset(cx.clamp(left + 20, size.width - right - 20), top + h + 15),
        color: ink,
        align: TextAlign.center,
      );
    }
    _text(canvas, 'least gain', Offset(left, size.height - 12));
    _text(
      canvas,
      'most gain',
      Offset(size.width - right, size.height - 12),
      align: TextAlign.right,
    );
    _text(
      canvas,
      topGain.toStringAsFixed(0),
      Offset(left - 4, top),
      align: TextAlign.right,
    );
    _text(canvas, '0', Offset(left - 4, top + h - 11), align: TextAlign.right);
  }

  @override
  bool shouldRepaint(GainPainter old) =>
      old.outcomes != outcomes ||
      old.landed != landed ||
      old.expected != expected ||
      old.best != best;
}

/// One guess of the waterfall: where it starts (the bits gained so far), what it
/// was expected to add (H, in skill's colour), what luck added or took away, and
/// where the best guess would have been expected to land (H*, a thin line).
class WaterfallStep {
  const WaterfallStep(this.word, this.expected, this.gain, this.best);
  final String word;
  final double expected;
  final double gain;
  final double? best;
}

/// The bits gained guess by guess, racing to the bits needed to find the word
/// (the line at the right). Only the guesses up to the one on show are drawn.
class BitsWaterfall extends StatelessWidget {
  const BitsWaterfall({
    super.key,
    required this.steps,
    required this.needed,
    required this.current,
  });
  final List<WaterfallStep> steps;
  final double needed;

  /// The index of the guess on show, drawn bold.
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      height: steps.length * 34.0 + 44,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('bits-waterfall'),
        painter: WaterfallPainter(
          steps,
          needed,
          current,
          skill: skillColor(c),
          luck: luckColor(c),
          ink: c.onSurface,
          grid: c.outlineVariant,
          label: c.onSurface.withValues(alpha: dimAlpha),
          font: DefaultTextStyle.of(context).style.fontFamily,
        ),
      ),
    );
  }
}

class WaterfallPainter extends CustomPainter {
  WaterfallPainter(
    this.steps,
    this.needed,
    this.current, {
    required this.skill,
    required this.luck,
    required this.ink,
    required this.grid,
    required this.label,
    required this.font,
  });
  final List<WaterfallStep> steps;
  final double needed;
  final int current;
  final Color skill, luck, ink, grid, label;
  final String? font;

  void _text(
    Canvas canvas,
    String t,
    Offset at, {
    Color? color,
    bool bold = false,
    bool right = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: 10,
          color: color ?? label,
          fontFamily: font,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(right ? tp.width : 0, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 62.0, right = 36.0, rowH = 34.0;
    final top = max(12.0, (needed / 2).ceilToDouble() * 2);
    double x(double v) => left + v / top * (size.width - left - right);
    final bottom = size.height - 20;
    for (var t = 0.0; t <= top; t += 2) {
      canvas.drawLine(
        Offset(x(t), 18),
        Offset(x(t), bottom),
        Paint()..color = grid,
      );
      _text(canvas, t.round().toString(), Offset(x(t) - 3, size.height - 14));
    }
    var cum = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final y = i * rowH + 26, h = 14.0;
      final start = cum, end = cum + s.gain, exp = start + s.expected;
      _text(
        canvas,
        '${i + 1} ${s.word}',
        Offset(0, y + 1),
        color: i == current ? ink : label,
        bold: i == current,
      );
      if (i > 0) {
        canvas.drawLine(
          Offset(x(start), y - (rowH - h)),
          Offset(x(start), y),
          Paint()..color = label,
        );
      }
      final got = min(exp, end);
      canvas.drawRect(
        Rect.fromLTRB(x(start), y, max(x(got), x(start) + .5), y + h),
        Paint()..color = skill,
      );
      if (end > exp + .005) {
        canvas.drawRect(
          Rect.fromLTRB(x(exp), y, x(end), y + h),
          Paint()..color = luck,
        );
      } else if (end < exp - .005) {
        final p = Paint()
          ..color = luck
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final r = Rect.fromLTRB(x(end), y, x(exp), y + h);
        for (var dx = r.left; dx < r.right; dx += 5) {
          canvas.drawLine(
            Offset(dx, r.top),
            Offset(min(dx + 3, r.right), r.top),
            p,
          );
          canvas.drawLine(
            Offset(dx, r.bottom),
            Offset(min(dx + 3, r.right), r.bottom),
            p,
          );
        }
        canvas.drawLine(r.topLeft, r.bottomLeft, p);
        canvas.drawLine(r.topRight, r.bottomRight, p);
      }
      if (s.best != null) {
        final b = start + s.best!;
        final ly = y + h + 5;
        final p = Paint()
          ..color = skill
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x(start), ly), Offset(x(b), ly), p);
        canvas.drawLine(Offset(x(b), ly - 3), Offset(x(b), ly + 3), p);
      }
      _text(
        canvas,
        end.toStringAsFixed(2),
        Offset(x(max(end, exp)) + 5, y + 1),
        color: ink,
      );
      cum = end;
    }
    canvas.drawLine(
      Offset(x(needed), 16),
      Offset(x(needed), bottom),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
    _text(
      canvas,
      'needed ${needed.toStringAsFixed(2)} bits',
      Offset(x(needed) - 4, 2),
      color: ink,
      right: true,
    );
  }

  @override
  bool shouldRepaint(WaterfallPainter old) =>
      old.steps != steps || old.needed != needed || old.current != current;
}

/// The last try: nothing is left to learn, so the words that fit the clues are
/// all equally likely and the plot says so: one column each, all as tall as
/// the chance, 1 in N.
class EqualChancePlot extends StatelessWidget {
  const EqualChancePlot({
    super.key,
    required this.fitting,
    required this.guessAt,
    required this.luck,
    this.chances,
  });

  /// How many words fit the clues, and where the guess is among them (-1 if
  /// it does not fit).
  final int fitting;
  final int guessAt;

  /// The chance of each word that fits, in the order of the list, when they
  /// are not equal (null: every word is as likely as the next).
  final List<double>? chances;

  /// The luck of the last try: its chance, not a pool.
  final double luck;

  static const _listed = 40;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ch = chances;
    final chance = fitting == 0
        ? 0.0
        : ch == null
        ? 100 / fitting
        : (guessAt >= 0 && guessAt < ch.length ? ch[guessAt] * 100 : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption(
          ch == null
              ? 'every word that fits was as likely'
              : 'the words that fit, by how likely each was',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('chance-plot'),
            painter: EqualChancePainter(
              fitting,
              guessAt,
              chances: ch,
              base: c.onSurface.withValues(alpha: .3),
              yours: c.primary,
              axis: c.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          lastTryLine,
          key: ValueKey('chance-caption'),
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 6),
        metricLine(
          context,
          guessAt >= 0
              ? 'luck ${signedLuck(luck)}: your guess was one of the '
                    '${_n(fitting)} words that fit, a '
                    '${chance < 10 ? chance.toStringAsFixed(1) : chance.round()}'
                    '% chance.'
              : 'luck 0: your guess did not fit the clues, so it had no '
                    'chance.',
          'luck',
          key: const ValueKey('chance-luck'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        reviewLink(
          WikiPage.skillLuckRisk,
          label: 'how skill, luck and risk work',
        ),
      ],
    );
  }
}

class EqualChancePainter extends CustomPainter {
  EqualChancePainter(
    this.count,
    this.guessAt, {
    this.chances,
    required this.base,
    required this.yours,
    required this.axis,
  });
  final int count, guessAt;
  final List<double>? chances;
  final Color base, yours, axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final h = size.height * .75;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    final shown = min(count, EqualChancePlot._listed);
    final slot = size.width / shown;
    if (slot >= 3) {
      for (var i = 0; i < shown; i++) {
        final ch = chances;
        final hi = ch == null || ch.isEmpty
            ? h
            : max(2.0, ch[i] / ch.first * h);
        canvas.drawRect(
          Rect.fromLTWH(slot * i + slot * .1, size.height - hi, slot * .8, hi),
          Paint()..color = i == guessAt ? yours : base,
        );
      }
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - h, size.width, h),
        Paint()..color = base,
      );
    }
  }

  @override
  bool shouldRepaint(EqualChancePainter old) =>
      old.count != count || old.guessAt != guessAt;
}
