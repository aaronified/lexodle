import 'dart:math';

import 'package:flutter/material.dart';

import 'learn_styles.dart';
import 'logic.dart' hide freshLetters;
import 'main.dart';
import 'playstyle.dart';
import 'styles_lesson.dart';
import 'ui.dart';
import 'words.dart';

/// The styles, as a lesson: the three habits of the opening and the two of the
/// end that a playstyle is made of, each with the rule that counts a guess as it,
/// when it is the right one to play, and a real example worked out for your
/// language and length. Luck is explained at the end, not taught: it is what the
/// answer did, and it averages nothing. Nothing here is scored.
class StylesPage extends StatefulWidget {
  const StylesPage({super.key, required this.bank});
  final WordBank bank;

  @override
  State<StylesPage> createState() => _StylesPageState();
}

/// When each habit is the right one to play, in a line or two.
String whenRight(Behaviour b) => switch (b) {
  Behaviour.maximiser =>
    'the habit to learn. the best split keeps every later guess cheap, and it '
        'is the guess a player with the list in their head plays. the opening '
        'lesson has the words.',
  Behaviour.eliminator =>
    'right when you do not have the best words to hand: new letters clear the '
        'board, and it never wastes a letter. but it gives up skill, which is '
        'what the example below costs.',
  Behaviour.gambler =>
    'right only when you must catch up. it usually gains less than expected '
        'and now and then much more; on average it loses skill, and luck '
        'decides the rest.',
  Behaviour.closer =>
    'right when a word that fits wins as often as anything else can: with few '
        'words left, or one try. it ends the game on the spot when it is '
        'right. closing trains it.',
  Behaviour.prober =>
    'right when many words look alike and tries remain (the trap of a word '
        'that differs in one letter): spend a guess that cannot win to split '
        'them, so the next is nearly sure. closing trains it.',
};

class _StylesPageState extends State<StylesPage> {
  late final int length = appState.length;
  late final List<String> _all = widget.bank.guessable(length);
  late final Map<String, int>? _law = widget.bank.law(length, appState.draw);

