import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'earned_rows.dart';
import 'guess_input.dart';
import 'keyboard.dart';
import 'learn_log.dart';
import 'main.dart';
import 'opening.dart';
import 'sequence.dart';
import 'store.dart' show Achievement;
import 'ui.dart';
import 'words.dart';

/// Finds the best sequence for the page (the real search by default; a test
/// gives its own).
typedef SequenceBenchmarkFinder = Future<SequenceScore> Function(WordBank bank);

Future<SequenceScore> _findBenchmark(WordBank bank) async {
  final length = appState.length;
  final land = await openingLandscape(
    bank: bank,
    length: length,
    draw: appState.draw,
  );
  return benchmarkSequence(
    bank: bank,
    length: length,
    draw: appState.draw,
    firsts: [for (final r in land.top) r.word],
  );
}

/// Three words, played first whatever the answer: pick three that tell the
/// answers apart as finely as they can, so that the fourth or fifth guess is
/// nearly sure. Each set is scored by what the colours of the three words
/// would tell about every word of the list, and against the best sequence the
/// app could find. The words need not start with the best opener: it is what
/// the three tell together that counts.
class SequencePage extends StatefulWidget {
  const SequencePage({super.key, required this.bank, this.findBenchmark});
  final WordBank bank;

  /// Replaces the search for the best sequence, for a test.
  final SequenceBenchmarkFinder? findBenchmark;

  @override
  State<SequencePage> createState() => _SequencePageState();
}

class _SequencePageState extends State<SequencePage> {
  final _focus = FocusNode();
  late final int length = appState.length;
  late final List<String> _answers = widget.bank.guessable(length);
  late final Set<String> _letters = widget.bank.letters(length);
  late final Map<String, int>? _law = widget.bank.law(length, appState.draw);
  late final input = GuessInput(length);

  final words = <String>[];

  /// The word the typed letters replace, or null when they make the next one.
  int? editing;
  String message = '';

  SequenceScore? score;
  SequenceScore? best;
  bool showBest = false;
  List<Achievement> earned = const [];

