import 'dart:math';

import 'package:flutter/material.dart';

import 'equations.dart';
import 'history.dart';
import 'logic.dart';
import 'ui.dart';

/// A finished game of a mode with no review (equations, mastermind) read back
/// from the history: its guesses on a board, coloured as they were, and how it
/// ended. The colours are worked out against the answer: for the mastermind
/// that is the word it settled on, which fits every reply it gave, so every
/// row reads as it did.
class PlainReplayPage extends StatelessWidget {
  const PlainReplayPage({super.key, required this.game, required this.guesses});

  final GameRow game;
  final List<String> guesses;

  String get _answer => game.answers.first;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final noun = game.mode.isEquations ? 'equation' : 'word';
    final shown = game.mode.isEquations ? faceOf : (String s) => s;
    final answer = _answer.split('').map(shown).join();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${game.mode.label}${game.isDaily ? ' · daily' : ''}',
          style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, box) {
                const gap = 6.0;
                final tile = min(
                  56.0,
                  (box.maxWidth - 38 - gap * (game.length - 1)) / game.length,
                );
                return ListView(
                  key: const ValueKey('plain-replay'),
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 24),
                  children: [
                    Text(
                      game.won
                          ? 'solved in ${guesses.length}'
                          : 'the $noun was $answer',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (game.won)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Caption(
                          'the $noun was $answer',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    for (final (r, g) in guesses.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: gap),
                        child: Row(
                          key: ValueKey('replay-row-$r'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (i, m) in evaluate(
                              _answer,
                              g,
                            ).indexed) ...[
                              if (i > 0) const SizedBox(width: gap),
                              Container(
                                key: ValueKey('replay-$r-$i'),
                                width: tile,
                                height: tile,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: markColors(c, m).$1,
                                  border: Border.all(
                                    color: markBorder(c, m),
                                    width: markBorderWidth(m),
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  shown(g[i]),
                                  style: TextStyle(
                                    fontSize: tile * .5,
                                    fontWeight: FontWeight.bold,
                                    color: markColors(c, m).$2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