  OpeningPosition? position;
  List<OpeningExample> openings = const [];
  LuckSpread? luck;
  final closings = <Behaviour, ClosingExample>{};
  bool closingDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pos = await openingPosition(
      bank: widget.bank,
      length: length,
      draw: appState.draw,
    );
    if (!mounted) return;
    final ex = openingExamples(pos: pos, guessable: _all, weights: _law);
    final gambler = ex.firstWhere((e) => e.behaviour == Behaviour.gambler);
    setState(() {
      position = pos;
      openings = ex;
      luck = luckSpread(pos.eligible, gambler.word, _law);
    });
    await closingExamples(
      bank: widget.bank,
      length: length,
      draw: appState.draw,
      onFound: (e) {
        if (mounted) setState(() => closings[e.behaviour] = e);
      },
    );
    if (mounted) setState(() => closingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagBadge(widget.bank.language.flag, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'the styles · $lang · $length',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(19, 4, 19, 28),
              children: [
                const Caption(
                  'your playstyle is two habits: one in the opening, one at '
                  'the end. every guess you make counts as one of five '
                  'habits, or none',
                ),
                const SizedBox(height: 16),
                const Caption(
                  'the opening · $earlyFrom or more words possible',
                ),
                const SizedBox(height: 8),
                for (final b in [
                  Behaviour.maximiser,
                  Behaviour.eliminator,
                  Behaviour.gambler,
                ])
                  _card(c, dim, b, _openingBody(c, dim, b)),
                const SizedBox(height: 10),
                const Caption(
                  'the end · $endUpTo or fewer words, or $endGreens greens known',
                ),
                const SizedBox(height: 8),
                for (final b in [Behaviour.closer, Behaviour.prober])
                  _card(c, dim, b, _closingBody(c, dim, b)),
                const SizedBox(height: 10),
                const Caption('between them'),
                const SizedBox(height: 6),
                Text(
                  'from $endUpTo to ${earlyFrom - 1} words, with under '
                  '$endGreens greens, is the middle game: it counts for '
                  'no habit.',
                  style: dim,
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                _luck(c, dim),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                _grid(c, dim),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme c, TextStyle dim, Behaviour b, Widget body) {
    return Padding(
      key: ValueKey('style-card-${b.label}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(border: Border.all(color: c.outlineVariant)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TablerIcon(b.icon, size: 22, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  b.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(b.what),
            const SizedBox(height: 2),
            Text('counted when: ${b.rule}', style: dim),
            const SizedBox(height: 8),
            Text(whenRight(b), key: ValueKey('style-when-${b.label}')),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }

  Widget _openingBody(ColorScheme c, TextStyle dim, Behaviour b) {
    final pos = position;
    if (pos == null) {
      return Text('working out an example…', style: dim);
    }
    final e = openings.firstWhere((x) => x.behaviour == b);
    final p = e.profile;
    final top = e.walk.groups.map((g) => g.words.length).reduce(max);
    return Column(
      key: ValueKey('style-example-${b.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pos.marks.isEmpty
              ? 'an example, at the start of a game:'
              : 'an example, after ${pos.first} showed these colours '
                    '(${pos.eligible.length} words fit):',
          style: dim,
        ),
        if (pos.marks.isNotEmpty) ...[
          const SizedBox(height: 4),
          _tiles(pos.first, pos.marks, 18),
        ],
        const SizedBox(height: 6),
        Text(
          e.word,
          style: TextStyle(
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
            color: c.primary,
          ),
        ),
        Text(
          'skill ${p.skill.round()} · risk ${p.risk?.round() ?? '–'} · rank '
          '${p.rank?.round() ?? '–'}% · ${p.fresh} fresh letters',
          key: ValueKey('style-numbers-${b.label}'),
        ),
        Text(
          '${e.walk.groups.length} groups · about '
          '${e.walk.expectedLeft.toStringAsFixed(1)} of ${e.walk.words} words '
          'left · the biggest group $top',
          style: dim,
        ),
        if (b == Behaviour.eliminator && e.qualifies)
          Text(
            'it gives up ${(100 - p.skill).round()} skill against the best '
            'guess for clearing letters',
            style: dim,
          ),
        const SizedBox(height: 4),
        Text(styleLine(p), style: dim),
        if (!e.qualifies)
          Text(
            'no guess in this position counts as a ${b.label}; this is the '
            'nearest',
            style: TextStyle(fontSize: 11, color: c.error),
          ),
      ],
    );
  }

  Widget _closingBody(ColorScheme c, TextStyle dim, Behaviour b) {
    final e = closings[b];
    if (e == null) {
      return Text(
        closingDone
            ? 'no example of this was found in the positions tried'
            : 'looking for an example…',
        style: dim,
      );
    }
    final q = e.question;
    final best = e.best;
    final other = e.other;
    final fits = q.eligible.length;
    return Column(
      key: ValueKey('style-example-${b.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'an example: $fits words fit, ${q.triesLeft} tries left',
          style: dim,
        ),
        const SizedBox(height: 4),
        for (var g = 0; g < q.guesses.length; g++)
          _tiles(q.guesses[g], q.marks[g], 18),
        const SizedBox(height: 6),
        for (final o in [
          ...q.options,
        ]..sort((a, b) => (b.win ?? 0).compareTo(a.win ?? 0)))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${o.word} · ${q.eligible.contains(o.word) ? 'fits' : 'cannot win now'}'
              ' · wins in time ${((o.win ?? 0) * 100).round()}%'
              '${identical(o, best) ? '  ← the best' : ''}',
              style: identical(o, best)
                  ? TextStyle(color: c.primary, fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
        const SizedBox(height: 4),
        for (final line in q.closingLines(best)) Text(line, style: dim),
        if (other != null)
          Text(
            b == Behaviour.closer
                ? 'a probe such as ${other.word} would win only '
                      '${((other.win ?? 0) * 100).round()}%'
                : 'a word that fits, ${other.word}, would win only '
                      '${((other.win ?? 0) * 100).round()}%',
            style: dim,
          ),
      ],
    );
  }

  Widget _tiles(String word, List<Mark> marks, double size) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        for (var i = 0; i < word.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: MarkTile(word[i], mark: marks[i], size: size),
          ),
      ],
    ),
  );

  Widget _luck(ColorScheme c, TextStyle dim) {
    final l = luck;
    return Column(
      key: const ValueKey('style-luck'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('luck: explained, not taught'),
        const SizedBox(height: 8),
        const Text(
          'luck is what the answer did for your guess. the same guess on '
          'different answers lands in different groups: a big group leaves '
          'many words (unlucky), a small one few (lucky). you choose the '
          'guess, never the answer, so there is nothing to practise: skill '
          'and risk are yours, luck is not. over every answer it averages '
          'exactly nothing.',
        ),
        const SizedBox(height: 10),
        if (l == null)
          Text('working out an example…', style: dim)
        else ...[
          Text('the guess ${l.guess}, by where the answer is:', style: dim),
          const SizedBox(height: 4),
          for (final r in _picked(l.rows))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'in a group of ${r.group.words.length} '
                '${r.group.words.length == 1 ? 'word' : 'words'} '
                '(${(r.group.chance * 100).toStringAsFixed(1)}% of answers): '
                'luck ${r.luck >= 0 ? '+' : '−'}${r.luck.abs().round()}',
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'weighted by those chances, luck over all answers is '
            '${l.mean.abs() < 0.05 ? '0' : l.mean.toStringAsFixed(1)}',
            key: const ValueKey('style-luck-mean'),
            style: dim,
          ),
        ],
      ],
    );
  }

  /// A handful of the groups, the biggest to the smallest: the two biggest, one
  /// from the middle, the two smallest.
  List<LuckRow> _picked(List<LuckRow> rows) {
    final n = rows.length;
    final at = {
      0,
      1,
      n ~/ 2,
      n - 2,
      n - 1,
    }.where((i) => i >= 0 && i < n).toList()..sort();
    return [for (final i in at) rows[i]];
  }

  Widget _grid(ColorScheme c, TextStyle dim) {
    const early = [
      Behaviour.maximiser,
      Behaviour.eliminator,
      Behaviour.gambler,
    ];
    const end = [Behaviour.closer, Behaviour.prober];
    return Column(
      key: const ValueKey('style-grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Caption('the pair is your style'),
        const SizedBox(height: 8),
        for (final e in early)
          for (final d in end)
            Padding(
              key: ValueKey('style-grid-${styleOf(e, d).id}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: styleOf(e, d).name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.primary,
                      ),
                    ),
                    TextSpan(text: '  ${e.label} + ${d.label}', style: dim),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
