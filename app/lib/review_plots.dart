import 'dart:math';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'ui.dart';

/// Every way a guess could have come out against the words still possible,
/// for the plot of skill and luck. Each outcome (a pattern of greens, yellows
/// and greys) is one group of the words that would give it; the pool you land
/// in is the size of the group the answer is in.
class Outcomes {
  const Outcomes(this.sizes, this.expected, this.landed);

  /// The size of each outcome's group, largest first.
  final List<int> sizes;

  /// E, the average pool you would land in: the sum of the squared group
  /// sizes over the number of words.
  final double expected;

  /// Which of [sizes] is the outcome that happened.
  final int landed;

  /// N, the words that were possible.
  int get words => sizes.fold(0, (a, b) => a + b);

  /// The pool you landed in.
  int get pool => sizes[landed];

  /// The chance of landing in a bigger pool than you did, and in a smaller
  /// one, in percent. Luck is the first less the second.
  double get chanceBigger => _share((s) => s > pool);
  double get chanceSmaller => _share((s) => s < pool);

  double _share(bool Function(int s) test) {
    final n = words;
    return n == 0 ? 0 : sizes.where(test).fold(0, (a, b) => a + b) / n * 100;
  }

  /// Luck as in the table: [chanceLuck] of the pool landed in.
  double get luck => chanceLuck(sizes, pool);
}

