import 'package:flutter/material.dart';

import 'history.dart';
import 'playstyle.dart';
import 'ui.dart';

/// The popup of a guess's type in the review table: what the guess was counted
/// as (a gambler, a maximiser, an eliminator in the early game, a closer or a
/// prober at the end), in a line, and the calculation on this guess's own
/// numbers. A guess counted as nothing says why not.
void showBehaviourPopup(BuildContext context, GuessRow row) {
  final c = Theme.of(context).colorScheme;
  final b = behaviourOf(row);
  final phase = phaseOf(row.before, row.greens);
  const body = TextStyle(fontSize: 13, height: 1.5);
  final dim = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: c.onSurface.withValues(alpha: dimAlpha),
  );
  Widget sub(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Caption(t),
  );
  showHairlineDialog<void>(
    context,
    title: b?.label ?? 'not counted',
    titleColor: b == null ? null : behaviourColor(c, b.label),
    leading: b == null
        ? null
        : TablerIcon(
            b.icon,
            size: chooserIconSize,
            color: behaviourColor(c, b.label),
          ),
    children: [
      Text(
        b == null ? _whyNot(row, phase) : b.what,
        key: const ValueKey('behaviour-what'),
        style: body,
      ),
      if (phase != null && phase != Phase.middle) ...[
        const SizedBox(height: 6),
        Text(
          '${phase.name} game: ${_phaseRule(phase)}. this guess had '
          '${row.before} ${row.before == 1 ? 'word' : 'words'} possible and '
          '${row.greens} ${row.greens == 1 ? 'green' : 'greens'}.',
          style: dim,
        ),
      ],
      if (b != null) ...[
        sub('the calculation'),
        Text(
          _calculation(b, row),
          key: const ValueKey('behaviour-calc'),
          style: body,
        ),
        const SizedBox(height: 4),
        Text('counted when ${b.rule}.', style: dim),
      ],
    ],
  );
}

String _pct(double v) => v < 10 ? '${v.toStringAsFixed(1)}%' : '${v.round()}%';

String _phaseRule(Phase p) => p == Phase.early
    ? '$earlyFrom or more words possible'
    : '$endUpTo or fewer words possible, or $endGreens or more greens';

/// The numbers of [row] against the rule of [b].
String _calculation(Behaviour b, GuessRow row) => switch (b) {
  Behaviour.gambler =>
    'risk = ${row.risk?.round() ?? '–'}. counted when $gamblerRisk or more.',
  Behaviour.maximiser =>
    'rank = the share of the guesses scored that gain more than this one = '
        '${row.rank == null ? '–' : _pct(row.rank!)}. counted when '
        '$topRank% or less.',
  Behaviour.eliminator =>
    'new letters = letters of the guess never used before = ${row.fresh}. '
        'counted when $freshLetters or more, and the guess is neither a '
        'gambler nor a maximiser.',
  Behaviour.closer =>
    'the guess ${row.fits ? 'fits' : 'does not fit'} the '
        '${row.before} words still possible. counted when it fits.',
  Behaviour.prober =>
    'the guess does not fit the ${row.before} words still possible, and its '
        'rank is ${row.rank == null ? '–' : _pct(row.rank!)}. counted when '
        '$topRank% or less and 3 or more words are left.',
};

/// Why a guess was counted as no type.
String _whyNot(GuessRow row, Phase? phase) => switch (phase) {
  null => 'with one word left there was nothing to choose.',
  Phase.middle =>
    'between $endUpTo and $earlyFrom words possible, with fewer than '
        '$endGreens greens, guesses are not counted: the middle game is where '
        'the early habit hands over to the end habit.',
  Phase.early =>
    'it did not meet the rule of a gambler, a maximiser or an eliminator.',
  Phase.end => 'it did not meet the rule of a closer or a prober.',
};
