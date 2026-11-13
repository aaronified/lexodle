import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../game_header.dart';
import '../guess_input.dart';
import '../hint_pick.dart';
import '../keyboard.dart';
import '../lex.dart';
import '../lex_widgets.dart';
import '../logic.dart';
import '../main.dart' show appState;
import '../modes.dart';
import '../swipe_clear.dart';
import '../ui.dart';
import '../words.dart';
import 'first_game_engine.dart';

/// The first game: a playable, guided game, not a lesson. No step counter and
/// no tries limit; one quiet line under the board, only when it applies. The
/// word is chosen as the player plays (see [FirstGameEngine]). Nothing is
/// persisted: the flow owner stores the stage. With [practice] the title says
/// so and the free hint is not taken from the player's own.
class FirstGamePage extends StatefulWidget {
  const FirstGamePage({
    super.key,
    required this.onDone,
    required this.onClose,
    this.practice = false,
  });

  final VoidCallback onDone;
  final VoidCallback onClose;
  final bool practice;

  @override
  State<FirstGamePage> createState() => _FirstGamePageState();
}

const _len = 5;

class _FirstGamePageState extends State<FirstGamePage> {
  Language? _language;
  FirstGameEngine? _engine;
  Set<String> _letters = const {};
  bool _failed = false;

  final _input = GuessInput(_len);
  final _focus = FocusNode();
  final _shift = ShiftTap();
  final _guesses = <String>[];
  final _marks = <List<Mark>>[];
  final _keyMarks = <String, Mark>{};
  final _picks = <HintPick>[];
  FirstGameProgress _progress = const FirstGameProgress();

  FirstChoice? _choice;
  String _suggested = '';
  String _target = '';
  bool _done = false;
  bool _finished = false;
  bool _kbSeen = false;
  bool _tray = false;
  int _practiceFree = startingFreeHints;
  String _message = '';

