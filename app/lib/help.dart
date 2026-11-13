import 'package:flutter/material.dart';

import 'hearts.dart';
import 'logic.dart';
import 'modes.dart';
import 'ui.dart';

/// One part of a mode's how to play: a heading, a crop of the real screen (when
/// it has one) and a few short lines.
class HelpSection {
  const HelpSection(this.heading, this.lines, {this.crop});
  final String heading;
  final List<String> lines;

  /// What the crop shows, by name (see [HelpCrop]); null for lines alone.
  final String? crop;
}

/// How to play [mode], as short lines under headings, each with a crop of the
/// screen where one says more than words. The typing, spaces, locks and erase
/// are part of playing it. [daily] adds what a daily is.
List<HelpSection> modeHelp(GameMode mode, {bool daily = false}) {
  final blind = mode == GameMode.blind;
  final rules = switch (mode) {
    GameMode.classic => const HelpSection('the rules', [
      'find the hidden word in your tries.',
      'every guess must be a real word.',
    ], crop: 'colours'),
    GameMode.quartet => const HelpSection('the rules', [
      'four words. one guess plays on all.',
      'every key is split in four, one part a board.',
      'a solved board drops out.',
    ], crop: 'split'),
    GameMode.relay => const HelpSection('the rules', [
      'four words, one after the other.',
      'the next opens with every guess played.',
    ], crop: 'relay'),
    GameMode.lockdown => const HelpSection('the rules', [
      'a green letter locks for good.',
      'a word not in the list costs a heart.',
      'no hearts left, you lose.',
    ], crop: 'lockdown'),
    GameMode.blind => const HelpSection('the rules', [
      'find the hidden word in your tries.',
      'no tile colours. only these counts.',
      'every guess must be a real word.',
    ], crop: 'counts'),
    GameMode.equations => const HelpSection('the rules', [
      'find the hidden equation.',
      'a true sum: one =, a number on the right.',
      '× and ÷ go before + and −.',
      'no leading 0. no lone 0.',
    ], crop: 'equation'),
    GameMode.mastermind => const HelpSection('the rules', [
      'no word is chosen.',
      'each reply fits a word still possible.',
      'guess the one left. no limit.',
    ], crop: 'reply'),
    GameMode.themed => const HelpSection('the rules', [
      'the words are places.',
      'only places count. no spaces.',
      'tap the i to learn about one.',
    ], crop: 'place'),
  };
  return [
    rules,
    if (mode == GameMode.mastermind)
      const HelpSection('the pool', [
        'random: a bigger pool is likelier.',
        'largest: always the biggest. no chance.',
      ]),
    if (blind)
      const HelpSection('pencil', [
        'tap a letter to colour it.',
        'ctrl does it under the cursor.',
      ], crop: 'pencil'),
    const HelpSection('typing', [
      'type, or tap the keys.',
      'tap a tile to move the cursor.',
      'drag the space key to move it.',
      'backspace or delete clears a tile.',
    ]),
    const HelpSection('spaces', [
      'space makes a blank. fill it first.',
    ], crop: 'blank'),
    HelpSection('locks', [
      'double tap a tile: lock it.',
      if (blind)
        'double tap the counts: lock greens.'
      else
        'double tap the guesses: lock greens.',
      if (mode == GameMode.relay) 'only the board in play locks.',
    ], crop: blind ? 'locks-blind' : 'locks'),
    const HelpSection('erase', [
      'swipe left over the row. it clears.',
      'or shift and backspace.',
    ], crop: 'erase'),
    if (daily)
      const HelpSection('the daily', ['same for everyone. once a day.']),
  ];
}

/// The crops of the help: pieces of the real screen, drawn with the game's own
/// tile at a small size, in the scheme's colours.
class HelpCrop extends StatelessWidget {
  const HelpCrop(this.kind, {super.key});
  final String kind;

  static const _size = 32.0;

  static Widget _tile(
    String ch, {
    Mark? mark,
    bool cursor = false,
    bool locked = false,
  }) => MarkTile(ch, size: _size, mark: mark, cursor: cursor, locked: locked);