/// The outcomes of [guess] against [eligible], and which one [answer] gave.
Outcomes outcomesOf(List<String> eligible, String guess, String answer) {
  final groups = <int, int>{};
  for (final w in eligible) {
    final key = patternCode(w, guess);
    groups[key] = (groups[key] ?? 0) + 1;
  }
  final order = groups.keys.toList()
    ..sort((a, b) {
      final c = groups[b]!.compareTo(groups[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final sizes = [for (final k in order) groups[k]!];
  final n = eligible.length;
  final expected = n == 0 ? 0.0 : sizes.fold<int>(0, (a, s) => a + s * s) / n;
  final landed = max(0, order.indexOf(patternCode(answer, guess)));
  return Outcomes(sizes, expected, landed);
}

/// Where one column of the plot sits.
class Slot {
  const Slot(this.index, this.x0, this.x1);

  /// Which outcome, as in [Outcomes.sizes].
  final int index;
  final double x0, x1;

  double get width => x1 - x0;
  double get center => (x0 + x1) / 2;
}

/// The columns of the plot in a plot [width] wide, largest pool first. Each
/// column is as wide as the chance of landing there (its share of the words),
/// so the horizontal middle of the plot is the median outcome, and how far
/// from it a column's centre lies is its luck: the middle is 0% luck, the far
/// left (the biggest pool, the likeliest outcomes) is unlucky, the far right
/// lucky.
List<Slot> splitSlots(Outcomes o, double width) {
  final n = o.words;
  final slots = <Slot>[];
  var x = 0.0;
  for (var i = 0; i < o.sizes.length; i++) {
    final w = n == 0 ? 0.0 : o.sizes[i] / n * width;
    slots.add(Slot(i, x, x + w));
    x += w;
  }
  return slots;
}

String _n(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String _w(double v) => v < 10 ? v.toStringAsFixed(1) : _n(v.round());

/// Skill and luck on one plot. A column for every way the guess could have come
/// out, as tall as the pool it leaves and as wide as the chance of it, the
/// biggest pools (the likeliest) on the left.
///
/// * Skill is about the dashed line, E: the pool the guess leaves on average,
///   measured between N (no split at all) and the dotted line, E*, what the best
///   real word in the list leaves. The lower E sits, the better the guess.
/// * Luck is about the column you landed in: the middle of the plot is 0%, to
///   its left a bigger pool than half the outcomes, to its right a smaller one.
class SplitPlot extends StatelessWidget {
  const SplitPlot({
    super.key,
    required this.outcomes,
    required this.best,
    required this.skill,
    required this.luck,
    this.skillReady = true,
  });
  final Outcomes outcomes;

  /// E*, the smallest expected pool any real guess leaves.
  final double best;

  /// The skill and luck of the guess, as in the table.
  final double skill, luck;

  /// False while E* is still being worked out.
  final bool skillReady;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final o = outcomes;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    Widget key(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: dim),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('skill and luck'),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) => CustomPaint(
              key: const ValueKey('split-plot'),
              painter: SplitPainter(
                o,
                splitSlots(o, box.maxWidth),
                best: best,
                base: c.onSurface.withValues(alpha: .3),
                yours: c.primary,
                expected: c.secondary,
                bestLine: yellowOf(c),
                axis: c.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text('unlucky', style: dim)),
            Text('0% luck', style: dim),
            Expanded(
              child: Text('lucky', textAlign: TextAlign.right, style: dim),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 2,
          children: [
            key(c.primary, 'where you landed'),
            key(c.secondary, 'average pool'),
            key(yellowOf(c), 'best real guess'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          skillReady
              ? 'skill ${skill.round()}: this guess leaves about ${_w(o.expected)} '
                    'of the ${_n(o.words)} words on average. no split at all '
                    'would leave ${_n(o.words)}; the best real guess leaves '
                    'about ${_w(best)}.'
              : 'skill: working out the best real guess…',
          key: const ValueKey('skill-caption'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(
          'you landed in ${_n(o.pool)} ${o.pool == 1 ? 'word' : 'words'}: luck '
          '${luckText(luck)}. you would have landed in a bigger pool '
          '${o.chanceBigger.round()}% of the time and in a smaller one '
          '${o.chanceSmaller.round()}%.',
          key: const ValueKey('luck-caption'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class SplitPainter extends CustomPainter {
  SplitPainter(
    this.o,
    this.slots, {
    required this.best,
    required this.base,
    required this.yours,
    required this.expected,
    required this.bestLine,
    required this.axis,
  });
  final Outcomes o;
  final List<Slot> slots;
  final double best;
  final Color base, yours, expected, bestLine, axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (o.sizes.isEmpty) return;
    final maxSize = o.sizes.first;
    double h(num s) => max(1.5, s / maxSize * size.height);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    // the columns, side by side: where there are many they read as one area
    for (final s in slots) {
      final landed = s.index == o.landed;
      final gap = s.width > 8 ? 1.0 : 0.0;
      canvas.drawRect(
        Rect.fromLTRB(
          s.x0 + gap,
          size.height - h(o.sizes[s.index]),
          max(s.x1 - gap, s.x0 + gap + (landed ? 2.0 : 0.5)),
          size.height,
        ),
        Paint()
          ..color = landed ? yours : base
          ..isAntiAlias = s.width < 3,
      );
    }
    // the middle of the plot: 0% luck
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    // E, the average pool (dashed) and E*, the best real guess's (dotted)
    void line(double value, Color color, double dash, double gap) {
      final y = size.height - h(value);
      final p = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset(min(x + dash, size.width), y), p);
      }
    }

    line(o.expected, expected, 8, 4);
    line(best, bestLine, 2, 3);
    // where you landed: always marked, however thin the column
    for (final s in slots) {
      if (s.index != o.landed) continue;
      final top = size.height - h(o.sizes[o.landed]);
      final p = Paint()
        ..color = yours
        ..strokeWidth = 2;
      canvas.drawLine(Offset(s.center, top), Offset(s.center, size.height), p);
      canvas.drawCircle(Offset(s.center, top), 3.5, p);
    }
  }

  @override
  bool shouldRepaint(SplitPainter old) =>
      old.o != o || old.slots != slots || old.best != best;
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
  });

  /// How many words fit the clues, and where the guess is among them (-1 if
  /// it does not fit).
  final int fitting;
  final int guessAt;

  /// The luck of the last try: its chance, not a pool.
  final double luck;

  static const _listed = 40;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final chance = fitting == 0 ? 0.0 : 100 / fitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('every word that fits was as likely'),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('chance-plot'),
            painter: EqualChancePainter(
              fitting,
              guessAt,
              base: c.onSurface.withValues(alpha: .3),
              yours: c.primary,
              axis: c.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_n(fitting)} ${fitting == 1 ? 'word fits' : 'words fit'} the '
          'clues, each with the same chance: 1 in ${_n(fitting)} '
          '(${chance < 10 ? chance.toStringAsFixed(1) : chance.round()}%). '
          '${guessAt >= 0 ? 'your guess was one of them' : 'your guess did not fit the clues, so it had no chance'}'
          '. luck ${luckText(luck)}: the outcome, less that chance.',
          key: const ValueKey('chance-caption'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class EqualChancePainter extends CustomPainter {
  EqualChancePainter(
    this.count,
    this.guessAt, {
    required this.base,
    required this.yours,
    required this.axis,
  });
  final int count, guessAt;
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
        canvas.drawRect(
          Rect.fromLTWH(slot * i + slot * .1, size.height - h, slot * .8, h),
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
