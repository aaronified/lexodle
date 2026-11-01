import 'dart:math';

import 'package:flutter/material.dart';

import 'drill_calc.dart';
import 'logic.dart';
import 'main.dart';
import 'opening.dart';
import 'ui.dart';
import 'words.dart';

/// The opening, as a lesson: the best first guess for the language and length,
/// and then, for each of the colours it is most likely to show, the best second
/// guess. Nothing here is scored. A few of the best first guesses can be
/// compared; the second guesses are worked out one outcome at a time, so the
/// list fills in as it goes.
class OpeningPage extends StatefulWidget {
  const OpeningPage({super.key, required this.bank});
  final WordBank bank;

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _OpeningPageState extends State<OpeningPage> {
  late final int length = appState.length;
  late final List<String> _words = widget.bank.guessable(length);
  late final Map<String, int>? _law = widget.bank.law(length, appState.draw);

  Landscape? land;
  int selected = 0;
  GroupWalk? walk;
  List<GroupLine> outcomes = const [];
  final seconds = <int, List<Recommendation>>{};
  final _open = <int>{};

  /// Which choice of first guess the second guesses belong to: an answer that
  /// comes after another was picked is dropped.
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await openingLandscape(
      bank: widget.bank,
      length: length,
      draw: appState.draw,
    );
    if (!mounted) return;
    setState(() => land = l);
    _choose(0);
  }

  List<String> get firsts => [for (final r in land?.top ?? const []) r.word];

  void _choose(int i) {
    final f = firsts;
    if (i >= f.length) return;
    final serial = ++_serial;
    final first = f[i];
    final w = walkGroups(_words, first, _law);
    final lines = openingOutcomes(_words, first, _law);
    setState(() {
      selected = i;
      walk = w;
      outcomes = lines;
      seconds.clear();
      _open.clear();
    });
    _fill(serial, lines);
  }

  Future<void> _fill(int serial, List<GroupLine> lines) async {
    for (var i = 0; i < lines.length; i++) {
      final best = await secondGuesses(
        group: lines[i],
        guessable: _words,
        weights: _law,
      );
      if (!mounted || serial != _serial) return;
      setState(() => seconds[i] = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final f = firsts;
    final w = walk;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagBadge(widget.bank.language.flag, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'the opening · $lang · $length',
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
              padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
              children: [
                const Caption(
                  'the best first guess, and what to play next for each of '
                  'the colours it is most likely to show',
                ),
                const SizedBox(height: 14),
                if (land == null || w == null)
                  const Text(
                    'working out the best first guess…',
                    key: ValueKey('opening-loading'),
                  )
                else ...[
                  Text(
                    f[selected],
                    key: const ValueKey('opening-first'),
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                      color: c.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${w.groups.length} groups · the biggest '
                    '${w.groups.map((g) => g.words.length).reduce(max)} words · '
                    'about ${w.expectedLeft.toStringAsFixed(1)} of '
                    '${w.words} words left · ${w.expectedBits.toStringAsFixed(2)} '
                    'bits expected',
                    key: const ValueKey('opening-stats'),
                    style: dim,
                  ),
                  if (f.length > 1) ...[
                    const SizedBox(height: 10),
                    Text('other first guesses as good or nearly:', style: dim),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < f.length; i++)
                          InkWell(
                            key: ValueKey('opening-alt-$i'),
                            onTap: () => _choose(i),
                            child: Text(
                              '${f[i]} ${land!.top[i].skill.round()}',
                              style: i == selected
                                  ? TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.bold,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  Caption(
                    'then, for each of the ${outcomes.length} likeliest '
                    'colours of ${f[selected]}',
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < outcomes.length; i++)
                    _row(c, dim, i, f[selected]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(ColorScheme c, TextStyle dim, int i, String first) {
    final g = outcomes[i];
    final best = seconds[i];
    final open = _open.contains(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: ValueKey('opening-row-$i'),
        onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var k = 0; k < first.length; k++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: MarkTile(first[k], mark: g.marks[k], size: 22),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${g.words.length} ${g.words.length == 1 ? 'word' : 'words'}'
                      ' · ${(g.chance * 100).toStringAsFixed(1)}%',
                      style: dim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (best == null)
                Text('working out the best second guess…', style: dim)
              else
                Text.rich(
                  key: ValueKey('opening-second-$i'),
                  TextSpan(
                    children: [
                      const TextSpan(text: 'play '),
                      TextSpan(
                        text: best.first.word,
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      if (g.words.length > 1)
                        TextSpan(
                          text:
                              '  ·  about ${best.first.expected.toStringAsFixed(1)} '
                              'words left after it',
                          style: dim,
                        ),
                    ],
                  ),
                ),
              if (open) ...[
                const SizedBox(height: 8),
                if (best != null && best.length > 1)
                  for (final r in best)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${r.word} · skill ${r.skill.round()} · '
                        'words left ${r.expected.toStringAsFixed(1)} · '
                        '${r.gain.toStringAsFixed(2)} bits'
                        '${r.canWin ? ' · can be right' : ''}',
                        key: ValueKey('opening-more-$i-${r.word}'),
                        style: dim,
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  '${g.words.take(12).join(', ')}'
                  '${g.words.length > 12 ? ', …' : ''}',
                  style: dim,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
