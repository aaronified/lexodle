import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';
import 'daily.dart';
import 'equations.dart';
import 'game.dart';
import 'geography.dart';
import 'home.dart' show HomePage;
import 'language_sheet.dart';
import 'keyboard.dart';
import 'main.dart';
import 'modes.dart';
import 'multi_game.dart';
import 'puzzle.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'typing_keys.dart';
import 'settings_button.dart';
import 'ui.dart';
import 'words.dart';

/// A wordle of one's own: the word, the language and the tries, in a link.
///
/// Each letter is four digits, so a word of any language reverses (a letter is
/// its code point times a prime, shifted by its place so a repeated letter
/// looks different, modulo 10,000). It is a disguise, not a secret.
/// `https://…/lexodle/#/diy?l=en&t=6&w=<digits>`. Whoever opens it plays the
/// word as practice: nothing is saved or counted.
const _mul = 7919, _shift = 2713, _offset = 4093;

/// The tries a made wordle can have, hardest first.
const diyTries = [4, 5, 6, 8, 10, 12];

/// The word lengths a made wordle can have: those the languages have lists
/// for, so that guesses can be checked.
const diyLengths = [4, 5, 6, 7, 8];

int _modInverse(int a, int m) {
  for (var x = 1; x < m; x++) {
    if (a * x % m == 1) return x;
  }
  return 1;
}

final _inverse = _modInverse(_mul, 10000);

String diyEncode(String word) => [
  for (var i = 0; i < word.runes.length; i++)
    (((word.runes.elementAt(i) * _mul + i * _shift + _offset) % 10000 + 10000) %
            10000)
        .toString()
        .padLeft(4, '0'),
].join();

/// The word of [digits], or null when they are not four digits a letter.
String? diyDecode(String digits) {
  if (digits.isEmpty || digits.length % 4 != 0) return null;
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
  final out = StringBuffer();
  for (var i = 0; i < digits.length ~/ 4; i++) {
    final n = int.parse(digits.substring(i * 4, i * 4 + 4));
    final code =
        ((((n - i * _shift - _offset) % 10000) + 10000) % 10000 * _inverse) %
        10000;
    out.writeCharCode(code);
  }
  return out.toString();
}

/// The modes a made puzzle can be in: every one with an answer someone can
/// make up. Not the mastermind, which has none (its word is not chosen).
bool diyApplies(GameMode m) => m != GameMode.mastermind;

/// The tries a made quartet or relay race can have.
const diyMultiTries = [7, 9, 10, 12, 14];

/// The lengths of a made equation.
const diyEquationLengths = equationLengths;

/// The time limits a made puzzle can have, in seconds; none is unlimited.
const diyLimits = [60, 300];

/// A made puzzle: its mode, language, words and tries (and, in lockdown, hearts),
/// its time limit (null: none) and the draw its scores are worked under.
class DiyPuzzle {
  DiyPuzzle(
    this.lang,
    String word,
    this.tries, {
    this.mode = GameMode.classic,
    List<String>? words,
    this.hearts,
    this.limit,
    Draw? draw,
  }) : words = words ?? [word],
       draw = draw ?? Draw.equal;

  final String lang;
  final GameMode mode;

  /// One word (one equation, one place), or four for a quartet or a relay race.
  final List<String> words;
  final int tries;

  /// The hearts of a lockdown puzzle; null for every other mode.
  final int? hearts;

  /// The time to win in; null for no limit.
  final Duration? limit;

  /// The draw of the answer, for the scores: equal when a link says nothing, as
  /// every link did before it had one.
  final Draw draw;

  String get word => words.first;

