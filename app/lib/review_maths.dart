import 'package:flutter/material.dart';

import 'review_text.dart';
import 'ui.dart';
import 'wiki_links.dart';

/// What a pill (skill, luck, risk, bits) of the review explains: the idea, a
/// worked example with real numbers, and the formulas. Copied from the review
/// mockup.
class MeasureHelp {
  const MeasureHelp(this.intro, this.example, this.formulas, this.where);
  final String intro;
  final String example;
  final List<String> formulas;
  final String where;
}

const measureHelp = <String, MeasureHelp>{
  'skill': MeasureHelp(
    'Skill is how much a guess is expected to teach you, judged before you '
        'know the answer. The answer does not change it. 100 means as informative '
        'as the best guess available. 0 means the guess tells you nothing.',
    '8 words are possible. The best guess could split them into 8 groups of '
        '1, so H* = log₂ 8 = 3 bits. Guess A splits them 4, 2, 1 and 1:\n\n'
        'group    chance          bits gained\n'
        '4 words  4 ÷ 8 = 50%     log₂(8 ÷ 4) = 1\n'
        '2 words  2 ÷ 8 = 25%     log₂(8 ÷ 2) = 2\n'
        '1 word   1 ÷ 8 = 12.5%   log₂(8 ÷ 1) = 3\n'
        '1 word   1 ÷ 8 = 12.5%   log₂(8 ÷ 1) = 3\n\n'
        'H = 0.5×1 + 0.25×2 + 0.125×3 + 0.125×3 = 1.75 bits\n'
        'skill = 1.75 ÷ 3 × 100 = 58\n\n'
        'Think of yes/no questions: a question that splits the options evenly is '
        'worth more than one that leaves most of them standing.',
    ['skill = H ÷ H* × 100', 'H = Σ q(o) · log₂(N ÷ s(o)),   q(o) = s(o) ÷ N'],
    'o an outcome (a pattern of tiles) · s(o) words that give it · N words '
        'still possible · H* the largest H among all accepted guesses',
  ),
  'luck': MeasureHelp(
    'Luck is which outcome you actually got. After a guess, the answer sits '
        'in one group. Some groups are small and teach you a lot. Some are large '
        'and teach you little. Luck compares your group with every group the '
        'guess could have given. +100% is the best outcome, −100% the worst, 0% '
        'the middle.',
    'Same guess A as under skill, H = 1.75 bits.\n\n'
        'Answer in a group of 1: gain 3 bits\n'
        '  P(less) = 50% + 25% = 75%, P(more) = 0%\n'
        '  luck = +75%, luck in bits = 3 − 1.75 = +1.25\n\n'
        'Answer in the group of 4: gain 1 bit\n'
        '  P(less) = 0%, P(more) = 50%\n'
        '  luck = −50%, luck in bits = 1 − 1.75 = −0.75\n\n'
        'Luck says nothing about how good the guess was. A poor guess can be '
        'lucky and a great guess unlucky.',
    [
      'luck = 100 · [ P(G < g) − P(G > g) ]',
      '−100 ≤ luck ≤ 100',
      'luck in bits: ε = g − H,   E[ε] = 0',
    ],
    'G the gain of the outcome the unknown answer will give · g the gain you '
        'got · ε luck in bits, which averages 0 over all answers',
  ),
  'risk': MeasureHelp(
    'Risk is how much a guess gambles on a lucky tail. A risky guess usually '
        'gains less than expected, and sometimes gains a lot. A safe guess gains '
        'about the same whatever the answer. Risk belongs to the guess, not to '
        'the result: whether the gamble paid off is luck.',
    '8 words are possible.\n\n'
        'Guess B splits 2 / 2 / 2 / 2\n'
        '  every outcome gains 2 bits = H, so D = 0: no risk\n\n'
        'Guess A splits 4 / 2 / 1 / 1, H = 1.75\n'
        '  P(less) = 50% (the 4), P(more) = 50%, D = 0\n\n'
        'Guess C splits 5 / 1 / 1 / 1\n'
        '  gains 0.68 bits (5 words) or 3 bits (1 word)\n'
        '  H = 5/8 × 0.68 + 3/8 × 3 = 1.55\n'
        '  P(less) = 62.5%, P(more) = 37.5%, D = 25%\n'
        '  if D* = 50%, risk = 25 ÷ 50 × 100 = 50\n\n'
        'Guess C almost always leaves 5 words. It pays off only when the answer '
        'is one of the 3 loners.',
    ['D = max{ 0, P(G < H) − P(G > H) }', 'risk = 100 · D ÷ D*'],
    'G the gain of the outcome the unknown answer will give · H = E[G] the '
        'expected gain · D* the largest D among all accepted guesses',
  ),
  'bits': MeasureHelp(
    'A bit is the information in one yes/no answer with even odds. Each bit '
        'halves the number of possible words. Finding one word among N takes '
        'log₂ N bits, however you play. Each guess supplies some of them.',
    '64 words, a guess leaves 8:  log₂(64 ÷ 8) = 3 bits\n'
        '8 words, a guess leaves 1:   log₂(8 ÷ 1)  = 3 bits\n'
        'total 6 bits = log₂ 64, all the bits needed\n\n'
        '3,000 words need log₂ 3,000 = 11.55 bits\n\n'
        'Expected gain is what a guess gives on average. The bits it actually '
        'gives depend on which group the answer is in.',
    [
      'g(t) = log₂( N(t−1) ÷ N(t) )',
      'Σ g(t) = log₂ N(0)',
      'H ≤ log₂ 3⁵ = 7.92',
    ],
    'N(t) words still possible after guess t · g(t) bits gained by guess t · '
        'the last guess takes everything that is left',
  ),
};