  /// The sets already scored this visit, so one is not counted twice.
  final _scored = <String>{};
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    (widget.findBenchmark ?? _findBenchmark)(widget.bank).then((b) {
      if (!mounted) return;
      setState(() => best = b);
      _record();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get full => words.length == sequenceLength;

  void _type(String ch) => setState(() {
    input.type(ch, _letters);
    message = '';
  });

  void _back() => setState(() {
    input.back();
    message = '';
  });

  void _submit() {
    if (!input.complete) {
      setState(
        () => message = input.hasBlank
            ? 'fill the blanks'
            : 'need $length letters',
      );
      return;
    }
    final word = input.word;
    if (!widget.bank.valid.contains(word)) {
      setState(() => message = 'not in the word list');
      return;
    }
    final at = editing;
    final others = [
      for (var i = 0; i < words.length; i++)
        if (i != at) words[i],
    ];
    if (others.contains(word)) {
      setState(() => message = 'already in the set');
      return;
    }
    setState(() {
      if (at != null) {
        words[at] = word;
      } else {
        words.add(word);
      }
      editing = null;
      input.clear();
      message = '';
      score = null;
      earned = const [];
    });
    if (full) _score();
  }

  /// Scores the three words against every answer. It yields first so that the
  /// words show before the work starts.
  Future<void> _score() async {
    final serial = ++_serial;
    final set = List.of(words);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || serial != _serial) return;
    final s = scoreSequence(_answers, set, _law);
    setState(() => score = s);
    _record();
  }

  /// Puts the set in the learn log, once, when it and the best found are both
  /// known.
  void _record() {
    final s = score, b = best;
    if (s == null || b == null) return;
    final key = (List.of(s.words)..sort()).join(' ');
    if (!_scored.add(key)) return;
    final skill = sequenceSkill(s, b);
    final got = appState.recordLearn(
      LearnEvent(
        kind: LearnKind.sequence,
        language: widget.bank.language.code,
        length: length,
        date: DateTime.now().toIso8601String().substring(0, 10),
        questions: 1,
        right: skill >= 99 ? 1 : 0,
        avgSkill: skill,
      ),
    );
    if (got.isNotEmpty && mounted) setState(() => earned = got);
  }

  void _edit(int i) => setState(() {
    editing = i;
    input.setWord(words[i]);
    message = '';
    // the set is being changed: its score is out of date until it is full again
    score = null;
    earned = const [];
    showBest = false;
    _serial++;
  });

  void _again() => setState(() {
    words.clear();
    editing = null;
    input.clear();
    message = '';
    score = null;
    earned = const [];
    showBest = false;
    _serial++;
  });

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _submit();
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() => input.move(-1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() => input.move(1));
    } else if (e.character != null) {
      _type(e.character!.toLowerCase());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.bank.language.name.toLowerCase();
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
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
                  'three words · $lang · $length',
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(19, 4, 19, 12),
                      children: [
                        const Caption(
                          'pick three words to play first, whatever the '
                          'answer. the more finely the colours of the three '
                          'tell the answers apart, the surer the fourth or '
                          'fifth guess',
                        ),
                        const SizedBox(height: 12),
                        _board(c),
                        if (message.isNotEmpty)
                          Text(message, style: TextStyle(color: c.error)),
                        if (score != null) ...[
                          const SizedBox(height: 14),
                          _result(c, dim, score!),
                        ] else if (full && editing == null)
                          Text('scoring…', style: dim),
                      ],
                    ),
                  ),
                  LetterKeyboard(
                    letters: _letters,
                    onLetter: _type,
                    onBlank: () => _type(GuessInput.blank),
                    onEnter: _submit,
                    onBack: _back,
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

  Widget _board(ColorScheme c) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final size = min(44.0, (box.maxWidth - gap * (length - 1)) / length);
        Widget row(List<String> chars, {int? cursor, VoidCallback? onTap}) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: onTap,
                child: Row(
                  children: [
                    for (var i = 0; i < length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      MarkTile(chars[i], size: size, cursor: i == cursor),
                    ],
                  ],
                ),
              ),
            );
        final typing = !full || editing != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < words.length; i++)
              if (editing == i)
                row(input.slots, cursor: input.cursor)
              else
                KeyedSubtree(
                  key: ValueKey('sequence-word-$i'),
                  child: row(words[i].split(''), onTap: () => _edit(i)),
                ),
            if (typing && editing == null)
              row(input.slots, cursor: input.cursor),
          ],
        );
      },
    );
  }

  String _bits(double b) => b.toStringAsFixed(2);
  String _pct(double p) => '${(p * 100).toStringAsFixed(p < .1 ? 1 : 0)}%';

  Widget _result(ColorScheme c, TextStyle dim, SequenceScore s) {
    final b = best;
    final needed = log(s.answers) / ln2;
    final skill = b == null ? null : sequenceSkill(s, b);
    return Column(
      key: const ValueKey('sequence-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          skill == null
              ? 'working out the best sequence to compare with…'
              : skill >= 99.5
              ? 'skill 100 · as good as the best found'
              : 'skill ${skill.round()} · the best found does '
                    '${_bits(b!.bits)} bits, yours ${_bits(s.bits)}',
          key: const ValueKey('sequence-skill'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'information after each word: '
          '${s.cumulativeBits.map(_bits).join(' → ')} bits, of '
          '${_bits(needed)} needed to know the answer outright',
          key: const ValueKey('sequence-bits'),
        ),
        const SizedBox(height: 4),
        Text(
          'the ${s.answers} answers fall into ${s.groups} groups: the biggest '
          'has ${s.largest} words, and ${s.alone} answers are alone in theirs',
          key: const ValueKey('sequence-groups'),
        ),
        const SizedBox(height: 4),
        Text(
          'about ${s.expectedLeft.toStringAsFixed(1)} words left on average '
          'after the three',
          key: const ValueKey('sequence-left'),
        ),
        const SizedBox(height: 4),
        Text(
          'win by the fourth guess in ${_pct(s.by4)} of games, by the fifth in '
          '${_pct(s.by5)}${s.largest > exactGroup ? ' or more' : ''}',
          key: const ValueKey('sequence-wins'),
        ),
        const SizedBox(height: 6),
        Text(
          'the order does not matter for what they tell: any of the three can '
          'come first',
          style: dim,
        ),
        if (earned.isNotEmpty) ...[
          const SizedBox(height: 10),
          EarnedRows(earned),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const ValueKey('sequence-again'),
              onPressed: _again,
              child: const Text('another three'),
            ),
            if (b != null)
              TextButton(
                key: const ValueKey('sequence-show'),
                onPressed: () => setState(() => showBest = !showBest),
                child: Text(showBest ? 'hide the best' : 'show the best found'),
              ),
          ],
        ),
        if (showBest && b != null) ...[
          const SizedBox(height: 8),
          Text(
            b.words.join(' · '),
            key: const ValueKey('sequence-best'),
            style: TextStyle(
              fontSize: 18,
              letterSpacing: 2,
              color: c.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_bits(b.bits)} bits · ${b.groups} groups · the biggest '
            '${b.largest} words · about ${b.expectedLeft.toStringAsFixed(1)} '
            'words left · wins by the fourth guess in ${_pct(b.by4)}, by the '
            'fifth in ${_pct(b.by5)}',
            style: dim,
          ),
          Text(
            'found by a search, not proved: there may be a better set',
            style: dim,
          ),
        ],
      ],
    );
  }
}
