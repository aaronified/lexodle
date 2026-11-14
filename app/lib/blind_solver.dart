import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'guess_input.dart';
import 'haptics.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'settings_button.dart';
import 'swipe_clear.dart';
import 'typing_keys.dart';
import 'ui.dart';
import 'words.dart';

/// One guess of a blind game and the two counts the game showed for it: the
/// letters right and in place, and the letters right elsewhere.
typedef BlindGuess = (String word, int green, int yellow);

/// The marks a blind guess shows, as [evaluate] sorts them with `blind: true`:
/// [green] greens, then [yellow] yellows, then absents up to [length].
List<Mark> blindMarks(int length, int green, int yellow) => [
  for (var i = 0; i < length; i++)
    i < green
        ? Mark.correct
        : i < green + yellow
        ? Mark.present
        : Mark.absent,
];

/// The words of [pool] still possible after the blind guesses in [history].
List<String> blindNarrow(List<String> pool, Iterable<BlindGuess> history) {
  var left = pool;
  for (final (word, green, yellow) in history) {
    left = filterEligible(
      left,
      word,
      blindMarks(word.length, green, yellow),
      blind: true,
    );
  }
  return left;
}

/// The best next guess of a blind game with [triesLeft] tries, this one
/// included: scored by the words expected to be left over the count outcomes.
/// With two tries the guess with the best chance of solving it in time, with
/// one the likeliest word that fits (as the classic solver does).
Future<Recommendation?> blindRecommend(
  List<String> eligible,
  Iterable<String> candidates,
  int triesLeft, {
  Map<String, int>? weights,
}) async {
  if (eligible.isEmpty) return null;
  if (triesLeft >= 3) {
    final top = (await analyseGuesses(
      eligible,
      candidates,
      k: 1,
      weights: weights,
      blind: true,
    )).top;
    return top.isEmpty ? null : top.first;
  }
  int weightOf(String w) => max(weights?[w] ?? 1, 1);
  var total = 0;
  for (final w in eligible) {
    total += weightOf(w);
  }
  final n = eligible.length;
  // the sum of the squared sizes of the groups [g] makes, over n
  double expected(String g) {
    final sizes = <int, int>{};
    for (final w in eligible) {
      sizes.update(blindCode(w, g), (v) => v + 1, ifAbsent: () => 1);
    }
    return sizes.values.fold<int>(0, (a, s) => a + s * s) / n;
  }

  if (triesLeft <= 1) {
    var pick = eligible.first;
    for (final w in eligible) {
      if (weightOf(w) > weightOf(pick)) pick = w;
    }
    return Recommendation(
      pick,
      0,
      expected(pick),
      true,
      winChance: weightOf(pick) / total,
    );
  }
  final possible = eligible.toSet();
  String? pick;
  var best = -1.0;
  var scored = 0;
  for (final g in candidates) {
    final heaviest = <int, int>{};
    for (final w in eligible) {
      heaviest.update(
        blindCode(w, g),
        (v) => max(v, weightOf(w)),
        ifAbsent: () => weightOf(w),
      );
    }
    final chance = heaviest.values.fold<int>(0, (a, v) => a + v) / total;
    if (chance > best + 1e-12 ||
        (chance > best - 1e-12 &&
            pick != null &&
            !possible.contains(pick) &&
            possible.contains(g))) {
      best = chance;
      pick = g;
    }
    if (++scored % 40 == 0) await Future<void>.delayed(Duration.zero);
  }
  if (pick == null) return null;
  return Recommendation(
    pick,
    0,
    expected(pick),
    possible.contains(pick),
    winChance: best,
  );
}

/// Helps with a blind game played elsewhere: enter each guess and the two
/// counts the game showed (tap a count to step it up), and it narrows the words
/// still possible and recommends the best next guess, scored by the words
/// expected to be left over the count outcomes. [excluded] holds answers the
/// solver must not know (see SolverExclusions): they are not in its pool.
class BlindSolverPage extends StatefulWidget {
  const BlindSolverPage({
    super.key,
    required this.bank,
    this.excluded = const {},
  });
  final WordBank bank;
  final Set<String> excluded;

  @override
  State<BlindSolverPage> createState() => _BlindSolverPageState();
}

class _BlindSolverPageState extends State<BlindSolverPage> {
  final _focus = FocusNode();
  late final int length = appState.length;
  late final int tries = appState.blindTries;
  late final List<String> _answers = [
    for (final w in widget.bank.answers(length))
      if (!widget.excluded.contains(w)) w,
  ];
  late final Set<String> _letters = widget.bank.letters(length);

  final history = <BlindGuess>[];
  late final input = GuessInput(length);
  int green = 0;
  int yellow = 0;
  String message = '';
  late List<String> eligible = _answers;
  Recommendation? rec;
  bool busy = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _solve();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _solve() async {
    final run = ++_run;
    var left = _answers;
    try {
      left = blindNarrow(_answers, history);
    } catch (e) {
      appLog.w('blind solver', 'could not narrow the words: ${e.runtimeType}');
    }
    setState(() {
      eligible = left;
      busy = true;
    });
    Recommendation? r;
    try {
      r = await blindRecommend(
        left,
        recommendationCandidates(left, widget.bank.guessable(length)),
        max(tries - history.length, 1),
        weights: widget.bank.law(length, appState.draw),
      );
    } catch (e) {
      appLog.w('blind solver', 'could not recommend: ${e.runtimeType}');
    }
    if (!mounted || run != _run) return; // a newer guess superseded this one
    setState(() {
      rec = r;
      busy = false;
    });
  }

  void _type(String ch) {
    setState(() {
      if (input.type(ch, _letters) >= 0) message = '';
    });
  }

