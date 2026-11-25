import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'calc_dialog.dart';
import 'drill_calc.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'opening.dart';
import 'precomputed.dart';
import 'precomputed_local.dart';
import 'review_plots.dart';
import 'ui.dart';
import 'tonal.dart';
import 'ui_kit.dart';
import 'words.dart';

/// How many of the likeliest replies a level lists.
const openingReplyCount = 5;

/// The opening, three guesses deep: the best first guess for the language and
/// length, its five likeliest replies, and, for the reply picked (tapped, set
/// by colours or drawn by chance), the best second guess for the words that
/// fit, and so on to the third. Nothing here is scored.
class OpeningPage extends StatefulWidget {
  const OpeningPage({super.key, required this.bank, this.random});
  final WordBank bank;

  /// The source of the replies drawn by chance (a test gives a seeded one).
  final Random? random;

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _OpeningPageState extends State<OpeningPage> {
  late final int length = appState.learnLength;
  late final List<String> _words = widget.bank.guessable(length);
  late final Map<String, int>? _law = widget.bank.law(
    length,
    appState.learnDraw,
  );
  late final Random _rng = widget.random ?? Random();

  /// The guess of each of the three levels, and how it splits that level's words.
  final _guess = List<String?>.filled(3, null);
  final _walks = List<GroupWalk?>.filled(3, null);

  /// The reply picked at the first two levels.
  final _sel = List<List<Mark>?>.filled(2, null);

  /// The level whose colours are being set, and the colours so far.
  int? _edit;
  List<Mark> _editMarks = const [];

  /// The level where the colours set match no word.
  int? _noWord;

  /// Second guesses the precomputed tree kept, by the first replies' colours.
  Map<String, List<Recommendation>> _tree = const {};
  Future<void>? _treeLoad;

  /// Which choice the guesses below belong to: an answer that comes after
  /// another was picked is dropped.
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await openingLandscape(
        bank: widget.bank,
        length: length,
        draw: appState.learnDraw,
      );
      if (!mounted) return;
      final first = l.top.first.word;
      final w = walkGroups(_words, first, _law);
      setState(() {
        _guess[0] = first;
        _walks[0] = w;
      });
      _treeLoad = _fromTree(first);
    } catch (e) {
      appLog.w('learn', 'opening first guess failed ${e.runtimeType}');
    }
  }

  /// The best second guesses the precompute workflow kept for the best first
  /// guess, when they were downloaded (or, on the web, can be read): used at
  /// once, and only the replies it has not got are worked out.
  Future<void> _fromTree(String first) async {
    // the workflow keeps only the lists the app keeps: a small one is no
    // request at all
    if (_words.length * _words.length < openingCells) return;
    try {
      final key = openingKeyOf(_words, _words, _law, false);
      final name = openingFileName(key);
      final local = PrecomputedLocal.readTree(name);
      final tree = local != null
          ? jsonDecode(local) as Map<String, dynamic>
          : await fetchPrecomputedTree(key);
      if (tree == null || tree['first'] != first || !mounted) return;
      _tree = {
        for (final g in tree['groups'] as List)
          g['marks'] as String: [
            for (final r in g['seconds'] as List)
              Recommendation(
                r[0] as String,
                (r[1] as num).toDouble(),
                (r[2] as num).toDouble(),
                r[3] == 1,
              ),
          ],
      };
    } catch (e) {
      // a hint: the second guesses are worked out when there is none
      appLog.w('learn', 'opening tree failed ${e.runtimeType}');
    }
  }

  List<String> _poolOf(int k) {
    if (k == 0) return _words;
    final w = _walks[k - 1];
    final s = _sel[k - 1];
    if (w == null || s == null) return const [];
    final g = _groupOf(w, s);
    return g?.words ?? const [];
  }

  GroupLine? _groupOf(GroupWalk w, List<Mark> marks) {
    final code = markCode(marks);
    for (final g in w.groups) {
      if (markCode(g.marks) == code) return g;
    }
    return null;
  }

  /// Picks [marks] as the reply to the guess of level [k]: the levels below
  /// are cleared and the next guess is worked out.
  void _select(int k, List<Mark> marks) {
    final w = _walks[k];
    if (w == null) return;
    final g = _groupOf(w, marks);
    if (g == null) {
      setState(() => _noWord = k);
      return;
    }
    final serial = ++_serial;
    setState(() {
      _noWord = null;
      _edit = null;
      _sel[k] = marks;
      for (var j = k + 1; j < 3; j++) {
        _guess[j] = null;
        _walks[j] = null;
        if (j < 2) _sel[j] = null;
      }
    });
    _next(k + 1, g, serial);
  }

  Future<void> _next(int level, GroupLine group, int serial) async {
    List<Recommendation>? best;
    try {
      if (level == 1) {
        await _treeLoad;
        final got = _tree[group.marks.map((m) => m.index).join()];
        if (got != null && got.isNotEmpty) best = got;
      }
      best ??= await secondGuesses(
        group: group,
        guessable: _words,
        weights: _law,
      );
    } catch (e) {
      appLog.w('learn', 'opening next guess failed ${e.runtimeType}');
    }
    if (!mounted || serial != _serial) return;
    try {
      final word = best != null && best.isNotEmpty
          ? best.first.word
          : group.words.first;
      final w = walkGroups(group.words, word, _law);
      setState(() {
        _guess[level] = word;
        _walks[level] = w;
      });
    } catch (e) {
      appLog.w('learn', 'opening walk failed ${e.runtimeType}');
    }
  }

  /// A reply drawn by chance: a word of the level's pool, as likely as its
  /// share of the words, and the colours the guess shows for it.
  void _randomise(int k) {
    try {
      final pool = _poolOf(k);
      final guess = _guess[k];
      if (pool.isEmpty || guess == null) return;
      final weights = [
        for (final w in pool) _law == null ? 1 : max(_law[w] ?? 1, 1),
      ];
      final word = chooseWord(pool, weights, _rng);
      _select(k, evaluate(word, guess));
    } catch (e) {
      appLog.w('learn', 'opening randomise failed ${e.runtimeType}');
    }
  }

  void _toggleEdit(int k) {
    setState(() {
      if (_edit == k) {
        _edit = null;
      } else {
        _edit = k;
        _noWord = null;
        _editMarks = List<Mark>.of(
          _sel[k] ?? List<Mark>.filled(length, Mark.absent),
        );
      }
    });
  }

  void _cycle(int i) {
    const next = {
      Mark.absent: Mark.present,
      Mark.present: Mark.correct,
      Mark.correct: Mark.absent,
    };
    setState(() {
      final m = List<Mark>.of(_editMarks);
      m[i] = next[m[i]]!;
      _editMarks = m;
    });
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PageHeader(
                  text: 'the opening · $lang · $length',
                  back: true,
                  settings: false,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('three guesses to open with', style: dim),
                      const SizedBox(height: 14),
                      if (_walks[0] == null)
                        const Text(
                          'working out the best first guess…',
                          key: ValueKey('opening-loading'),
                        )
                      else
                        ..._levels(context, c, dim),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _levels(BuildContext context, ColorScheme c, TextStyle dim) {
    final out = <Widget>[];
    for (var k = 0; k < 3; k++) {
      final w = _walks[k];
      if (w == null) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'working out the ${_ords[k]} guess…',
              key: ValueKey('opening-loading-$k'),
              style: dim,
            ),
          ),
        );
        break;
      }
      out.add(_level(context, c, dim, k, w));
      if (k == 2) {
        final thing = thingOf(appState.mode);
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'three guesses in: about ${_left(w)} $thing left on average.',
              key: const ValueKey('opening-end'),
              style: dim,
            ),
          ),
        );
        break;
      }
      out.addAll(_replies(context, c, dim, k, w));
      if (_sel[k] == null) {
        if (_noWord == k && _edit != k) out.add(_noWordText(dim));
        break;
      }
    }
    return out;
  }

  static const _ords = ['first', 'second', 'third'];

  Widget _noWordText(TextStyle dim) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      'no word gives these colours.',
      key: const ValueKey('opening-no-word'),
      style: dim,
    ),
  );

  int _left(GroupWalk w) => max(1, (w.words / pow(2, w.expectedBits)).round());

  CalcSpec _levelSpec(int k, GroupWalk w) {
    final n = w.words;
    final thing = thingOf(appState.mode);
    final h = w.expectedBits;
    return CalcSpec(
      metric: 'skill',
      title: 'the best ${_ords[k]} guess',
      intro: k == 0
          ? '${w.guess} splits the $n $thing into ${w.groups.length} groups, '
                'the most information of any word.'
          : 'after the replies so far, $n $thing fit. ${w.guess} splits '
                'them best.',
      rows: [
        ('$thing that fit', '$n'),
        ('groups it makes', '${w.groups.length}'),
        ('bits it gains on average (H)', '${h.toStringAsFixed(2)} bits'),
        ('bits still to find', 'log₂ $n = ${bitsOf(1 / n).toStringAsFixed(2)}'),
      ],
      result: ('$thing left on average ≈ N/2^H', '≈ ${_left(w)}'),
      note: k == 0 || n > 400
          ? 'scored over every $thing as a guess.'
          : 'scored over every $thing as a guess, fitting or not.',
      plot: PlotSpec(
        outcomes: [
          for (final g in w.groups) Outcome(g.chance, bitsOf(g.chance)),
        ],
        expected: h,
        word: w.guess,
        sizes: [for (final g in w.groups) g.words.length],
      ),
    );
  }

  /// The share of the words the five likeliest replies cover.
  double _coverOf(GroupWalk w) =>
      w.groups.take(openingReplyCount).fold<double>(0, (s, g) => s + g.chance);

  /// The colour of one letter of a reply: green right, yellow wrong place, and
  /// the absent grey.
  Color _squareOf(ColorScheme c, Mark m) => switch (m) {
    Mark.correct => c.secondary,
    Mark.present => yellowOf(c),
    Mark.absent => markColors(c, Mark.absent).$1,
  };

  /// A letter of a word, as a square tile on the tone above the group.
  Widget _tile(BuildContext context, String ch, double size, double font) =>
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tonesOf(context).s2,
          borderRadius: BorderRadius.circular(radiusElement),
        ),
        child: Text(
          ch,
          style: TextStyle(
            fontSize: font,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );

  /// A bar of [f] (0 to 1) of the width, on the tone three above the page.
  Widget _bar(BuildContext context, ColorScheme c, double f) {
    final v = f > 1 ? 1.0 : (f < 0 ? 0.0 : f);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: tonesOf(context).s3,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _level(
    BuildContext context,
    ColorScheme c,
    TextStyle dim,
    int k,
    GroupWalk w,
  ) {
    final key = ['opening-first', 'opening-second', 'opening-third'][k];
    final strip = StatsStrip([
      (w.expectedBits.toStringAsFixed(2), 'bits expected', skillColor(c)),
      ('${_left(w)}', 'words left on average', null),
      ('${(_coverOf(w) * 100).round()}%', 'in these five replies', null),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (k > 0) SectionLabel('${_ords[k]} guess'),
        if (k == 0) const SizedBox(height: 4),
        TonalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('best ${_ords[k]} guess', style: dim)),
                  CalcDot(_levelSpec(k, w), key: ValueKey('opening-dot-$k')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                key: ValueKey(key),
                children: [
                  for (var i = 0; i < w.guess.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _tile(context, w.guess[i], 36, 18),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: k == 0 ? const ValueKey('opening-stats') : null,
                child: strip,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The square row of one reply: a letter's colour per square.
  Widget _squares(ColorScheme c, GroupLine g) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < g.marks.length; i++)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _squareOf(c, g.marks[i]),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
    ],
  );

  List<Widget> _replies(
    BuildContext context,
    ColorScheme c,
    TextStyle dim,
    int k,
    GroupWalk w,
  ) {
    final thing = thingOf(appState.mode);
    final top = w.groups.take(openingReplyCount).toList();
    final cover = _coverOf(w);
    final most = top.isEmpty ? 1.0 : top.first.chance;
    final cur = _sel[k];
    final curCode = cur == null ? null : markCode(cur);
    final custom = cur != null && !top.any((g) => markCode(g.marks) == curCode)
        ? _groupOf(w, cur)
        : null;
    final spec = CalcSpec(
      metric: 'bits',
      title: 'the likeliest replies',
      intro:
          'every word gives one reply to this guess. these five are the '
          'commonest. together they cover only part of the $thing, so any '
          'other reply is one tap away.',
      rows: [
        ('$thing that fit', '${w.words}'),
        ('the five cover', _pc(cover)),
        ('replies this guess can give', '${w.groups.length}'),
      ],
      result: ('not covered', _pc(1 - cover)),
      note:
          'below, set any colours yourself, or draw a reply by chance (each '
          'as likely as its share of the $thing).',
    );

    // the best second guess and its words left, under a reply that is picked
    Widget then() {
      final next = k < 2 ? _walks[k + 1] : null;
      final word = k < 2 ? _guess[k + 1] : null;
      if (next == null || word == null || _sel[k] == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text('then', style: dim),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < word.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _tile(context, word[i], 28, 15),
                ],
              ],
            ),
            Text('${_left(next)} $thing left on average', style: dim),
          ],
        ),
      );
    }

    GroupRow row(GroupLine g, String key) {
      final on = curCode == markCode(g.marks);
      final share = most > 0 ? g.chance / most : 0.0;
      return GroupRow(
        key: ValueKey(key),
        onTap: () => _select(k, g.marks),
        title: _squares(c, g),
        below: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _bar(context, c, share),
            const SizedBox(height: 6),
            Text(
              '${g.words.length} '
              '${thingOf(appState.mode, plural: g.words.length != 1)}'
              ' · ${_pc(g.chance)}',
              style: dim.copyWith(fontSize: 12),
            ),
            if (on) then(),
          ],
        ),
      );
    }

    return [
      Row(
        children: [
          Expanded(
            child: SectionLabel('the five likeliest replies', first: k == 0),
          ),
          CalcDot(spec, key: ValueKey('opening-replies-dot-$k')),
        ],
      ),
      GroupedList(
        rows: [
          for (var i = 0; i < top.length; i++)
            row(top[i], 'opening-reply-$k-$i'),
          if (custom != null) row(custom, 'opening-reply-$k-custom'),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          'the five cover ${_pc(cover)} of the $thing.',
          key: ValueKey('opening-cover-$k'),
          style: dim,
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(c, 'set colours', 'opening-set-$k', () => _toggleEdit(k)),
          _pill(c, 'randomise', 'opening-random-$k', () => _randomise(k)),
        ],
      ),
      if (_edit == k) ...[
        const SizedBox(height: 8),
        TonalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _editMarks.length; i++)
                    MarkTile(
                      '',
                      key: ValueKey('opening-tile-$k-$i'),
                      mark: _editMarks[i],
                      size: 36,
                      onTap: () => _cycle(i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _pill(
                c,
                'use these',
                'opening-use-$k',
                () => _select(k, List<Mark>.of(_editMarks)),
              ),
              if (_noWord == k) _noWordText(dim),
            ],
          ),
        ),
      ],
    ];
  }

  /// A low-emphasis button of the tonal kind (no edge), 48 high.
  Widget _pill(ColorScheme c, String text, String key, VoidCallback onTap) =>
      OutlinedButton(key: ValueKey(key), onPressed: onTap, child: Text(text));

  String _pc(double q) => '${(q * 100).toStringAsFixed(1)}%';
}