  String get link =>
      '$puzzleBase#${Routes.diy}?l=$lang'
      '${mode == GameMode.classic ? '' : '&m=${mode.name}'}'
      '&t=$tries${hearts == null ? '' : '&h=$hearts'}'
      '${limit == null ? '' : '&cd=${limit!.inSeconds}'}'
      '${switch (draw) {
        Draw.frequency => '&d=f',
        Draw.equal => '',
        Draw.sigmoid => '&d=s',
      }}'
      '&w=${words.map(diyEncode).join('.')}';

  /// The puzzle a link names, or null when it names none. A link without a mode
  /// is a classic one, as every link was before the other modes had one; one
  /// without a limit or a draw has no limit and equal chances.
  static DiyPuzzle? parse(Uri uri) {
    final q = uri.queryParameters;
    final lang = q['l'], t = int.tryParse(q['t'] ?? '');
    if (lang == null || !RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
    if (t == null || t < 1 || t > 20) return null;
    final modes = GameMode.values.where(
      (m) => m.name == (q['m'] ?? GameMode.classic.name),
    );
    if (modes.isEmpty || !diyApplies(modes.first)) return null;
    final mode = modes.first;
    final words = <String>[];
    for (final d in (q['w'] ?? '').split('.')) {
      final w = diyDecode(d);
      if (w == null) return null;
      words.add(w);
    }
    if (words.length != mode.boards) return null;
    if (words.any((w) => w.length != words.first.length)) return null;
    final n = words.first.length;
    switch (mode) {
      case GameMode.equations:
        if (!diyEquationLengths.contains(n)) return null;
        if (words.any((w) => equationProblem(w) != null)) return null;
      case GameMode.themed:
        if (n < 3 || n > 40) return null;
      default:
        if (!diyLengths.contains(n)) return null;
    }
    int? hearts;
    if (mode == GameMode.lockdown) {
      hearts = int.tryParse(q['h'] ?? '');
      if (hearts == null || !lockdownHearts.any((h) => h.$2 == hearts)) {
        return null;
      }
    }
    // a limit or a draw this version does not know is left out, not refused
    final cd = int.tryParse(q['cd'] ?? '');
    return DiyPuzzle(
      lang,
      words.first,
      t,
      mode: mode,
      words: words,
      hearts: hearts,
      limit: cd != null && diyLimits.contains(cd)
          ? Duration(seconds: cd)
          : null,
      draw: switch (q['d']) {
        'f' => Draw.frequency,
        's' => Draw.sigmoid,
        'e' => Draw.equal,
        _ => null,
      },
    );
  }
}

/// The boards a made puzzle can have.
enum DiyBoard {
  classic('classic', 1),
  quartet('quartet', 4),
  relay('relay', 4);

  const DiyBoard(this.label, this.boards);
  final String label;
  final int boards;
}