  void _back() {
    setState(() {
      if (input.back() >= 0) message = '';
    });
  }

  void _move(int by) => setState(() => input.move(by));

  void _clearRow() => setState(() => input.clearTyped());

  void _step(bool isGreen) => setState(() {
    if (isGreen) {
      green = (green + 1) % (length + 1);
    } else {
      yellow = (yellow + 1) % (length + 1);
    }
  });

  void _add() {
    if (!input.complete) {
      Haptics.fire(Haptic.reject);
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    if (green + yellow > length) {
      Haptics.fire(Haptic.reject);
      setState(() => message = 'the counts add up to more than $length');
      return;
    }
    history.add((input.word, green, yellow));
    input.clear();
    green = 0;
    yellow = 0;
    message = '';
    _solve();
  }

  void _undo() {
    if (history.isEmpty) return;
    history.removeLast();
    _solve();
  }

  void _use(String word) => setState(() {
    input.setWord(word);
    green = 0;
    yellow = 0;
    message = '';
  });

  late final _keys = TypingKeys(
    submit: _add,
    back: _back,
    clearRow: _clearRow,
    move: _move,
    type: _type,
  );

  KeyEventResult _onKey(FocusNode _, KeyEvent e) => _keys.handle(e);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlagBadge(widget.bank.language.flag, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'solver · blind · $lang · $length · $tries tries',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
          actions: [const SettingsButton()],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(19, 4, 19, 12),
                      children: [
                        const Caption(
                          'type each guess you played, then tap the two '
                          'counts to match what the game showed: letters '
                          'right and in place, letters right elsewhere',
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            const gap = 6.0;
                            final size = min(
                              48.0,
                              (box.maxWidth - gap * (length - 1) - 14) /
                                  (length + 2),
                            );
                            Widget count(
                              int n,
                              Mark mark,
                              Key key,
                              VoidCallback? tap,
                            ) {
                              final (fill, fg) = markColors(c, mark);
                              return GestureDetector(
                                key: key,
                                behavior: HitTestBehavior.opaque,
                                onTap: tap,
                                child: Container(
                                  width: size,
                                  height: size,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: fill,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      fontSize: size * .5,
                                      fontWeight: FontWeight.bold,
                                      color: fg,
                                    ),
                                  ),
                                ),
                              );
                            }

                            Widget row(
                              List<String> chars,
                              int g,
                              int y, {
                              int? cursor,
                              int? at,
                            }) => Padding(
                              padding: const EdgeInsets.only(bottom: gap),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: cursor == null
                                        ? _tiles(chars, size, gap)
                                        : SwipeClear(
                                            onClear: _clearRow,
                                            child: _tiles(
                                              chars,
                                              size,
                                              gap,
                                              cursor: cursor,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  count(
                                    g,
                                    Mark.correct,
                                    ValueKey('count-${at ?? 'h'}-g'),
                                    at == null ? null : () => _step(true),
                                  ),
                                  const SizedBox(width: gap),
                                  count(
                                    y,
                                    Mark.present,
                                    ValueKey('count-${at ?? 'h'}-y'),
                                    at == null ? null : () => _step(false),
                                  ),
                                ],
                              ),
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (w, g, y) in history)
                                  row(w.split(''), g, y),
                                row(
                                  input.slots,
                                  green,
                                  yellow,
                                  cursor: input.cursor,
                                  at: history.length,
                                ),
                              ],
                            );
                          },
                        ),
                        if (message.isNotEmpty)
                          Text(message, style: TextStyle(color: c.error)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: history.isEmpty ? null : _undo,
                                child: const Text('undo last'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _add,
                                child: const Text('add guess'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),
                        _result(c),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
                    onCursor: _move,
                    onEnter: _add,
                    onBack: _back,
                    enterLabel: 'add',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tiles(List<String> chars, double size, double gap, {int? cursor}) =>
      Row(
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            MarkTile(chars[i], size: size, cursor: i == cursor),
          ],
        ],
      );

  Widget _result(ColorScheme c) {
    final n = eligible.length;
    final left = tries - history.length;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption('$n ${n == 1 ? 'word' : 'words'} on my list fit'),
        const SizedBox(height: 4),
        Caption(
          'answers from ${_answers.length} words · '
          '${left > 0 ? '$left ${left == 1 ? 'try' : 'tries'} left' : 'out of tries'}',
        ),
      ],
    );
    if (n == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 8),
          Text(
            'no word matches. check the counts of the guesses above, or the '
            'game may use a word this list lacks.',
            style: TextStyle(color: c.error, fontSize: 13),
          ),
        ],
      );
    }
    final r = rec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        const SizedBox(height: 10),
        if (n == 1) ...[
          Text(
            'the only word on my list that fits: ${eligible.first}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ] else if (r == null || busy)
          const Caption('working out the best guess…')
        else ...[
          Caption(switch (left) {
            <= 1 => 'last try: the likeliest word that fits',
            2 => 'two tries left: the guess most likely to solve it in time',
            _ => 'recommended guess',
          }),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _use(r.word),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                r.word,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.primary,
                ),
              ),
            ),
          ),
          Text(
            '${r.winChance == null ? '' : 'about ${(r.winChance! * 100).toStringAsFixed(0)}% to solve it · '}'
            'expect about ${r.expected.toStringAsFixed(1)} words left'
            '${r.canWin ? ' · could be the answer' : ''}  (tap to use)',
            style: TextStyle(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
        if (n > 1) ...[
          const SizedBox(height: 16),
          Caption(n > 40 ? 'most likely 40' : 'all the words that fit'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final w in eligible.take(40))
                InkWell(onTap: () => _use(w), child: Text(w)),
            ],
          ),
        ],
      ],
    );
  }
}