/// The dialog a pill opens: the idea, a worked example and the maths.
void showMeasureHelp(BuildContext context, String which) {
  final c = Theme.of(context).colorScheme;
  final h = measureHelp[which]!;
  const body = TextStyle(fontSize: 13, height: 1.5);
  final mono = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: c.onSurface.withValues(alpha: .85),
  );
  Widget sub(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Caption(t),
  );
  showHairlineDialog<void>(
    context,
    title: which,
    titleColor: metricColor(c, which),
    children: [
      Text.rich(TextSpan(children: measureSpans(c, h.intro)), style: body),
      sub('example'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text.rich(
          TextSpan(children: measureSpans(c, h.example)),
          style: mono,
          softWrap: false,
        ),
      ),
      sub('the maths'),
      for (final f in h.formulas)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: measureSpans(c, f)),
            style: mono.copyWith(fontSize: 13),
          ),
        ),
      const SizedBox(height: 4),
      Text(
        h.where,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: c.onSurface.withValues(alpha: dimAlpha),
        ),
      ),
      reviewLink(WikiPage.skillLuckRisk, label: 'how $which works'),
    ],
  );
}

/// One calculation on the step page: a heading with its info dot, the lines
/// that go into the number, a rule, and the result in the measure's colour.
class MeasureBlock extends StatelessWidget {
  const MeasureBlock({
    super.key,
    required this.title,
    required this.which,
    required this.tip,
    required this.rows,
    this.result,
    this.note,
  });
  final String title;
  final String which;
  final String tip;
  final List<(String, String)> rows;

  /// The formula as worked out and its value.
  final (String, String)? result;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colour = metricColor(c, which);
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    Widget line(String a, String b, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: color ?? c.onSurface.withValues(alpha: .8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                b,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? c.onSurface,
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colour,
                ),
              ),
              const SizedBox(width: 6),
              InfoDot(tip, title: title),
            ],
          ),
          const SizedBox(height: 8),
          for (final (a, b) in rows) line(a, b),
          if (result != null) ...[
            Divider(height: 10, color: c.outlineVariant),
            line(result!.$1, result!.$2, color: colour, bold: true),
          ],
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: TextStyle(fontSize: 11, height: 1.5, color: dim),
              ),
            ),
        ],
      ),
    );
  }
}

/// The info-dot texts of the blocks, from the mockup.
const blockTips = <String, String>{
  'plot':
      'Each column is one possible outcome of your guess. Its width is the '
      'chance of that outcome. Its height is the bits it would gain. The '
      'area under all the columns is the expected gain, H. The yellow line '
      'splits the chance in half: the middle outcome, where luck is 0.',
  'skill':
      'Skill is how many bits the guess is expected to gain, averaged over '
      'all possible answers, compared with the best guess. Any answer gives '
      'the same skill. H* comes from scoring every accepted word as a '
      'guess, so it is not on the plot.',
  'risk':
      'Risk is how much the guess gambles on the tail. A risky guess usually '
      'gains less than expected and sometimes much more. A gain of exactly H '
      'counts for neither side. Risk is scored against the riskiest guess, '
      'as skill is against the best. D* comes from scoring every accepted '
      'word.',
  'luck':
      'The answer decides luck. Your gain is outlined on the plot. Luck is '
      'the chance of gaining less than you did minus the chance of gaining '
      'more, from −100% to +100%.',
  'bits':
      'A game ends when the word is found. Finding one among N words takes '
      'log₂ N bits, whatever you play. Each guess adds its expected gain '
      '(blue, your skill), then luck (yellow adds, dashed takes away). The '
      'thin line shows where the best guess was expected to land. The last '
      'guess takes everything that is left. Risk is not added: it gauges the '
      'gamble, and whether the gamble paid off is luck.',
};