/// One group of pills, one selected: the flat look of the mode filter.
class _Pills<T> extends StatelessWidget {
  const _Pills({
    required this.id,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  /// The group's name: its pills are keyed `diy-<id>-<name>`.
  final String id;
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (v, label) in items)
          Semantics(
            button: true,
            selected: v == selected,
            label: '$id $label',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('diy-$id-$label'),
              onTap: () => onSelect(v),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: v == selected
                      ? c.secondaryContainer
                      : c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: v == selected ? FontWeight.bold : null,
                      color: v == selected ? c.onSecondaryContainer : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The page that makes a puzzle: pills for its board, rules, timer, word pool,
/// pool source and language, then its word (or four, or a place), its tries,
/// then the link to copy.
class DiyPage extends StatefulWidget {
  const DiyPage({super.key});

  @override
  State<DiyPage> createState() => _DiyPageState();
}

class _DiyPageState extends State<DiyPage> {
  List<Language> _langs = WordBank.loadedLanguages ?? const [];
  DiyBoard _board = DiyBoard.classic;
  bool _lockdown = false;
  int? _seconds;
  Draw _draw = Draw.sigmoid;
  bool _geography = false;
  String _lang = appState.lang;
  late List<String> _words = List.filled(_board.boards, '');
  int _active = 0;
  int _tries = 6;
  int _hearts = appState.hearts;
  String? _link;
  WordBank? _placeBank;
  WordBank? _bank;

  /// The mode the pills make.
  GameMode get _mode => _geography
      ? GameMode.themed
      : _lockdown
      ? GameMode.lockdown
      : switch (_board) {
          DiyBoard.quartet => GameMode.quartet,
          DiyBoard.relay => GameMode.relay,
          DiyBoard.classic => GameMode.classic,
        };
  bool get _places => _geography;

  @override
  void initState() {
    super.initState();
    if (_langs.isEmpty) {
      WordBank.languages().then(
        (l) {
          if (mounted) setState(() => _langs = l);
        },
        onError: (Object e) =>
            appLog.w('diy', 'could not read the languages: ${e.runtimeType}'),
      );
    }
  }

  Language? get _language {
    for (final l in _langs) {
      if (l.code == _lang) return l;
    }
    return _langs.isEmpty ? null : _langs.first;
  }

  Set<String> get _letters {
    if (_places) {
      return {for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) c};
    }
    final lang = _language;
    if (lang == null) return {};
    // the language's letters: those of the words of its lists (see the
    // keyboard of a game), from the bank when it has been read
    final bank = _bank;
    return bank == null
        ? {for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) c}
        : {for (final n in diyLengths) ...bank.letters(n)};
  }

  Future<void> _loadBank() async {
    final lang = _language;
    if (lang == null || _places) return;
    try {
      final bank = await WordBank.load(lang);
      if (mounted && lang.code == _lang) setState(() => _bank = bank);
    } catch (e) {
      appLog.w('diy', 'could not read the word list: ${e.runtimeType}');
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final l = await WordBank.languages();
      final b = await Geography.load(l.firstWhere((x) => x.code == 'en'));
      if (mounted && _geography) setState(() => _placeBank = b);
    } catch (e) {
      appLog.w('diy', 'could not read the places: ${e.runtimeType}');
    }
  }

  int get _maxLength => _places ? 20 : diyLengths.last;

  /// Applies a change of the pills: a different board or source starts the
  /// words afresh (their number, their letters and their tries differ).
  void _change({
    DiyBoard? board,
    bool? lockdown,
    bool? geography,
    String? lang,
  }) {
    final before = (_board, _geography);
    setState(() {
      _board = board ?? _board;
      _lockdown = lockdown ?? _lockdown;
      _geography = geography ?? _geography;
      if (lang != null && lang != _lang) {
        _lang = lang;
        _bank = null;
        for (var i = 0; i < _words.length; i++) {
          _words[i] = '';
        }
      }
      if (before != (_board, _geography)) {
        _words = List.filled(_places ? 1 : _board.boards, '');
        _active = 0;
        _tries = switch (_board) {
          DiyBoard.quartet => 9,
          DiyBoard.relay => 10,
          DiyBoard.classic => 6,
        };
        _bank = null;
      }
      _link = null;
    });
    if (_geography && _placeBank == null) _loadPlaces();
    if (!_geography) _loadBank();
  }

  void _pickBoard(DiyBoard b) {
    if (b == _board) return;
    if (_lockdown && b != DiyBoard.classic) {
      _toast('lockdown is for one board: classic rules it is');
    } else if (_geography && b != DiyBoard.classic) {
      _toast('geography is one board, classic rules');
    }
    _change(
      board: b,
      lockdown: b == DiyBoard.classic ? null : false,
      geography: b == DiyBoard.classic ? null : false,
    );
  }

  void _pickRules(bool lockdown) {
    if (lockdown == _lockdown) return;
    if (lockdown && _board != DiyBoard.classic) {
      _toast(
        _board == DiyBoard.quartet
            ? 'a quartet cannot be locked down'
            : 'a relay race cannot be locked down',
      );
      return;
    }
    if (lockdown && _geography) _toast('geography is one board, classic rules');
    _change(lockdown: lockdown, geography: lockdown ? false : null);
  }

  void _pickSource(bool geography) {
    if (geography == _geography) return;
    if (geography) {
      if (_lang != 'en') {
        _toast('geography is only in english');
        return;
      }
      if (_board != DiyBoard.classic || _lockdown) {
        _toast('geography is one board, classic rules');
        return;
      }
    }
    _change(geography: geography);
  }

  void _toast(String text) {
    try {
      showToast(context, text);
    } catch (e) {
      appLog.w('diy', 'could not show a toast: ${e.runtimeType}');
    }
  }

  Future<void> _pickLanguage() async {
    try {
      final code = await showLanguageSheet(
        context,
        langs: _langs,
        current: _lang,
      );
      if (!mounted || code == null || code == _lang) return;
      if (_geography && code != 'en') {
        _toast('geography is only in english');
        _change(lang: code, geography: false);
      } else {
        _change(lang: code);
      }
    } catch (e) {
      appLog.w('diy', 'could not pick the language: ${e.runtimeType}');
    }
  }

  void _type(String ch) {
    final w = _words[_active];
    if (w.length >= _maxLength) return;
    setState(() {
      _words[_active] = w + ch;
      _link = null;
    });
  }

  /// Shift and backspace (or a swipe) clear the word being made.
  void _clearWord() {
    if (_words[_active].isEmpty) return;
    setState(() {
      _words[_active] = '';
      _link = null;
    });
  }

  late final _keys = TypingKeys(
    submit: _make,
    back: _back,
    clearRow: _clearWord,
    // a word here is made by adding to its end: there is no cursor to move
    move: (_) {},
    type: _type,
  );

  void _back() {
    final w = _words[_active];
    if (w.isEmpty) return;
    setState(() {
      _words[_active] = w.substring(0, w.length - 1);
      _link = null;
    });
  }

  /// What is wrong with word [i], in a few words, or null when it is fine.
  String? _problem(int i) {
    final w = _words[i];
    if (w.isEmpty) return null;
    if (_places) {
      final b = _placeBank;
      if (b != null && w.length >= 3 && !b.valid.contains(w)) {
        return 'not a place of the list';
      }
      return null;
    }
    if (!diyLengths.contains(w.length)) return 'four to eight letters';
    return null;
  }

  bool get _ready {
    final n = _words.first.length;
    for (var i = 0; i < _words.length; i++) {
      if (_words[i].isEmpty || _words[i].length != n) return false;
      if (_problem(i) != null) return false;
    }
    if (_places) return _placeBank != null && n >= 3;
    return true;
  }

  void _make() {
    if (!_ready) return;
    try {
      setState(
        () => _link = DiyPuzzle(
          _lang,
          _words.first,
          _tries,
          mode: _mode,
          words: List.of(_words),
          hearts: _mode == GameMode.lockdown ? _hearts : null,
          limit: _seconds == null ? null : Duration(seconds: _seconds!),
          draw: _draw,
        ).link,
      );
    } catch (e) {
      appLog.w('diy', 'could not make the link: ${e.runtimeType}');
    }
  }

  /// What a made puzzle of this mode is called.
  String get _noun => _places
      ? 'place'
      : _board.boards > 1
      ? 'words'
      : 'word';

  List<(int, String, String)> get _triesItems {
    if (_board != DiyBoard.classic) {
      return [for (final t in diyMultiTries) (t, '$t tries', '')];
    }
    return [
      for (final t in diyTries)
        (
          t,
          '$t tries',
          switch (t) {
            4 => 'hard',
            5 => '',
            6 => 'normal',
            8 => 'easy',
            10 => 'easier',
            _ => 'easiest',
          },
        ),
    ];
  }

  Widget _tiles(ColorScheme c, int b) {
    final w = _words[b];
    final shown = w.length < 5 ? 5 : (w.length + 1).clamp(5, _maxLength);
    final on = b == _active;
    return InkWell(
      key: ValueKey('diy-word-$b'),
      onTap: () => setState(() => _active = b),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < shown; i++)
              Container(
                key: ValueKey(b == 0 ? 'diy-tile-$i' : 'diy-tile-$b-$i'),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: on && i == w.length
                        ? c.primary
                        : i < w.length
                        ? c.onSurface
                        : c.onSurface.withValues(alpha: on ? .5 : .25),
                    width: on && i == w.length ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  i < w.length ? faceOf(w[i]) : '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _group(String caption, Widget pills) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Caption(caption), const SizedBox(height: 8), pills],
  );

  Widget _languagePill(ColorScheme c, Language? lang) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      key: const ValueKey('diy-language'),
      borderRadius: BorderRadius.circular(3),
      onTap: lang == null ? null : _pickLanguage,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lang != null) FlagBadge(lang.flag, size: 16),
            const SizedBox(width: 6),
            Text(_lang, style: const TextStyle(fontSize: 12)),
            Icon(Icons.arrow_drop_down, size: 16, color: c.onSurfaceVariant),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final lang = _language;
    if (_bank == null && lang != null && !_places) _loadBank();
    final problem = _problem(_active);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _keys.handle(e),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('make your own'),
          actions: [const SettingsButton()],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 16),
                  children: [
                    _group(
                      'board',
                      _Pills<DiyBoard>(
                        id: 'board',
                        items: [for (final b in DiyBoard.values) (b, b.label)],
                        selected: _board,
                        onSelect: _pickBoard,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _group(
                      'rules',
                      _Pills<bool>(
                        id: 'rules',
                        items: const [(true, 'lockdown'), (false, 'classic')],
                        selected: _lockdown,
                        onSelect: _pickRules,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _group(
                      'timer',
                      _Pills<int?>(
                        id: 'timer',
                        items: const [
                          (60, '1 min'),
                          (300, '5 min'),
                          (null, 'unlimited'),
                        ],
                        selected: _seconds,
                        onSelect: (s) => setState(() {
                          _seconds = s;
                          _link = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _group(
                      'word pool',
                      _Pills<Draw>(
                        id: 'draw',
                        items: const [
                          (Draw.sigmoid, 'sigmoid'),
                          (Draw.frequency, 'frequency'),
                          (Draw.equal, 'equal'),
                        ],
                        selected: _draw,
                        onSelect: (d) => setState(() {
                          _draw = d;
                          _link = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _group(
                      'pool source',
                      _Pills<bool>(
                        id: 'source',
                        items: const [(false, 'classic'), (true, 'geography')],
                        selected: _geography,
                        onSelect: _pickSource,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _group('language', _languagePill(c, lang)),
                    const SizedBox(height: 18),
                    Caption('your $_noun'),
                    const SizedBox(height: 8),
                    for (var b = 0; b < _words.length; b++) _tiles(c, b),
                    const SizedBox(height: 8),
                    Text(
                      problem ??
                          (_places
                              ? 'a place of the list, in english, with no spaces.'
                              : _board.boards > 1
                              ? 'four words of one length, four to eight letters, '
                                    'in this language\'s letters. tap a word to '
                                    'type in it. they do not have to be in the '
                                    'word list.'
                              : 'type any word, four to eight letters, in this '
                                    'language\'s letters. it does not have to be '
                                    'in the word list.'),
                      key: const ValueKey('diy-note'),
                      style: TextStyle(
                        fontSize: 11,
                        color: problem == null ? dim : c.error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_mode == GameMode.lockdown) ...[
                      const Caption('hearts'),
                      const SizedBox(height: 10),
                      StepperChoice<int>(
                        key: const ValueKey('diy-hearts'),
                        semanticLabel: 'hearts',
                        items: [
                          for (final (name, n) in lockdownHearts)
                            (n, '$n ${n == 1 ? 'heart' : 'hearts'}', name),
                        ],
                        selected: _hearts,
                        onChanged: (h) => setState(() {
                          _hearts = h;
                          _link = null;
                        }),
                      ),
                    ] else ...[
                      const Caption('tries'),
                      const SizedBox(height: 10),
                      StepperChoice<int>(
                        key: const ValueKey('diy-tries'),
                        semanticLabel: 'tries',
                        items: _triesItems,
                        selected: _triesItems.any((i) => i.$1 == _tries)
                            ? _tries
                            : _triesItems.first.$1,
                        onChanged: (t) => setState(() {
                          _tries = t;
                          _link = null;
                        }),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      key: const ValueKey('diy-make'),
                      onPressed: _ready ? _make : null,
                      child: const Text('create the link'),
                    ),
                    if (_link != null) ...[
                      const SizedBox(height: 18),
                      const Caption('the link'),
                      const SizedBox(height: 8),
                      Container(
                        key: const ValueKey('diy-link'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.surfaceContainerHighest,
                          border: Border.fromBorderSide(hairline(c)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: SelectableText(
                          _link!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const ValueKey('diy-copy'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: _link!),
                            );
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('link copied')),
                              );
                          } catch (e) {
                            appLog.w(
                              'diy',
                              'could not copy the link: ${e.runtimeType}',
                            );
                          }
                        },
                        child: const Text('copy'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'whoever opens it plays your $_noun as practice: nothing '
                        'is saved or counted. it is only lightly disguised, not '
                        'secret: each character is four digits.',
                        style: TextStyle(fontSize: 11, color: dim),
                      ),
                    ],
                  ],
                ),
              ),
              LetterKeyboard(
                letters: _letters,
                onLetter: _type,
                onEnter: _make,
                onBack: _back,
                enterLabel: 'create',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays a made puzzle opened by a link, as practice, in its mode.
class DiyGate extends StatefulWidget {
  const DiyGate({super.key, required this.puzzle});
  final DiyPuzzle puzzle;

  @override
  State<DiyGate> createState() => _DiyGateState();
}

class _DiyGateState extends State<DiyGate> {
  late final Future<WordBank?> _bank = _load();

  Future<WordBank?> _load() async {
    final langs = await WordBank.languages();
    final found = langs.where((l) => l.code == widget.puzzle.lang);
    if (found.isEmpty) return null;
    final p = widget.puzzle;
    switch (p.mode) {
      case GameMode.equations:
        return Equations.load(found.first);
      case GameMode.themed:
        final places = await Geography.load(found.first);
        return places.valid.contains(p.word) ? places : null;
      default:
        var bank = await WordBank.load(found.first);
        for (final w in p.words) {
          bank = bank.withWord(w);
        }
        return bank;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WordBank?>(
      future: _bank,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(actions: [const SettingsButton()]),
            body: const Center(child: Caption('loading…')),
          );
        }
        final bank = snap.data;
        if (bank == null) return const HomePage();
        final p = widget.puzzle;
        if (p.mode.multi) {
          return MultiGamePage(
            bank: bank,
            practice: true,
            daily: DailyMulti(
              '',
              p.mode,
              p.words,
              length: p.word.length,
              tries: p.tries,
            ),
            limit: p.limit,
            draw: p.draw,
          );
        }
        return GamePage(
          bank: bank,
          mode: p.mode,
          practice: true,
          chosen: true,
          hearts: p.hearts,
          limit: p.limit,
          draw: p.draw,
          daily: Daily('', p.word, length: p.word.length, tries: p.tries),
        );
      },
    );
  }
}
