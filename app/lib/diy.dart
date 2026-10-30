import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'daily.dart';
import 'home.dart' show HomePage, LanguagePopup;
import 'keyboard.dart';
import 'main.dart';
import 'puzzle.dart';
import 'routes.dart';
import 'stepper_choice.dart';
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

/// A made wordle.
class DiyPuzzle {
  const DiyPuzzle(this.lang, this.word, this.tries);
  final String lang;
  final String word;
  final int tries;

  String get link =>
      '$puzzleBase#${Routes.diy}?l=$lang&t=$tries&w=${diyEncode(word)}';

  /// The wordle a link names, or null when it names none.
  static DiyPuzzle? parse(Uri uri) {
    final q = uri.queryParameters;
    final lang = q['l'], t = int.tryParse(q['t'] ?? '');
    if (lang == null || !RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
    if (t == null || t < 1 || t > 20) return null;
    final word = diyDecode(q['w'] ?? '');
    if (word == null || !diyLengths.contains(word.length)) return null;
    return DiyPuzzle(lang, word, t);
  }
}

/// The screen where a wordle is made: its language, its word and its tries,
/// then the link to copy.
class DiyPage extends StatefulWidget {
  const DiyPage({super.key});

  @override
  State<DiyPage> createState() => _DiyPageState();
}

class _DiyPageState extends State<DiyPage> {
  List<Language> _langs = WordBank.loadedLanguages ?? const [];
  late String _lang = appState.lang;
  String _word = '';
  int _tries = 6;
  String? _link;

  @override
  void initState() {
    super.initState();
    if (_langs.isEmpty) {
      WordBank.languages().then((l) {
        if (mounted) setState(() => _langs = l);
      });
    }
  }

  Language? get _language {
    for (final l in _langs) {
      if (l.code == _lang) return l;
    }
    return _langs.isEmpty ? null : _langs.first;
  }

  Set<String> get _letters {
    final alphabet = <String>{};
    final lang = _language;
    if (lang == null) return alphabet;
    // the language's letters: those of the words of its lists (see the
    // keyboard of a game), from the bank when it has been read
    final bank = _bank;
    return bank == null
        ? {for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) c}
        : {for (final n in diyLengths) ...bank.letters(n)};
  }

  WordBank? _bank;
  Future<void> _loadBank() async {
    final lang = _language;
    if (lang == null) return;
    final bank = await WordBank.load(lang);
    if (mounted && lang.code == _lang) setState(() => _bank = bank);
  }

  void _type(String ch) {
    if (_word.length >= diyLengths.last) return;
    setState(() {
      _word += ch;
      _link = null;
    });
  }

  void _back() {
    if (_word.isEmpty) return;
    setState(() {
      _word = _word.substring(0, _word.length - 1);
      _link = null;
    });
  }

  bool get _ready => diyLengths.contains(_word.length);

  void _make() {
    if (!_ready) return;
    setState(() => _link = DiyPuzzle(_lang, _word, _tries).link);
  }

  Future<void> _pickLanguage() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => LanguagePopup(langs: _langs, current: _lang),
    );
    if (code == null || code == _lang) return;
    setState(() {
      _lang = code;
      _word = '';
      _link = null;
      _bank = null;
    });
    _loadBank();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final lang = _language;
    if (_bank == null && lang != null) _loadBank();
    final shown = _word.length < 5 ? 5 : (_word.length + 1).clamp(5, 8);
    return Scaffold(
      appBar: AppBar(title: const Text('make your own')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(19, 8, 19, 16),
                children: [
                  const Caption('language'),
                  const SizedBox(height: 8),
                  InkWell(
                    key: const ValueKey('diy-language'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: lang == null ? null : _pickLanguage,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          if (lang != null) FlagBadge(lang.flag),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang?.name ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: c.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Caption('your word'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var i = 0; i < shown; i++)
                        Container(
                          key: ValueKey('diy-tile-$i'),
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: i == _word.length
                                  ? c.primary
                                  : i < _word.length
                                  ? c.onSurface
                                  : c.onSurface.withValues(alpha: .5),
                              width: i == _word.length ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            i < _word.length ? _word[i] : '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'type any word, four to eight letters, in this language\'s '
                    'letters. it does not have to be in the word list.',
                    style: TextStyle(fontSize: 11, color: dim),
                  ),
                  const SizedBox(height: 18),
                  const Caption('tries'),
                  const SizedBox(height: 10),
                  StepperChoice<int>(
                    key: const ValueKey('diy-tries'),
                    semanticLabel: 'tries',
                    items: [
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
                    ],
                    selected: _tries,
                    onChanged: (t) => setState(() {
                      _tries = t;
                      _link = null;
                    }),
                  ),
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
                        border: Border.all(color: c.outlineVariant),
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
                        await Clipboard.setData(ClipboardData(text: _link!));
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('link copied')),
                          );
                      },
                      child: const Text('copy'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'whoever opens it plays your word as practice: nothing '
                      'is saved or counted. the word is only lightly disguised, '
                      'not secret: each letter is four digits.',
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
    );
  }
}

/// Plays a made wordle opened by a link, as practice.
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
    final bank = await WordBank.load(found.first);
    return bank.withWord(widget.puzzle.word);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WordBank?>(
      future: _bank,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Caption('loading…')),
          );
        }
        final bank = snap.data;
        if (bank == null) return const HomePage();
        final p = widget.puzzle;
        return GamePage(
          bank: bank,
          practice: true,
          daily: Daily('', p.word, length: p.word.length, tries: p.tries),
        );
      },
    );
  }
}
