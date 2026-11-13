import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../blind_pencil.dart';
import '../equations.dart';
import '../game_header.dart';
import '../geography.dart';
import '../guess_input.dart';
import '../hearts.dart';
import '../keyboard.dart';
import '../logic.dart';
import '../main.dart' show appState;
import '../modes.dart';
import '../ui.dart';
import '../words.dart';
import 'first_game_engine.dart';
import 'first_game_page.dart';
import 'lesson_boards.dart';
import 'lesson_game.dart';

/// What a lesson plays on: the language (for the flag and the keys), the keys,
/// and the engine over the words (the equations, or the places, of the mode).
class LessonBank {
  const LessonBank(this.language, this.letters, this.engine);
  final Language language;
  final Set<String> letters;
  final FirstGameEngine engine;
}

/// Loads what the lesson of [mode] plays on: five-letter words of the chosen
/// language (English when it has none), the equations of eight tiles, or the
/// five-letter places (English only).
Future<LessonBank> loadLessonBank(GameMode mode) async {
  final langs = await WordBank.languages();
  final en = langs.firstWhere((l) => l.code == 'en');
  var pick = en;
  if (mode != GameMode.themed) {
    for (final l in langs) {
      if (l.code == appState.lang &&
          (mode.isEquations || l.lengths.contains(5))) {
        pick = l;
      }
    }
  }
  final WordBank bank;
  final int length;
  if (mode.isEquations) {
    bank = await Equations.load(pick);
    length = 8;
  } else if (mode == GameMode.themed) {
    bank = await Geography.load(en);
    length = 5;
  } else {
    bank = await WordBank.load(pick);
    length = 5;
  }
  var words = bank.guessable(length);
  if (words.isEmpty) throw StateError('no words');
  var pool = words.length;
  if (mode.isEquations) {
    // the list is in order of its numbers: spread the draw over all of it
    final n = words.length;
    if (n % 7919 != 0) {
      words = [for (var i = 0; i < n; i++) words[(i * 7919) % n]];
    }
    pool = n;
  }
  return LessonBank(
    pick,
    bank.letters(length),
    FirstGameEngine(words, poolSize: pool),
  );
}

/// A mode lesson: a short guided game of [mode] that explains its rules and its
/// screen, one quiet line at a time. It is about how to play the mode (the
/// Learn drills are about playing better). It looks like the real game screen
/// of the mode, with no guess count and no tries limit. Finishing it marks the
/// mode taught and calls [onDone] once; the X calls [onDone] once too, without
/// marking. Nothing else is saved.
class ModeLessonPage extends StatefulWidget {
  const ModeLessonPage({super.key, required this.mode, required this.onDone});

  final GameMode mode;
  final VoidCallback onDone;

  @override
  State<ModeLessonPage> createState() => _ModeLessonPageState();
}

class _ModeLessonPageState extends State<ModeLessonPage> {
  LessonBank? _bank;
  LessonGame? _game;
  bool _failed = false;
  bool _ended = false;
  bool _kbSeen = false;

  GuessInput? _input;
  final _focus = FocusNode();
  final _shift = ShiftTap();

  String _message = '';
  String? _invalid;
  LetterFix? _fix;
  String _fixTried = '';
  bool _fixLearned = false;

  GameMode get _mode => widget.mode;

