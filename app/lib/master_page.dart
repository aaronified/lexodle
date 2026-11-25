import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';
import 'calc_dialog.dart';
import 'keyboard.dart';
import 'logic.dart';
import 'main.dart';
import 'master_game.dart';
import 'ui.dart';
import 'words.dart';

/// How to master, a screen of learn: a real game (classic, blind or mastermind)
/// with the numbers behind every step one tap away: the words that fit, the
/// likeliest answers, the best guesses for skill and the best bets for luck, and
/// the logic of every colour. The screen itself stays quiet: a board, a
/// keyboard, four small buttons and the words that fit.
class MasterPage extends StatefulWidget {
  const MasterPage({
    super.key,
    required this.bank,
    required this.kind,
    @visibleForTesting this.game,
  });
  final WordBank bank;
  final MasterKind kind;

  /// A game made by the caller (a test, which does not want the analysis).
  final MasterGame? game;

  @override
  State<MasterPage> createState() => _MasterPageState();
}

class _MasterPageState extends State<MasterPage> {
  late final MasterGame game =
      widget.game ??
      MasterGame(
        bank: widget.bank,
        kind: widget.kind,
        length: appState.learnLength,
        draw: appState.learnDraw,
      );

  @override
  void dispose() {
    if (widget.game == null) game.dispose();
    super.dispose();
  }

  // ---- helpers ----

  String get _head => widget.kind == MasterKind.classic
      ? 'learn · how to master'
      : 'learn · how to master ${widget.kind.name}';

  void _toast(String text) {
    if (!mounted) return;
    try {
      showToast(context, text);
    } catch (e) {
      appLog.w('learn', 'could not show a toast: ${e.runtimeType}');
    }
  }

  Future<void> _submit() async {
    try {
      final why = await game.submit();
      if (why != null) _toast(why);
    } catch (e) {
      appLog.w('learn', 'could not play a guess: ${e.runtimeType}');
    }
  }

  void _tap(int row, int i) {
    try {
      final why = game.tapTile(row, i);
      if (why != null) _toast(why);
    } catch (e) {
      appLog.w('learn', 'could not mark a tile: ${e.runtimeType}');
    }
  }