  static Widget _row(List<Widget> tiles) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, t) in tiles.indexed) ...[
        if (i > 0) const SizedBox(width: 5),
        t,
      ],
    ],
  );

  static Widget _word(String w, [List<Mark?>? marks]) => _row([
    for (var i = 0; i < w.length; i++)
      _tile(w[i], mark: marks == null ? null : marks[i]),
  ]);

  Widget _arrow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Icon(
      Icons.arrow_right,
      size: 20,
      color: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: dimAlpha),
    ),
  );

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: dimAlpha),
    ),
  );

  /// A colour chip and what it says.
  Widget _legend(BuildContext context, Mark m, String text) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: markColors(c, m).$1,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _legends(BuildContext context, {bool grey = true}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      children: [
        _legend(context, Mark.correct, 'green: right letter, right place'),
        const SizedBox(height: 6),
        _legend(context, Mark.present, 'yellow: right letter, wrong place'),
        if (grey) ...[
          const SizedBox(height: 6),
          _legend(context, Mark.absent, 'grey: not in the word'),
        ],
      ],
    ),
  );

  /// The framed box a crop sits in, as on the real screen: hairline, small
  /// corners.
  Widget _frame(BuildContext context, List<Widget> children) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        border: Border.fromBorderSide(hairline(c)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const g = Mark.correct, y = Mark.present, a = Mark.absent;
    switch (kind) {
      case 'opening':
        return _frame(context, [
          _word('crane', [a, y, g, a, y]),
          const SizedBox(width: 12),
          _label(context, 'five new letters'),
          const SizedBox(width: 12),
          _word('eerie', [a, a, a, a, a]),
          const SizedBox(width: 12),
          _label(context, 'repeats: less to learn'),
        ]);
      case 'groups':
        return _frame(context, [
          _word('batch'),
          _label(context, '  '),
          _word('catch'),
          _label(context, '  '),
          _word('match'),
          _label(context, '  '),
          _word('patch'),
          const SizedBox(width: 12),
          _label(context, 'one guess, many groups'),
        ]);
      case 'compare':
        return _frame(context, [
          _word('crane'),
          _row([_tile('1', mark: g), _tile('2', mark: y)]),
          const SizedBox(width: 14),
          _word('crate'),
          _row([_tile('1', mark: g), _tile('1', mark: y)]),
        ]);
      case 'signs':
        return _frame(context, [
          _word('4+5×7', [g, y, a, a, a]),
          const SizedBox(width: 12),
          _label(context, 'try the signs early'),
        ]);
      case 'colours':
        return Column(
          children: [
            _frame(context, [
              _word('crane', [a, y, g, a, a]),
            ]),
            _legends(context),
          ],
        );
      case 'counts':
        return Column(
          children: [
            _frame(context, [
              _word('crane'),
              const SizedBox(width: 14),
              _row([_tile('1', mark: g), _tile('1', mark: y)]),
            ]),
            _legends(context, grey: false),
          ],
        );
      case 'split':
        return _frame(context, [
          // one key, cut in four: what each board says about the letter
          _row([_tile('e', mark: g), _tile('e', mark: y)]),
          const SizedBox(width: 10),
          _row([_tile('e', mark: a), _tile('e')]),
          const SizedBox(width: 12),
          _label(context, 'one key, four boards'),
        ]);
      case 'relay':
        return _frame(context, [
          _row([
            _tile('1', cursor: true),
            _tile('2', locked: true),
            _tile('3', locked: true),
            _tile('4', locked: true),
          ]),
          const SizedBox(width: 12),
          _label(context, 'one in play, the rest wait'),
        ]);
      case 'lockdown':
        return _frame(context, [
          _row([
            _tile('c', mark: g, locked: true),
            _tile('r'),
            _tile('a', mark: g, locked: true),
            _tile('n'),
            _tile('e'),
          ]),
          const SizedBox(width: 14),
          const HeartsRow(total: 5, left: 4),
        ]);
      case 'equation':
        return Column(
          children: [
            _frame(context, [
              _word('4×5=20', [g, a, y, g, a, a]),
            ]),
            _legends(context, grey: false),
          ],
        );
      case 'reply':
        return _frame(context, [
          _word('crane', [a, y, g, a, a]),
          _arrow(context),
          _label(context, 'a word that could still be it'),
        ]);
      case 'place':
        return _frame(context, [
          _word('spain'),
          const SizedBox(width: 10),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surfaceContainerHighest,
            ),
            child: Text(
              'i',
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ),
        ]);
      case 'pencil':
        return _frame(context, [
          _tile('s'),
          _arrow(context),
          _tile('s', mark: g),
          _arrow(context),
          _tile('s', mark: y),
          _arrow(context),
          _tile('s', mark: a),
        ]);
      case 'blank':
        return _frame(context, [
          _row([
            _tile('c'),
            _tile('r'),
            _tile(' ', cursor: true),
            _tile('n'),
            _tile('e'),
          ]),
        ]);
      case 'locks':
        return _frame(context, [
          _tile('a'),
          _label(context, ' ×2'),
          _arrow(context),
          _tile('a', locked: true),
          const SizedBox(width: 16),
          _row([_tile('c', mark: g), _tile('r', mark: a), _tile('a', mark: g)]),
          _label(context, ' ×2'),
          _arrow(context),
          _row([_tile('c', locked: true), _tile(''), _tile('a', locked: true)]),
        ]);
      case 'locks-blind':
        return _frame(context, [
          _tile('a'),
          _label(context, ' ×2'),
          _arrow(context),
          _tile('a', locked: true),
          const SizedBox(width: 16),
          _row([_tile('1', mark: g), _tile('1', mark: y)]),
          _label(context, ' ×2'),
          _arrow(context),
          _row([_tile(''), _tile('r', locked: true), _tile('')]),
        ]);
      case 'erase':
        return _frame(context, [
          Column(
            children: [
              _word('cra'),
              const SizedBox(height: 6),
              Icon(Icons.arrow_back, size: 26, color: c.primary),
            ],
          ),
        ]);
    }
    return const SizedBox();
  }
}

/// The help button of a game screen, at the top right: the rules of [mode].
class ModeHelpButton extends StatelessWidget {
  const ModeHelpButton({super.key, required this.mode, this.daily = false});
  final GameMode mode;
  final bool daily;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('help-button'),
    tooltip: 'how to play',
    icon: TablerIcon(
      'info-circle',
      size: 24,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    onPressed: () => showModeHelp(context, mode, daily: daily),
  );
}

/// Shows how to play [mode] in a dialog.
Future<void> showModeHelp(
  BuildContext context,
  GameMode mode, {
  bool daily = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      key: const ValueKey('help-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: hairline(Theme.of(context).colorScheme),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'how to play · ${mode.label}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('help-close'),
                    tooltip: 'close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in modeHelp(mode, daily: daily))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Caption(s.heading),
                            const SizedBox(height: 8),
                            if (s.crop != null) ...[
                              HelpCrop(s.crop!),
                              const SizedBox(height: 8),
                            ],
                            for (final line in s.lines)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(line),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