  @override
  void initState() {
    super.initState();
    if (_mode != GameMode.classic) _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bank = await loadLessonBank(_mode);
      if (!mounted) return;
      final game = LessonGame(_mode, bank.engine);
      setState(() {
        _bank = bank;
        _game = game;
        _input = GuessInput(game.length);
      });
    } catch (e) {
      appLog.w('lesson', 'could not load the words: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _guard(String what, void Function() f) {
    try {
      f();
    } catch (e) {
      appLog.w('lesson', 'could not $what: ${e.runtimeType}');
    }
  }

  /// Ends the lesson once: [taught] marks the mode, then [ModeLessonPage.onDone].
  void _end({required bool taught}) {
    if (_ended) return;
    _ended = true;
    if (taught) {
      try {
        appState.markTaught(_mode);
      } catch (e) {
        appLog.w('lesson', 'could not mark it taught: ${e.runtimeType}');
      }
    }
    try {
      widget.onDone();
    } catch (e) {
      appLog.w('lesson', 'could not finish: ${e.runtimeType}');
    }
  }

  void _clearNotes() {
    _message = '';
    _invalid = null;
    _fix = null;
    _fixTried = '';
  }

  bool get _usesFix => _mode == GameMode.blind || _mode == GameMode.mastermind;

  // --- input ---

  void _type(String ch) => _guard('type', () {
    final g = _game, input = _input;
    if (g == null || input == null || g.done) return;
    setState(() {
      _clearNotes();
      input.type(
        _mode.isEquations && ch != GuessInput.blank
            ? typedEquationChar(ch)
            : ch,
        _bank!.letters,
      );
    });
  });

  void _back() => _guard('delete', () {
    final g = _game, input = _input;
    if (g == null || input == null || g.done) return;
    setState(() {
      _clearNotes();
      input.back();
    });
  });

  void _clearRow() => _guard('clear the row', () {
    final g = _game, input = _input;
    if (g == null || input == null || g.done) return;
    setState(() {
      _clearNotes();
      input.clearTyped();
    });
  });

  void _move(int by) => _guard('move the cursor', () {
    final input = _input;
    if (input == null || (_game?.done ?? true)) return;
    setState(() => input.move(by));
  });

  void _tap(int i) => _guard('tap a tile', () {
    final input = _input;
    if (input == null || (_game?.done ?? true)) return;
    setState(() {
      final fixAt = _fix?.index;
      final fixTapped = fixAt != null && fixAt == i && _invalid != null;
      final again = input.tap(i);
      if (fixTapped && !again) {
        // the arrow asks for another letter there: empty it, say which
        _fixLearned = true;
        input.select(i);
        input.back();
        _fixTried = _fix!.letter;
        _invalid = null;
        _fix = null;
      }
    });
  });

  void _toggleLockAtCursor() => _guard('lock a letter', () {
    final input = _input;
    if (input == null || (_game?.done ?? true)) return;
    setState(() => input.toggleLock(input.cursor));
  });

  /// A double tap on the guesses of board [b] locks its greens.
  void _lockGreens(int b) => _guard('lock the greens', () {
    final g = _game, input = _input;
    if (g == null || input == null || g.done) return;
    final greens = g.greensOf(b);
    if (greens.isEmpty) return;
    setState(() => input.lockAll(greens));
  });

  void _pencil(int r, int i) => _guard('pencil a letter', () {
    final g = _game;
    if (g == null || g.done) return;
    final row = g.boards[0][r];
    final deduced = BlindPencil.deduce(g.blindRows, _bank!.letters);
    setState(() {
      final why = g.pencil.tap(row.word[i], i, g.blindRows, deduced);
      _message = why == null ? '' : '$why.';
    });
  });

  void _submit() => _guard('send the guess', () {
    final g = _game, input = _input, bank = _bank;
    if (g == null || input == null || bank == null || g.done) return;
    if (!input.complete) {
      setState(() {
        _message = input.hasBlank
            ? 'a blank cannot be sent. fill it first.'
            : '${g.length == 8 ? 'eight tiles' : 'five letters'} first.';
      });
      return;
    }
    final word = input.word;
    if (g.boards.any((b) => b.any((r) => r.word == word))) {
      setState(() => _message = 'already guessed.');
      return;
    }
    if (!g.isValid(word)) {
      setState(() {
        g.invalid();
        _invalid = word;
        _fix = _usesFix ? bank.engine.oneLetterFix(word) : null;
        _fixTried = '';
        _message = '';
      });
      return;
    }
    setState(() {
      _clearNotes();
      g.guess(word);
      if (g.done) return;
      // the typed letters go, the locks stay (a lockdown's are the game's)
      input.next();
      if (_mode == GameMode.lockdown) {
        input.lockFixed([for (final e in g.greens.entries) (e.key, e.value)]);
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
      appLog.w('lesson', 'could not read a key: ${err.runtimeType}');
      return KeyEventResult.ignored;
    }
  }

  // --- the coach ---

  /// The one quiet line under the board.
  String get _line {
    final g = _game!;
    if (_message.isNotEmpty) return _message;
    if (_invalid != null) {
      return switch (_mode) {
        GameMode.equations => g.whyNot(_invalid!) ?? 'not a true equation.',
        GameMode.lockdown => 'not a word. you lose a heart.',
        GameMode.themed => 'not a place name.',
        _ =>
          'not a word.'
              '${_fix != null && !_fixLearned ? ' tap the arrow to change a letter.' : ''}',
      };
    }
    if (_fixTried.isNotEmpty) return 'try ${_fixTried.toLowerCase()} there.';
    final n = g.made;
    if (g.done) {
      return switch (_mode) {
        GameMode.mastermind => 'cornered.',
        GameMode.quartet => 'all four solved.',
        GameMode.relay => 'all four words solved.',
        _ => 'solved.',
      };
    }
    return switch (_mode) {
      GameMode.quartet =>
        n == 0
            ? 'four boards. one guess goes to all four.'
            : n < 2
            ? 'each board answers on its own.'
            : 'solve a board and it is done.',
      GameMode.relay =>
        g.active == 0 && n == 0
            ? 'four words, one after another. solve this one to open the next.'
            : g.active == 0
            ? 'greens you lock carry to the next word.'
            : 'next word. your locks stay.',
      GameMode.lockdown =>
        n == 0
            ? 'greens lock by themselves. a bad word costs a heart.'
            : 'your greens are locked. fill in the rest.',
      GameMode.blind =>
        n == 0
            ? 'no colours. you see counts: right place, wrong place.'
            : 'tap a letter to pencil a colour.',
      GameMode.equations =>
        n == 0
            ? 'find the equation. eight tiles, one = sign. it must be true.'
            : 'green is right. yellow is elsewhere.',
      GameMode.mastermind =>
        n == 0
            ? 'the word dodges you. it settles only when cornered.'
            : 'the number shows the words still possible.',
      GameMode.themed => 'place names only. in english.',
      _ => '',
    };
  }

  /// The small line over the coach: what is solved, which word, how many words
  /// are still possible.
  String? get _status {
    final g = _game!;
    return switch (_mode) {
      GameMode.quartet => '${g.solved.where((s) => s).length} of 4 solved',
      GameMode.relay => 'word ${g.done ? 4 : g.active + 1} of 4',
      GameMode.mastermind => '${g.candidates.length} possible words',
      _ => null,
    };
  }

  // --- view ---

  @override
  Widget build(BuildContext context) {
    if (_mode == GameMode.classic) {
      // classic has no screen of its own: its lesson is the first game again
      return FirstGamePage(
        practice: true,
        onDone: () => _end(taught: true),
        onClose: () => _end(taught: false),
      );
    }
    final lang = _bank?.language;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: lang == null
              ? const Text('lesson', key: ValueKey('game-title'))
              : gameTitle(context, language: lang, mode: _mode, text: 'lesson'),
          actions: [
            IconButton(
              key: const ValueKey('lesson-close'),
              tooltip: 'close',
              onPressed: () => _guard('close', () => _end(taught: false)),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _game == null
                  ? Center(
                      child: _failed
                          ? const Caption('the words could not be loaded.')
                          : null,
                    )
                  : _lesson(Theme.of(context).colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lesson(ColorScheme c) {
    final g = _game!;
    return Column(
      children: [
        Expanded(child: _board(g)),
        _statusRow(g),
        _coach(c, g),
        if (!g.done) _keyboard(g),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _board(LessonGame g) {
    final input = _input!;
    if (_mode.multi) {
      return LessonMultiBoard(
        game: g,
        input: input,
        onSelect: _tap,
        onClear: _clearRow,
        onLockGreens: _lockGreens,
      );
    }
    final blind = _mode == GameMode.blind;
    return LessonBoard(
      game: g,
      input: input,
      onSelect: _tap,
      onClear: _clearRow,
      onLockGreens: () => _lockGreens(0),
      onPencil: blind ? _pencil : null,
      fixAt: _invalid != null ? _fix?.index : null,
      deduced: blind
          ? BlindPencil.deduce(g.blindRows, _bank!.letters)
          : const {},
    );
  }

  Widget _statusRow(LessonGame g) {
    if (_mode == GameMode.lockdown) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: HeartsRow(total: g.heartsTotal, left: g.hearts),
      );
    }
    final s = _status;
    if (s == null) return const SizedBox(height: 24);
    return SizedBox(
      height: 24,
      child: Center(child: Caption(s, key: const ValueKey('lesson-status'))),
    );
  }

  Widget _coach(ColorScheme c, LessonGame g) {
    final line = _line;
    final bad = _invalid != null || _message.isNotEmpty;
    final gotIt = g.done || g.made >= 2;
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
                  color: bad
                      ? c.error
                      : c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            if (gotIt)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: g.done
                    ? FilledButton(
                        key: const ValueKey('lesson-got-it'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(160, 44),
                        ),
                        onPressed: () =>
                            _guard('finish', () => _end(taught: true)),
                        child: const Text('got it'),
                      )
                    : TextButton(
                        key: const ValueKey('lesson-got-it'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () =>
                            _guard('finish', () => _end(taught: true)),
                        child: const Text('got it'),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _keyboard(LessonGame g) {
    final bank = _bank!;
    final Map<String, Mark> marks;
    switch (_mode) {
      case GameMode.relay:
        marks = g.keyMarks(g.active);
      case GameMode.blind:
        marks = g.pencil.keyboard(
          BlindPencil.deduce(g.blindRows, bank.letters),
          bank.letters,
        );
      case GameMode.equations:
        marks = g.keyMarks(0);
      default:
        marks = _mode.multi ? const {} : g.keyMarks(0);
    }
    return LetterKeyboard(
      letters: bank.letters,
      numberPad: _mode.isEquations,
      onCursor: _move,
      marks: marks,
      quadMarks: _mode == GameMode.quartet ? g.quadMarks() : const {},
      onLetter: _type,
      onBlank: () => _type(GuessInput.blank),
      onEnter: _submit,
      onBack: _back,
    );
  }
}