  void _type(String ch) {
    try {
      game.type(ch);
    } catch (e) {
      appLog.w('learn', 'could not type a letter: ${e.runtimeType}');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      game.back();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null &&
        ch.runes.length == 1 &&
        RegExp(r'^\p{L}$', unicode: true).hasMatch(ch)) {
      _type(ch.toLowerCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlagBadge(widget.bank.language.flag, size: 16),
              const SizedBox(width: 8),
              // the graduation hat: this is learn
              TablerIcon('school', size: headerIconSize, color: c.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _head,
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
              child: ListenableBuilder(
                listenable: game,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
                  children: [
                    _hint(c),
                    const SizedBox(height: 10),
                    _board(),
                    const SizedBox(height: 10),
                    if (game.done) _over(c) else _keyboard(),
                    const SizedBox(height: 10),
                    _buttons(),
                    const SizedBox(height: 14),
                    _poolBlock(c),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(ColorScheme c) {
    final text = switch (widget.kind) {
      MasterKind.classic => 'guess the hidden word',
      MasterKind.blind => 'blind: the counts only. work out the colours',
      MasterKind.mastermind =>
        'the opponent answers as a word that still fits. split the words best',
    };
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: c.onSurface.withValues(alpha: dimAlpha),
          ),
        ),
        _Pill(
          'new word',
          key: const ValueKey('master-new'),
          onTap: () {
            try {
              game.restart();
            } catch (e) {
              appLog.w('learn', 'could not restart: ${e.runtimeType}');
            }
          },
        ),
      ],
    );
  }

  Widget _board() {
    const gap = 6.0;
    final blind = game.blind;
    final length = game.length;
    return LayoutBuilder(
      builder: (context, box) {
        final slots = length + (blind ? 2 : 0);
        final extra = blind ? gap * 2 + 4 : 0.0;
        final size = max(
          20.0,
          min(44.0, (box.maxWidth - gap * (length - 1) - extra) / slots),
        );
        Widget row(List<Widget> tiles, {List<Widget> counts = const []}) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    tiles[i],
                  ],
                  if (counts.isNotEmpty) ...[
                    const SizedBox(width: gap * 2),
                    for (var i = 0; i < counts.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      counts[i],
                    ],
                  ],
                ],
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < game.rows.length; r++)
              row(
                [
                  for (var i = 0; i < length; i++)
                    blind
                        ? _BlindTile(
                            game.rows[r].word[i],
                            mark: game.shownAt(r, i),
                            helper: game.helperAt(r, i),
                            size: size,
                            onTap: () => _tap(r, i),
                          )
                        : MarkTile(
                            game.rows[r].word[i],
                            mark: game.rows[r].marks[i],
                            size: size,
                          ),
                ],
                counts: blind
                    ? [
                        MarkTile(
                          '${game.rows[r].green}',
                          key: ValueKey('count-green-$r'),
                          mark: Mark.correct,
                          size: size,
                        ),
                        MarkTile(
                          '${game.rows[r].yellow}',
                          key: ValueKey('count-yellow-$r'),
                          mark: Mark.present,
                          size: size,
                        ),
                      ]
                    : const [],
              ),
            if (!game.done)
              row(
                [
                  for (var i = 0; i < length; i++)
                    MarkTile(
                      i < game.typed.length ? game.typed[i] : '',
                      cursor: i == game.typed.length,
                      size: size,
                    ),
                ],
                counts: blind
                    ? [
                        MarkTile('', mark: Mark.absent, size: size),
                        MarkTile('', mark: Mark.absent, size: size),
                      ]
                    : const [],
              ),
          ],
        );
      },
    );
  }

  Widget _keyboard() {
    final blind = game.blind;
    return LetterKeyboard(
      letters: widget.bank.letters(game.length),
      onLetter: _type,
      onEnter: _submit,
      onBack: game.back,
      marks: blind
          ? {
              for (final e in game.deduced.entries)
                if (e.value == Mark.absent) e.key: Mark.absent,
            }
          : game.keyMarks,
      chances: blind ? game.keyChances : const {},
    );
  }

  Widget _over(ColorScheme c) {
    final word = game.answer ?? (game.rows.isEmpty ? '' : game.rows.last.word);
    final n = game.rows.length;
    return Text(
      '${game.adversary ? 'it was' : 'the word was'} $word. solved in $n.',
      key: const ValueKey('master-over'),
      style: TextStyle(fontSize: 14, color: c.primary),
    );
  }

  Widget _buttons() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      _Pill(
        'likeliest',
        key: const ValueKey('master-likeliest'),
        onTap: _likeliest,
      ),
      _Pill(
        'best for skill',
        key: const ValueKey('master-skill'),
        onTap: () => _best(skill: true),
      ),
      _Pill(
        'best for luck',
        key: const ValueKey('master-luck'),
        onTap: () => _best(skill: false),
      ),
      _Pill('logic', key: const ValueKey('master-logic'), onTap: _logic),
    ],
  );

  // ---- the words that fit ----

  Widget _poolBlock(ColorScheme c) {
    final n = game.pool.length;
    final list = game.pool.take(24).join(' ') + (n > 24 ? ' …' : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Caption('${_n(n)} ${n == 1 ? 'word fits' : 'words fit'}'),
            const SizedBox(width: 8),
            CalcDot(_poolSpec()),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const ValueKey('master-pool'),
          onTap: _allWords,
          child: Text(
            list,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ),
      ],
    );
  }

  CalcSpec _poolSpec() {
    final n0 = game.words.length;
    final n = game.pool.length;
    final rows = <(String, String)>[('all the words', _n(n0))];
    for (final r in game.rows) {
      rows.add(('${r.word}  ${_label(r)}', '${_n(r.before)} → ${_n(r.after)}'));
    }
    final bits = n > 0 && n0 > 0 ? log(n0 / n) / ln2 : 0.0;
    return CalcSpec(
      metric: 'bits',
      title: 'how we got to the pool',
      intro: game.blind
          ? 'a word fits when it would have given exactly the counts you got, '
                'for every guess so far: the same number of its letters in '
                'place and the same number elsewhere.'
          : 'a word fits when it would have given exactly the colours you got, '
                'for every guess so far: the greens in place, the yellows in '
                'the word but elsewhere, the greys not in it.',
      rows: rows,
      result: ('words that fit now', _n(n)),
      note:
          'each guess keeps only the words that agree with it, so the pool '
          'only shrinks. bits found: log₂ (${_n(n0)} ÷ ${_n(n)}) = '
          '${bits.toStringAsFixed(2)}.',
    );
  }

  void _allWords() => _dialog(() {
    final n = game.pool.length;
    return showHairlineDialog<void>(
      context,
      title: 'the ${_n(n)} ${n == 1 ? 'word that fits' : 'words that fit'}',
      titleColor: bitsColor(Theme.of(context).colorScheme),
      children: [
        const Text(
          'in the order of how common they are.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          game.pool.join(' '),
          key: const ValueKey('master-all-words'),
          style: const TextStyle(fontSize: 12, height: 1.8),
        ),
      ],
    );
  });

  // ---- dialogs ----

  void _dialog(Future<void> Function() open) {
    try {
      open();
    } catch (e) {
      appLog.w('learn', 'could not open a dialog: ${e.runtimeType}');
    }
  }

  void _likeliest() => _dialog(() {
    final c = Theme.of(context).colorScheme;
    final n = game.pool.length;
    return showHairlineDialog<void>(
      context,
      title: 'likeliest answers',
      titleColor: luckColor(c),
      children: [
        Text(
          game.adversary
              ? 'the opponent answers as a word that still fits, so every one '
                    'of the ${_n(n)} words that fit is possible.'
              : 'the answer is drawn from the commonest words, so the '
                    'commonest words that fit are the likeliest. every one of '
                    'the ${_n(n)} words that fit is possible.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        for (final w in game.likeliest)
          _optionRow(
            word: w,
            line: Text('${_pc(_chanceOf(w))} chance', style: _dimStyle(c)),
          ),
      ],
    );
  });

  void _best({required bool skill}) => _dialog(() {
    final c = Theme.of(context).colorScheme;
    return showHairlineDialog<void>(
      context,
      title: skill ? 'best for skill' : 'best bets for luck',
      titleColor: skill ? skillColor(c) : luckColor(c),
      children: [
        ListenableBuilder(
          listenable: game,
          builder: (context, _) => _bestBody(skill),
        ),
      ],
    );
  });

  Widget _bestBody(bool skill) {
    final c = Theme.of(context).colorScheme;
    final last = game.last;
    final land = game.landscape;
    final n = game.pool.length;
    final lines = <Widget>[
      Text.rich(
        TextSpan(
          children: measureSpans(
            c,
            skill
                ? 'skill is how many bits a guess is expected to gain, against '
                      'the best guess there is. these two are the best.'
                : 'a bet is a guess most likely to get a reply better than its '
                      'average. luck is then up to the answer.',
          ),
        ),
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 8),
    ];
    if (last != null) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'your last guess ${last.guess}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                skill
                    ? 'skill ${last.skill.round()}'
                    : 'luck ${luckText(last.luck)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: skill ? skillColor(c) : luckColor(c),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (land == null) {
      lines.add(
        Text(
          game.analysing || game.analyse
              ? 'working out the best guesses…'
              : 'the best guesses are not worked out in this game.',
          style: _dimStyle(c),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      );
    }
    final bits = n > 0 ? log(n) / ln2 : 0.0;
    if (skill) {
      for (final r in game.bestForSkill) {
        final plot = game.plotOf(r.word, best: land.bestGain);
        final groups = plot.outcomes.length;
        final h = plot.expected;
        lines.add(
          _optionRow(
            word: r.word,
            line: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${h.toStringAsFixed(2)} bits',
                    style: TextStyle(
                      color: skillColor(c),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' · $groups groups · skill ${r.skill.round()}',
                  ),
                ],
              ),
              style: _dimStyle(c),
            ),
            dot: CalcSpec(
              metric: 'skill',
              title: r.word,
              intro:
                  '${r.word} is among the guesses that split the ${_n(n)} '
                  'words that fit most evenly. it can be a word that cannot '
                  'win.',
              rows: [
                ('groups it makes', '$groups'),
                ('bits it gains on average (H)', h.toStringAsFixed(2)),
                (
                  'best bits among all guesses (H*)',
                  land.bestGain.toStringAsFixed(2),
                ),
                ('bits still to find', 'log₂ $n = ${bits.toStringAsFixed(2)}'),
              ],
              result: ('skill = H ÷ H* × 100', '${r.skill.round()}'),
              note: game.blind
                  ? 'in blind a group is a pair of counts, so there are far '
                        'fewer groups than with colours.'
                  : 'a guess that splits well is not always a word that fits.',
              plot: plot,
            ),
          ),
        );
      }
    } else {
      for (final r in game.betsForLuck) {
        final plot = game.plotOf(r.word, best: land.bestGain);
        var up = 0.0;
        for (final o in plot.outcomes) {
          if (o.gain > plot.expected + 1e-9) up += o.chance;
        }
        lines.add(
          _optionRow(
            word: r.word,
            line: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_pc(up)} lucky',
                    style: TextStyle(
                      color: luckColor(c),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' · ${plot.expected.toStringAsFixed(2)} bits on '
                        'average',
                  ),
                ],
              ),
              style: _dimStyle(c),
            ),
            dot: CalcSpec(
              metric: 'luck',
              title: r.word,
              intro:
                  'a bet: ${r.word} gets a reply that gains more than its '
                  'average ${_pc(up)} of the time. the rest of the time it '
                  'gains less, sometimes much less.',
              rows: [
                (
                  'its average gain (H)',
                  '${plot.expected.toStringAsFixed(2)} bits',
                ),
                ('chance of gaining more than H', _pc(up)),
                ('chance of gaining less than H', _pc(1 - up)),
                ('groups it makes', '${plot.outcomes.length}'),
              ],
              result: ('luck is the reply you get', 'not the guess'),
              note:
                  'a bet is picked for its chance of a good reply. it is not '
                  'the best guess: skill is.',
              plot: plot,
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }

  /// One candidate: its word, a line about it, an info dot when it has a
  /// calculation, and "use".
  Widget _optionRow({
    required String word,
    required Widget line,
    CalcSpec? dot,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            word,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(child: line),
          if (dot != null) ...[CalcDot(dot), const SizedBox(width: 8)],
          _Pill(
            'use',
            key: ValueKey('use-$word'),
            onTap: () {
              try {
                game.use(word);
                Navigator.pop(context);
              } catch (e) {
                appLog.w('learn', 'could not use a word: ${e.runtimeType}');
              }
            },
          ),
        ],
      ),
    );
  }

  TextStyle _dimStyle(ColorScheme c) => TextStyle(
    fontSize: 12,
    height: 1.4,
    color: c.onSurface.withValues(alpha: dimAlpha),
  );

  /// The chance of [word] being the answer, among the words that fit.
  double _chanceOf(String word) {
    final w = game.weights;
    if (w == null) return game.pool.isEmpty ? 0 : 1 / game.pool.length;
    var total = 0.0;
    for (final x in game.pool) {
      total += max(w[x] ?? 1, 1);
    }
    return total <= 0 ? 0 : max(w[word] ?? 1, 1) / total;
  }

  // ---- the logic of the colours ----

  void _logic() => _dialog(() {
    final c = Theme.of(context).colorScheme;
    return showHairlineDialog<void>(
      context,
      title: 'the logic, letter by letter',
      titleColor: bitsColor(c),
      children: [_logicBody(c)],
    );
  });

  Widget _logicBody(ColorScheme c) {
    if (game.rows.isEmpty) {
      return const Text(
        'guess a word and its logic is written here, letter by letter.',
        style: TextStyle(fontSize: 13, height: 1.5),
      );
    }
    final intro = game.blind
        ? 'a blind guess gives two counts: green, how many of its letters are '
              'in place, and yellow, how many are in the word elsewhere. the '
              'colours are worked out from them: a count of 0 rules every '
              'letter out, a total of ${game.length} puts every letter in, and '
              'a guess with all its right letters marked rules out the rest.'
        : 'green: the letter is here. yellow: it is in the word, but not here. '
              'grey: it is not in the word (or no more copies than the '
              'coloured ones). each tile cuts the words that fit.';
    final dim = _dimStyle(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro, style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 6),
        for (var r = 0; r < game.rows.length; r++)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey('logic-$r'),
              initiallyExpanded: r == game.rows.length - 1,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: game.rows[r].word,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          '  ${_label(game.rows[r])}  ·  '
                          '${_n(game.rows[r].before)} → '
                          '${_n(game.rows[r].after)}',
                      style: dim,
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
              children: [
                for (var i = 0; i < game.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BlindTile(
                          game.rows[r].word[i],
                          mark: game.blind
                              ? game.shownAt(r, i)
                              : game.rows[r].marks[i],
                          helper: false,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${i + 1}. ${_tileLogic(r, i)}',
                            style: const TextStyle(fontSize: 12, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  int _count(List<String> pool, bool Function(String) f) =>
      pool.where(f).length;

  /// Why tile [i] of guess [r] has its colour.
  String _tileLogic(int r, int i) {
    final row = game.rows[r];
    final ch = row.word[i];
    final pool = game.pools[r];
    final p = _n(pool.length);
    final others = [
      for (var j = 0; j < row.word.length; j++)
        if (row.word[j] == ch && j != i) j,
    ];
    final more = others.isEmpty
        ? ''
        : ' ($ch also stands at place '
              '${others.map((j) => j + 1).join(', ')} of this guess)';
    if (!game.blind) {
      switch (row.marks[i]) {
        case Mark.correct:
          final k = _count(pool, (x) => x[i] == ch);
          return 'green: $ch is in place ${i + 1}. of the $p words that '
              'fitted, ${_n(k)} have $ch there.';
        case Mark.present:
          final k = _count(pool, (x) => x.contains(ch) && x[i] != ch);
          return 'yellow: $ch is in the word, but not in place ${i + 1}. '
              '${_n(k)} of $p have it elsewhere. it can still be in any other '
              'place.$more';
        case Mark.absent:
          final sibling = others.any((j) => row.marks[j] != Mark.absent);
          if (sibling) {
            return 'grey: no more copies of $ch than the coloured one$more. '
                'the word has it only as often as the guess shows it.';
          }
          final k = _count(pool, (x) => !x.contains(ch));
          return 'grey: $ch is not in the word at all. ${_n(k)} of $p words '
              'lack it.';
      }
    }
    // blind: the colours are not shown, so the reason is worked from the counts
    // and the pencil
    final hit = row.green + row.yellow;
    final len = game.length;
    final d = game.deduced;
    final pm = game.shownAt(r, i);
    final key = '$ch@$i';
    final fx = game.forced[key];
    final rows = game.rows;
    if (d[ch] == Mark.absent) {
      final z = rows.indexWhere(
        (x) => x.green + x.yellow == 0 && x.word.contains(ch),
      );
      final full = rows.indexWhere(
        (x) => x.green + x.yellow == len && !x.word.contains(ch),
      );
      if (z >= 0)
        return 'grey: guess ${z + 1} found no right letter, so $ch is out.';
      if (full >= 0) {
        return 'grey: guess ${full + 1} has all $len right letters, and $ch '
            'is not among them.';
      }
      return 'grey: the counts of the guesses together rule $ch out (guesses '
          'that share no letter add up to $len right letters, so the rest is '
          'out).';
    }
    if (game.pencil.soft.contains(ch) && pm == Mark.absent && fx == null) {
      return 'grey: guess ${r + 1} has its $hit right '
          '${hit == 1 ? 'letter' : 'letters'} marked, so the rest of it is '
          'out, $ch too. mark $ch instead and the other mark stands down.';
    }
    if (fx == Mark.absent) {
      return 'grey: ${hit == 0 ? 'no right letter in the guess' : 'every letter of the word is found'}, '
          'so $ch is out. set by the helper.';
    }
    if (fx == Mark.present) {
      return 'yellow: guess ${r + 1} has '
          '${hit == len ? 'every letter in the word' : '$ch in the word'} and '
          'no green, so $ch is in the word but not in place ${i + 1}. set by '
          'the helper.';
    }
    if (fx == Mark.correct) {
      return 'green: guess ${r + 1} has no yellow, so every right letter is in '
          'place, $ch too. set by the helper.';
    }
    if (game.pencil.softTiles.containsKey(key)) {
      return '${pm == Mark.correct ? 'green' : 'yellow'}: it follows from the '
          'counts and your marks.';
    }
    if (pm == Mark.correct) return 'green: you marked $ch in place ${i + 1}.';
    if (pm == Mark.present) {
      return 'yellow: you marked $ch in the word, not in place ${i + 1}.';
    }
    if (pm == Mark.absent) return 'grey: you marked $ch out.';
    final here = _count(game.pool, (x) => x[i] == ch);
    final elsewhere = _count(game.pool, (x) => x.contains(ch) && x[i] != ch);
    final none = _count(game.pool, (x) => !x.contains(ch));
    return 'not settled: of the ${_n(game.pool.length)} words that fit, '
        '${_n(here)} have $ch in place ${i + 1} (green), ${_n(elsewhere)} have '
        'it elsewhere (yellow), ${_n(none)} lack it (grey).';
  }

  /// The marks of a guess as text: letters g, y, x, or the two counts in blind.
  String _label(MasterRow r) => game.blind
      ? '${r.green} green · ${r.yellow} yellow'
      : r.marks
            .map(
              (m) => switch (m) {
                Mark.correct => 'g',
                Mark.present => 'y',
                Mark.absent => 'x',
              },
            )
            .join();
}

/// 12345 as 12,345.
String _n(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// A chance as a percent.
String _pc(double p) {
  final x = p * 100;
  final d = x < 1 ? 2 : (x < 10 ? 1 : 0);
  return '${x.toStringAsFixed(d)}%';
}

/// A small pill button: hairline edge, no fill.
class _Pill extends StatelessWidget {
  const _Pill(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: c.outline, width: hairlineWidth),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// A letter tile of a blind board: its colour is the pencil's (none is an
/// outline), a dot in its top right corner says the helper set it, and a tap
/// marks it.
class _BlindTile extends StatelessWidget {
  const _BlindTile(
    this.ch, {
    required this.mark,
    required this.helper,
    required this.size,
    this.onTap,
  });
  final String ch;
  final Mark? mark;
  final bool helper;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      MarkTile(ch, mark: mark, size: size, onTap: onTap, helper: helper);
}