  /// The invalid word shown, and its one-letter fix.
  String? _invalid;
  LetterFix? _fix;
  String _fixTried = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The word list of the current language when it has five-letter words, else
  /// English.
  Future<void> _load() async {
    try {
      final langs = await WordBank.languages();
      Language? pick;
      for (final l in langs) {
        if (l.code == appState.lang && l.lengths.contains(_len)) pick = l;
      }
      pick ??= langs.firstWhere((l) => l.code == 'en');
      final bank = await WordBank.load(pick);
      final words = bank.guessable(_len);
      if (words.isEmpty) throw StateError('no words');
      if (!mounted) return;
      setState(() {
        _language = pick;
        _letters = bank.letters(_len);
        _engine = FirstGameEngine(words);
      });
    } catch (e) {
      appLog.w('first-game', 'could not load the words: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  // --- state helpers ---

  int get _free => widget.practice ? _practiceFree : appState.freeHints;

  void _clearNotes() {
    _message = '';
    _invalid = null;
    _fix = null;
    _fixTried = '';
  }

  void _guard(String what, void Function() f) {
    try {
      f();
    } catch (e) {
      appLog.w('first-game', 'could not $what: ${e.runtimeType}');
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    try {
      widget.onDone();
    } catch (e) {
      appLog.w('first-game', 'could not finish: ${e.runtimeType}');
    }
  }

  // --- input ---

  void _type(String ch) => _guard('type', () {
    if (_done) return;
    setState(() {
      _clearNotes();
      if (_input.type(ch, _letters) >= 0) {
        _progress = _progress.onType(
          ch == GuessInput.blank ? '_' : ch,
          tutorial: true,
        );
      }
    });
  });

  void _back() => _guard('delete', () {
    if (_done) return;
    setState(() {
      _clearNotes();
      _input.back();
      _progress = _progress.onDelete(tutorial: true);
    });
  });

  void _clearRow() => _guard('clear the row', () {
    if (_done) return;
    setState(() {
      _clearNotes();
      _input.clearTyped();
      _progress = _progress.onClear(tutorial: true);
    });
  });

  void _move(int by) => _guard('move the cursor', () {
    if (_done) return;
    setState(() {
      _input.move(by);
      if (by < 0) _progress = _progress.onArrowLeft(tutorial: true);
    });
  });

  void _tap(int i) => _guard('tap a tile', () {
    if (_done) return;
    setState(() {
      final fixAt = _fix?.index;
      final fixTapped = fixAt != null && fixAt == i && _invalid != null;
      final again = _input.tap(i);
      _progress = _progress.onTap(
        i,
        fixIndex: fixTapped ? fixAt : null,
        tutorial: true,
      );
      if (fixTapped && !again) {
        // the arrow asks for another letter there: empty it, say which
        _input.select(i);
        _input.back();
        _fixTried = _fix!.letter;
        _invalid = null;
        _fix = null;
      }
      if (again && _input.isLocked(i)) {
        _progress = _progress.onLocked(tutorial: true);
      }
    });
  });

  void _toggleLockAtCursor() => _guard('lock a letter', () {
    if (_done) return;
    setState(() {
      final i = _input.cursor;
      if (_input.toggleLock(i)) {
        _progress = _progress.onLocked(tutorial: true);
      }
    });
  });

  /// A double tap on the guesses locks every green found so far.
  void _lockGreens() => _guard('lock the greens', () {
    if (_done) return;
    final greens = <(int, String)>[
      for (var r = 0; r < _marks.length; r++)
        for (var i = 0; i < _len; i++)
          if (_marks[r][i] == Mark.correct) (i, _guesses[r][i]),
    ];
    if (greens.isEmpty) return;
    setState(() {
      _input.lockAll(greens);
      _progress = _progress.onLocked(tutorial: true);
    });
  });

  void _submit() => _guard('send the guess', () {
    final engine = _engine;
    if (_done || engine == null) return;
    if (!_input.complete) {
      setState(() {
        _message = _input.hasBlank
            ? 'a blank cannot be sent. fill it first.'
            : 'five letters first.';
      });
      return;
    }
    final word = _input.word;
    if (_guesses.contains(word)) {
      setState(() => _message = 'already guessed.');
      return;
    }
    if (!engine.isValid(word)) {
      setState(() {
        _invalid = word;
        _fix = engine.oneLetterFix(word);
        _fixTried = '';
        _message = '';
      });
      return;
    }
    setState(() {
      _clearNotes();
      if (_guesses.isEmpty) {
        final c = engine.chooseFirst(word);
        _choice = c;
        _target = c.target;
        _suggested = engine.suggestion(word, c.pattern, c.candidates);
      } else if (_guesses.length == 1 && _choice != null) {
        _target = engine.chooseSecond(
          word,
          candidates: _choice!.candidates,
          suggested: _suggested,
          target: _target,
        );
      }
      final m = evaluate(_target, word);
      _guesses.add(word);
      _marks.add(m);
      for (var i = 0; i < _len; i++) {
        final old = _keyMarks[word[i]];
        if (old == null || m[i].index < old.index) _keyMarks[word[i]] = m[i];
      }
      if (word == _target) {
        _done = true;
        _tray = false;
      } else {
        _input.next();
        _progress = _progress.onGuess(tutorial: true);
      }
    });
  });

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    try {
      if (!_kbSeen) setState(() => _kbSeen = true);
      if (_shift.tapped(e)) {
        _toggleLockAtCursor();
        return KeyEventResult.handled;
      }
      if (e is KeyUpEvent) return KeyEventResult.ignored;
      final hw = HardwareKeyboard.instance;
      if (hw.isControlPressed || hw.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      final k = e.logicalKey;
      if (k == LogicalKeyboardKey.enter) {
        _submit();
      } else if (k == LogicalKeyboardKey.backspace ||
          k == LogicalKeyboardKey.delete) {
        hw.isShiftPressed ? _clearRow() : _back();
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        _move(-1);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        _move(1);
      } else if (e.character != null && e.character!.isNotEmpty) {
        _type(e.character!.toLowerCase());
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    } catch (err) {
      appLog.w('first-game', 'could not read a key: ${err.runtimeType}');
      return KeyEventResult.ignored;
    }
  }

  // --- hints ---

  void _openLamp() => _guard('open the hints', () {
    setState(() {
      _tray = true;
      _progress = _progress.onHint(tutorial: true);
    });
  });

  /// Buys a hint: the first is free; others cost nothing here either, but are
  /// only offered when the player has the lex for them.
  void _buyHint(HintKind kind) => _guard('buy a hint', () {
    if (_done || _target.isEmpty) return;
    final pick = pickHint(kind, _target, _guesses, _letters, taken: _picks);
    if (pick == null) {
      showToast(context, 'nothing left to hint at');
      return;
    }
    final free = _free > 0;
    if (free) {
      if (widget.practice) {
        _practiceFree--;
      } else if (appState.buyHint(
            GameHints(),
            kind,
            guesses: _guesses.length,
            free: true,
          ) ==
          null) {
        showToast(context, 'could not use the free hint');
        return;
      }
    } else if (appState.lexBalance < kind.price) {
      showToast(context, 'not enough lex');
      return;
    }
    setState(() {
      _picks.add(pick);
      _tray = false;
      _progress = _progress.onHint(tutorial: true);
    });
    showToast(
      context,
      free
          ? 'free hint used. this game pays 0 lex.'
          : 'hint used. nothing is charged in your first game.',
    );
  });

  // --- coach ---

  /// The one quiet line under the board, or empty.
  String get _line {
    final p = _progress;
    if (_done) return 'solved in ${_guesses.length}.';
    if (_invalid != null) {
      return p.invalidHint(hasFix: _fix != null) ?? 'not a word.';
    }
    if (_message.isNotEmpty) return _message;
    if (_fixTried.isNotEmpty) return 'try ${_fixTried.toLowerCase()} there.';
    final kb = _kbSeen;
    final n = [
      for (var i = 0; i < _len; i++)
        if (_input.isLetter(i)) i,
    ].length;
    return switch (p.step) {
      0 =>
        n == 0
            ? 'type any five-letter word, then press enter.'
            : n < _len
            ? '$n of $_len. keep typing.'
            : 'five letters. press enter.',
      1 => 'you have a green. colours tell you about each letter.',
      2 =>
        'not sure of a letter? press _ for a blank. blanks cannot be sent. '
            'tap a tile to move the cursor.${kb ? ' keyboard: space, ← →.' : ''}',
      3 =>
        'double tap a letter to lock it. it stays for your next guess.'
            '${kb ? ' keyboard: tap shift.' : ''}',
      4 =>
        'swipe the row to clear it, locks too. ⌫ deletes one letter and keeps '
            'locks.${kb ? ' keyboard: shift + ⌫.' : ''}',
      5 => 'stuck? tap the lamp. hints cost lex. medals earn lex.',
      _ => 'now find the word.',
    };
  }

  // --- view ---

  @override
  Widget build(BuildContext context) {
    final lang = _language;
    final title = widget.practice ? 'practice' : 'your first game';
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: lang == null
              ? Text(title, key: const ValueKey('game-title'))
              : gameTitle(
                  context,
                  language: lang,
                  mode: GameMode.classic,
                  text: title,
                ),
          actions: [
            IconButton(
              key: const ValueKey('first-close'),
              tooltip: 'close',
              onPressed: () => _guard('close', widget.onClose),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _engine == null
                  ? Center(
                      child: _failed
                          ? const Caption('the words could not be loaded.')
                          : null,
                    )
                  : _game(Theme.of(context).colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _game(ColorScheme c) => Column(
    children: [
      Expanded(child: _board(c)),
      _coach(c),
      if (!_done) ..._bottom(c),
      const SizedBox(height: 12),
    ],
  );

  Widget _board(ColorScheme c) => LayoutBuilder(
    builder: (context, box) {
      const gap = 6.0;
      final tile = min(56.0, (box.maxWidth - 32 - gap * (_len - 1)) / _len);
      Widget row(int r) => Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _len; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: tile,
                height: tile,
                child: MarkTile(
                  _guesses[r][i],
                  mark: _marks[r][i],
                  size: tile,
                  key: ValueKey('tile-$r-$i'),
                ),
              ),
            ],
          ],
        ),
      );
      final fixAt = _invalid != null ? _fix?.index : null;
      final current = Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: SwipeClear(
          onClear: _clearRow,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _len; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    SizedBox(
                      width: tile,
                      height: tile,
                      child: MarkTile(
                        _input.slot(i),
                        size: tile,
                        key: ValueKey('tile-${_guesses.length}-$i'),
                        cursor: i == _input.cursor,
                        locked: _input.isLocked(i),
                        onTap: () => _tap(i),
                      ),
                    ),
                    if (i == fixAt)
                      Positioned(
                        top: tile + 2,
                        child: Text(
                          '↑ change',
                          key: const ValueKey('fix-arrow'),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 11, color: c.primary),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
      return SingleChildScrollView(
        key: const ValueKey('boards-scroll'),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
        child: Center(
          child: Column(
            children: [
              if (_guesses.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('greens-area'),
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _done ? null : _lockGreens,
                  child: Column(
                    children: [
                      for (var r = 0; r < _guesses.length; r++) row(r),
                    ],
                  ),
                ),
              if (!_done) current,
              if (fixAt != null) const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );

  Widget _legend(ColorScheme c) {
    Widget item(String ch, Mark m, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 26, height: 26, child: MarkTile(ch, mark: m, size: 26)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: c.onSurface.withValues(alpha: dimAlpha),
          ),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        item('a', Mark.absent, 'not in the word'),
        item('r', Mark.present, 'wrong place'),
        item('e', Mark.correct, 'right place'),
      ],
    );
  }

  Widget _coach(ColorScheme c) {
    final step = _progress.step;
    final line = _line;
    final showSuggestion =
        !_done &&
        step == 1 &&
        _invalid == null &&
        _message.isEmpty &&
        _suggested.isNotEmpty;
    final canSkip =
        !_done &&
        step >= 2 &&
        step <= 5 &&
        _invalid == null &&
        _message.isEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (line.isNotEmpty)
              Text(
                line,
                key: const ValueKey('coach'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _invalid != null || _message.isNotEmpty
                      ? c.error
                      : c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            if (showSuggestion) ...[
              const SizedBox(height: 8),
              _legend(c),
              const SizedBox(height: 8),
              Text(
                'try this next. the yellow letters are moved.',
                style: TextStyle(
                  fontSize: 12,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey('suggestion'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: c.surfaceContainerHigh,
                  foregroundColor: c.onSurface,
                ),
                onPressed: () => _guard('fill the suggestion', () {
                  setState(() {
                    _input.setWord(_suggested);
                    _clearNotes();
                  });
                }),
                child: Text(
                  _suggested,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (_done)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  key: const ValueKey('first-continue'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 44),
                  ),
                  onPressed: _finish,
                  child: const Text('continue'),
                ),
              ),
            if (canSkip)
              TextButton(
                key: const ValueKey('first-next'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => _guard('skip a line', () {
                  setState(() => _progress = _progress.onNext());
                }),
                child: const Text('got it'),
              ),
            if (!_done && step >= 6 && _invalid == null)
              TextButton(
                key: const ValueKey('first-pass'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _finish,
                child: const Text('that is enough'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bottom(ColorScheme c) {
    final lamp = _progress.step >= 5 && _target.isNotEmpty;
    if (_tray) return [Flexible(child: _trayView(c))];
    return [
      if (_picks.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              for (final h in _picks)
                HintMiniRow(
                  kind: h.kind,
                  letter: h.letter,
                  pos: h.pos,
                  length: _len,
                ),
              Caption('this game pays 0 lex'),
            ],
          ),
        ),
      if (lamp)
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: HintBar(
            free: _free,
            lex: appState.lexBalance,
            onTap: _openLamp,
          ),
        ),
      LetterKeyboard(
        letters: _letters,
        onCursor: _move,
        marks: {
          for (final h in _picks)
            if (h.kind == HintKind.grey) h.letter: Mark.absent,
          ..._keyMarks,
        },
        onLetter: _type,
        onBlank: () => _type(GuessInput.blank),
        onEnter: _submit,
        onBack: _back,
      ),
    ];
  }

  Widget _trayView(ColorScheme c) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Caption(
            'a hint makes this game pay 0 lex. your streak is safe.',
          ),
          const SizedBox(height: 6),
          for (final k in HintKind.values)
            HintHoldRow(
              key: ValueKey('hint-${k.name}'),
              kind: k,
              price: k.price,
              free: _free,
              lex: appState.lexBalance,
              onBuy: () => _buyHint(k),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _tray = false),
            child: const Text('back to the keyboard'),
          ),
        ],
      ),
    ),
  );
}
