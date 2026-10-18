import 'dart:math';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'ui.dart';

/// Every way a guess could have come out against the words still possible,
/// for the luck plot. Each outcome (a pattern of greens, yellows and greys) is
/// one group of the words that would give it; the pool you land in is the size
/// of the group the answer is in.
class Outcomes {
  const Outcomes(this.sizes, this.expected, this.landed);

  /// The size of each outcome's group, largest first.
  final List<int> sizes;

  /// The average pool you would land in: the sum of the squared group sizes
  /// over the number of words.
  final double expected;

  /// Which of [sizes] is the outcome that happened.
  final int landed;

  int get words => sizes.fold(0, (a, b) => a + b);

  /// The luck of the outcome, as in the table: how much smaller than
  /// [expected] the pool you landed in was, in percent.
  double get luck =>
      expected <= 0 ? 0 : (expected - sizes[landed]) / expected * 100;
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

/// Where one column of the luck plot sits.
class Slot {
  const Slot(this.index, this.x0, this.x1, {required this.unlucky});

  /// Which outcome, as in [Outcomes.sizes].
  final int index;
  final double x0, x1;

  /// A pool larger than average, on the left of the middle.
  final bool unlucky;

  double get width => x1 - x0;
  double get center => (x0 + x1) / 2;
}

/// The columns of the luck plot in a plot [width] wide, largest pool first.
/// Zero luck is the horizontal midpoint: the outcomes that leave a larger pool
/// than average fill the left half, the rest the right half, each half evenly,
/// so the columns still run from the largest pool to the smallest, left to
/// right, and the middle is exactly average.
List<Slot> luckSlots(Outcomes o, double width) {
  final left = [
    for (var i = 0; i < o.sizes.length; i++)
      if (o.sizes[i] > o.expected) i,
  ];
  final right = [
    for (var i = 0; i < o.sizes.length; i++)
      if (o.sizes[i] <= o.expected) i,
  ];
  final half = width / 2;
  return [
    for (var k = 0; k < left.length; k++)
      Slot(
        left[k],
        half / left.length * k,
        half / left.length * (k + 1),
        unlucky: true,
      ),
    for (var k = 0; k < right.length; k++)
      Slot(
        right[k],
        half + half / right.length * k,
        half + half / right.length * (k + 1),
        unlucky: false,
      ),
  ];
}

/// Columns narrower than this are drawn as one area instead.
const _minColumn = 3.0;

String _n(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// How the guess ranked among every guess I scored: a column for each, best on
/// the left, as tall as its skill, with your guess marked where it stands. With
/// many guesses the columns become one area.
class SkillPlot extends StatelessWidget {
  const SkillPlot({
    super.key,
    required this.landscape,
    required this.skill,
    required this.guess,
  });
  final Landscape landscape;
  final double skill;
  final String guess;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final skills = landscape.skills;
    final rank = landscape.rankOf(skill);
    final best = landscape.top.isEmpty ? null : landscape.top.first;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('how your guess ranked'),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('skill-plot'),
            painter: SkillPainter(
              skills,
              rank,
              skill,
              base: c.onSurface.withValues(alpha: .3),
              yours: c.primary,
              best: c.secondary,
              axis: c.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('best', style: dim),
            Text('worst', style: dim),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          rank == 0
              ? '$guess scored ${skill.round()}, as good as any of the '
                    '${_n(skills.length)} guesses I scored.'
              : '$guess scored ${skill.round()}: ahead of '
                    '${landscape.percentile(skill).round()}% of the '
                    '${_n(skills.length)} guesses I scored'
                    '${best == null ? '' : '. the best, ${best.word}, scored ${best.skill.round()}'}.',
          key: const ValueKey('skill-caption'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class SkillPainter extends CustomPainter {
  SkillPainter(
    this.skills,
    this.rank,
    this.skill, {
    required this.base,
    required this.yours,
    required this.best,
    required this.axis,
  });
  final List<double> skills;
  final int rank;
  final double skill;
  final Color base, yours, best, axis;

  @override
  void paint(Canvas canvas, Size size) {
    final n = skills.length;
    if (n == 0) return;
    double h(double s) => max(2.0, s.clamp(0, 100) / 100 * size.height);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    final slot = size.width / n;
    final bars = slot >= _minColumn;
    Color colorOf(int i) => i == rank ? yours : (i == 0 ? best : base);
    if (bars) {
      for (var i = 0; i < n; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            slot * i + slot * .1,
            size.height - h(skills[i]),
            slot * .8,
            h(skills[i]),
          ),
          Paint()..color = colorOf(i),
        );
      }
      return;
    }
    final cols = max(2, (size.width / 2).floor());
    final path = Path()..moveTo(0, size.height);
    for (var k = 0; k < cols; k++) {
      final i = (k / (cols - 1) * (n - 1)).round();
      path.lineTo(k / (cols - 1) * size.width, size.height - h(skills[i]));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = base);
    for (final i in {0, rank.clamp(0, n - 1)}) {
      final x = n == 1 ? 0.0 : i / (n - 1) * size.width;
      final y = size.height - h(skills[i]);
      final p = Paint()
        ..color = colorOf(i)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, y), Offset(x, size.height), p);
      canvas.drawCircle(Offset(x, y), 3, p);
    }
  }

  @override
  bool shouldRepaint(SkillPainter old) =>
      old.skills != skills || old.rank != rank || old.skill != skill;
}

/// Where you could have landed, and where you did: a column for each possible
/// outcome of the guess, as tall as the pool it leaves, largest first. Zero
/// luck is the middle; the pools to its left are larger than average (unlucky),
/// to its right smaller (lucky). The outcome that happened is marked and the
/// average pool is a line. With many outcomes the columns become one area.
class LuckPlot extends StatelessWidget {
  const LuckPlot({super.key, required this.outcomes});
  final Outcomes outcomes;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final o = outcomes;
    final landedSize = o.sizes[o.landed];
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    String fmt(double v) =>
        v < 10 ? v.toStringAsFixed(1) : v.round().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('where you could have landed'),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) => CustomPaint(
              key: const ValueKey('luck-plot'),
              painter: LuckPainter(
                o,
                luckSlots(o, box.maxWidth),
                base: c.onSurface.withValues(alpha: .3),
                yours: c.primary,
                average: c.secondary,
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
        const SizedBox(height: 4),
        Text(
          'you landed in $landedSize ${landedSize == 1 ? 'word' : 'words'}; '
          'on average it would have been ${fmt(o.expected)}. each column is '
          'one way the guess could have come out, as tall as the pool it '
          'leaves; the middle is exactly average.',
          key: const ValueKey('luck-caption'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class LuckPainter extends CustomPainter {
  LuckPainter(
    this.o,
    this.slots, {
    required this.base,
    required this.yours,
    required this.average,
    required this.axis,
  });
  final Outcomes o;
  final List<Slot> slots;
  final Color base, yours, average, axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (o.sizes.isEmpty) return;
    final maxSize = o.sizes.first;
    double h(num s) => max(2.0, s / maxSize * size.height);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    // the middle: zero luck
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    for (final side in [true, false]) {
      final mine = [
        for (final s in slots)
          if (s.unlucky == side) s,
      ];
      if (mine.isEmpty) continue;
      if (mine.first.width >= _minColumn) {
        for (final s in mine) {
          final gap = s.width > 6 ? 1.0 : 0.0;
          canvas.drawRect(
            Rect.fromLTRB(
              s.x0 + gap,
              size.height - h(o.sizes[s.index]),
              s.x1 - gap,
              size.height,
            ),
            Paint()..color = s.index == o.landed ? yours : base,
          );
        }
      } else {
        // too many to read as columns: one area over the same slots
        final path = Path()..moveTo(mine.first.x0, size.height);
        for (final s in mine) {
          final y = size.height - h(o.sizes[s.index]);
          path
            ..lineTo(s.x0, y)
            ..lineTo(s.x1, y);
        }
        path
          ..lineTo(mine.last.x1, size.height)
          ..close();
        canvas.drawPath(path, Paint()..color = base);
      }
    }
    // the average pool, as a dashed line across
    final ey = size.height - h(o.expected);
    final dash = Paint()
      ..color = average
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, ey), Offset(min(x + 4, size.width), ey), dash);
    }
    // where you landed: always marked, whatever the style of the plot
    for (final s in slots) {
      if (s.index != o.landed) continue;
      final top = size.height - h(o.sizes[o.landed]);
      final p = Paint()
        ..color = yours
        ..strokeWidth = 2;
      if (s.width < _minColumn) {
        canvas.drawLine(
          Offset(s.center, top),
          Offset(s.center, size.height),
          p,
        );
      }
      canvas.drawCircle(Offset(s.center, top), 3.5, p);
    }
  }

  @override
  bool shouldRepaint(LuckPainter old) => old.o != o || old.slots != slots;
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
    if (slot >= _minColumn) {
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
