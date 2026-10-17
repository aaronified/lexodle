import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic.dart';
import 'main.dart';
import 'store.dart';
import 'ui.dart';
import 'word_info.dart';
import 'words.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.bank});
  final WordBank bank;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _rng = Random();
  final _focus = FocusNode();

  late final int length;
  late final int tries;
  late final List<String> _pool;
  late final Set<String> _letters;

  late String answer;
  late List<String> eligible;
  final guesses = <String>[];
  final marks = <List<Mark>>[];
  final keyMarks = <String, Mark>{};
  String input = '';
  String message = '';
  bool over = false;
  bool won = false;
  List<Achievement> unlocked = [];

  @override
  void initState() {
    super.initState();
    length = appState.length;
    tries = appState.tries;
    _pool = widget.bank.answers(length);
    _letters = widget.bank.letters(length);
    _reset();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    answer = chooseWord(_pool, widget.bank.answerWeights(length), _rng);
    eligible = List.of(_pool);
    guesses.clear();
    marks.clear();
    keyMarks.clear();
    input = '';
    message = '';
    over = won = false;
    unlocked = [];
  }

  void _type(String ch) {
    if (over || input.length >= length || !_letters.contains(ch)) return;
    setState(() {
      input += ch;
      message = '';
    });
  }

  void _back() {
    if (over || input.isEmpty) return;
    setState(() {
      input = input.substring(0, input.length - 1);
      message = '';
    });
  }

  void _submit() {
    if (over) return;
    if (input.length != length) {
      setState(() => message = 'need $length letters');
      return;
    }
    if (guesses.contains(input)) {
      setState(() => message = 'already guessed');
      return;
    }
    if (!widget.bank.valid.contains(input)) {
      setState(() => message = 'not in the word list');
      return;
    }
    final m = evaluate(answer, input);
    setState(() {
      guesses.add(input);
      marks.add(m);
      for (var i = 0; i < length; i++) {
        final k = input[i];
        final old = keyMarks[k];
        // correct beats present beats absent
        if (old == null || m[i].index < old.index) keyMarks[k] = m[i];
      }
      eligible = filterEligible(eligible, input, m);
      final solved = input == answer;
      input = '';
      message = '';
      if (solved || guesses.length >= tries) {
        over = true;
        won = solved;
        unlocked = appState.recordGame(GameResult(
          lang: widget.bank.language.code,
          length: length,
          tries: tries,
          used: guesses.length,
          won: solved,
        ));
      }
    });
  }

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
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              '${widget.bank.language.name.toLowerCase()} · $length · $tries tries',
              style: const TextStyle(fontSize: 14, letterSpacing: 1.5)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Expanded(child: _grid()),
                SizedBox(height: 56, child: Center(child: _status(c))),
                if (over) _overPanel(c) else _keyboard(c),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      const gap = 6.0;
      final tile =
          min(56.0, (box.maxWidth - 32 - gap * (length - 1)) / length);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: Column(children: [
            for (var r = 0; r < tries; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _tile(
                      c,
                      tile,
                      r < guesses.length
                          ? guesses[r][i]
                          : (r == guesses.length && i < input.length
                              ? input[i]
                              : ''),
                      r < marks.length ? marks[r][i] : null,
                      active: r == guesses.length && !over,
                    ),
                  ],
                ]),
              ),
          ]),
        ),
      );
    });
  }

  Widget _tile(ColorScheme c, double size, String ch, Mark? m,
      {required bool active}) {
    Color? fill;
    Color fg = c.onSurface;
    Color border = active ? c.onSurface.withValues(alpha: .5) : c.outlineVariant;
    switch (m) {
      case Mark.correct:
        fill = c.primary;
        fg = c.onPrimary;
        border = c.primary;
      case Mark.present:
        fill = c.tertiaryContainer;
        fg = c.onTertiaryContainer;
        border = c.tertiary;
      case Mark.absent:
        fill = c.surfaceContainerHighest;
        fg = c.onSurface.withValues(alpha: .45);
        border = c.surfaceContainerHighest;
      case null:
        if (ch.isNotEmpty) border = c.onSurface;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: m == Mark.present ? 2 : 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(ch,
          style: TextStyle(
              fontSize: size * .5, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _status(ColorScheme c) {
    if (message.isNotEmpty) {
      return Text(message, style: TextStyle(color: c.error));
    }
    if (appState.showWordsLeft && !over && guesses.isNotEmpty) {
      return Caption('${eligible.length} possible '
          '${eligible.length == 1 ? 'word' : 'words'} · '
          '${tries - guesses.length} left');
    }
    if (!over) return Caption('${tries - guesses.length} tries left');
    return const SizedBox();
  }

  Widget _overPanel(ColorScheme c) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            won
                ? 'solved in ${guesses.length} of $tries'
                : 'the word was  $answer',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (won) Caption(answer),
        const SizedBox(height: 10),
        for (final a in unlocked)
          Text('★ ${a.title}  —  ${a.description}',
              style: TextStyle(color: c.primary, fontSize: 13)),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        WordInfoView(word: answer, language: widget.bank.language),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context), child: const Text('menu')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
                onPressed: () => setState(_reset), child: const Text('again')),
          ),
        ]),
      ]),
      ),
    );
  }

  Widget _keyboard(ColorScheme c) {
    const base = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    final extra = _letters.where((l) => !base.join().contains(l)).toList()
      ..sort();
    final rows = <List<String>>[
      for (final r in base) r.split('').where(_letters.contains).toList(),
      for (var i = 0; i < extra.length; i += 10)
        extra.sublist(i, min(i + 10, extra.length)),
    ];
    Widget key(String label, VoidCallback tap, {Mark? mark, double flex = 1}) {
      Color? fill;
      Color fg = c.onSurface;
      switch (mark) {
        case Mark.correct:
          fill = c.primary;
          fg = c.onPrimary;
        case Mark.present:
          fill = c.tertiaryContainer;
          fg = c.onTertiaryContainer;
        case Mark.absent:
          fill = c.surfaceContainerHighest;
          fg = c.onSurface.withValues(alpha: .35);
        case null:
      }
      return Expanded(
        flex: (flex * 10).round(),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: fill ?? c.outline),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: label.length > 1 ? 11 : 16,
                      fontWeight: FontWeight.bold,
                      color: fg)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++)
          Row(children: [
            if (i == 2) key('enter', _submit, flex: 1.6),
            for (final l in rows[i]) key(l, () => _type(l), mark: keyMarks[l]),
            if (i == 2) key('⌫', _back, flex: 1.6),
          ]),
      ]),
    );
  }
}
