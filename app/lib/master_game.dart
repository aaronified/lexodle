import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analysis_worker.dart';
import 'app_log.dart';
import 'blind_pencil.dart';
import 'calc_dialog.dart';
import 'logic.dart';
import 'modes.dart';
import 'review_plots.dart' show Outcome;
import 'words.dart';

/// The kinds of game how-to-master is played in.
enum MasterKind { classic, blind, mastermind }

/// One guess of the game: the word, the words that fitted before it and after
/// it, and the marks it got (counts only, greens first, in a blind game).
class MasterRow {
  const MasterRow(this.word, this.marks, this.before, this.after);
  final String word;
  final List<Mark> marks;
  final int before;
  final int after;

  int get green => marks.where((m) => m == Mark.correct).length;
  int get yellow => marks.where((m) => m == Mark.present).length;
}

/// The game of how to master: the hidden word (or, in mastermind, an opponent
/// that answers as a random word that still fits would), the guesses with their
/// replies, the words that still fit, and everything learn explains at each
/// step: the best guesses for skill and the bets for luck, the skill and luck of
/// the guess just made, the plot of any guess, and, in a blind game, the
/// colouring logic of the pencil and the chance of each key.
///
/// Nothing here is scored or kept: learn is not.
class MasterGame extends ChangeNotifier {
  MasterGame({
    required this.bank,
    required this.kind,
    required this.length,
    this.draw = Draw.sigmoid,
    int? seed,
    String? answer,
    this.analyse = true,
  }) : _rng = Random(seed) {
    _begin(answer);
  }

  final WordBank bank;
  final MasterKind kind;
  final int length;
  final Draw draw;
  final Random _rng;

  /// Whether the position is analysed (the best guesses, H*). A test that does
  /// not need them turns it off: the whole word list is slow to score there.
  final bool analyse;

  bool get blind => kind == MasterKind.blind;
  bool get adversary => kind == MasterKind.mastermind;

  /// Every word the answer can be, the likeliest first.
  List<String> get words => bank.answers(length);

  /// Every word accepted as a guess.
  List<String> get guessable => bank.guessable(length);

  /// How likely each word is, or null when they all are equally.
  Map<String, int>? get weights => bank.law(length, draw);

  /// The hidden word (null in mastermind, which has none).
  String? answer;

  final rows = <MasterRow>[];

  /// The words that fitted before each guess (see [rows]).
  final pools = <List<String>>[];

  /// The words that still fit.
  List<String> pool = const [];

  /// The row being typed.
  String typed = '';

  /// The skill and luck of the guess just made.
  GuessMetrics? last;

  /// The pencil of a blind game, and what the counts settle for it.
  late BlindPencil pencil;
  Map<String, Mark> deduced = const {};
  Map<String, Mark> forced = const {};

  /// The analysis of the words that fit now (the best guesses for skill, the
  /// riskiest, H*); null while it is worked out.
  Landscape? landscape;
  bool analysing = false;
  int _serial = 0;

  bool get done => rows.isNotEmpty && rows.last.green == length;

  void _begin(String? fixed) {
    rows.clear();
    pools.clear();
    typed = '';
    last = null;
    pool = List.of(words);
    pencil = BlindPencil(length);
    deduced = const {};
    forced = const {};
    landscape = null;
    answer = adversary ? null : (fixed ?? _drawWord());
    _refreshPencil();
    _analyse();
  }

  /// A new game: a new word to find.
  void restart() {
    _begin(null);
    notifyListeners();
  }

  String _drawWord() {
    final w = weights;
    final list = words;
    if (w == null) return list[_rng.nextInt(list.length)];
    var total = 0;
    for (final x in list) {
      total += max(w[x] ?? 1, 1);
    }
    var at = _rng.nextInt(total);
    for (final x in list) {
      at -= max(w[x] ?? 1, 1);
      if (at < 0) return x;
    }
    return list.first;
  }

  // ---- typing ----

  void type(String ch) {
    if (done || typed.length >= length) return;
    typed += ch;
    notifyListeners();
  }

  void back() {
    if (typed.isEmpty) return;
    typed = typed.substring(0, typed.length - 1);
    notifyListeners();
  }

  /// Puts a whole word in the row (the "use" of a candidate).
  void use(String word) {
    if (done) return;
    typed = word;
    notifyListeners();
  }

  /// Plays the typed word. Returns why it was not played (not a whole word, not
  /// in the list), or null.
  Future<String?> submit() async {
    if (done) return null;
    if (typed.length < length) return 'a word has $length letters';
    final word = typed;
    if (!guessable.contains(word)) return 'not in the word list';
    final before = pool;
    final marks = adversary
        ? mastermindReply(before, word, _rng)
        : evaluate(answer!, word, blind: blind);
    final shown = blind ? _counted(marks) : marks;
    final after = filterEligible(before, word, shown, blind: blind);
    // skill is measured against the best guess of the position it was made in
    Landscape? land = landscape;
    try {
      if (analyse) {
        land ??= await analyseOffThread(
          before,
          guessable,
          k: 2,
          weights: weights,
          blind: blind,
        );
      }
    } catch (e) {
      appLog.w('learn', 'could not score a guess: ${e.runtimeType}');
    }
    var metrics = scoreGuess(
      before,
      word,
      after.length,
      solved: marks.every((m) => m == Mark.correct),
      weights: weights,
      afterWords: after,
      blind: blind,
      best: land?.bestGain,
    );
    if (land != null) metrics = metrics.withLandscape(land);
    pools.add(before);
    rows.add(MasterRow(word, shown, before.length, after.length));
    pool = after;
    typed = '';
    last = metrics;
    if (rows.last.green == length && adversary) answer = word;
    _refreshPencil();
    landscape = null;
    notifyListeners();
    _analyse();
    return null;
  }

  /// The marks of a blind guess are only counts: greens first, then yellows.
  List<Mark> _counted(List<Mark> m) {
    final out = [...m]..sort((a, b) => a.index - b.index);
    return out;
  }

  // ---- the analysis of the words that fit ----

  Future<void> _analyse() async {
    if (!analyse) return;
    final serial = ++_serial;
    analysing = true;
    try {
      final land = await analyseOffThread(
        pool,
        guessable,
        k: 2,
        weights: weights,
        blind: blind,
      );
      if (serial != _serial) return;
      landscape = land;
    } catch (e) {
      appLog.w('learn', 'could not analyse the position: ${e.runtimeType}');
    }
    if (serial == _serial) {
      analysing = false;
      notifyListeners();
    }
  }

  /// The two likeliest answers.
  List<String> get likeliest => pool.take(2).toList();

  /// The two best guesses for skill (empty until the analysis is in).
  List<Recommendation> get bestForSkill =>
      (landscape?.top ?? const []).take(2).toList();

  /// The two bets for luck: the guesses that gamble the most.
  List<RiskPick> get betsForLuck =>
      (landscape?.riskiest ?? const []).take(2).toList();

  // ---- plots ----

  /// The plot of [guess] against the words that fit now (or [against]), with the
  /// column of [landed] outlined when given.
  PlotSpec plotOf(
    String guess, {
    List<String>? against,
    List<Mark>? landed,
    double? best,
    String word = '',
  }) {
    final list = against ?? pool;
    final w = weights;
    final mass = <int, double>{};
    final size = <int, int>{};
    var total = 0.0;
    int codeOf(String target) =>
        blind ? blindCode(target, guess) : patternCode(target, guess);
    for (final t in list) {
      final x = w == null ? 1.0 : max(w[t] ?? 1, 1).toDouble();
      final c = codeOf(t);
      mass[c] = (mass[c] ?? 0) + x;
      size[c] = (size[c] ?? 0) + 1;
      total += x;
    }
    final keys = mass.keys.toList()
      ..sort((a, b) {
        final c = mass[b]!.compareTo(mass[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    final outcomes = [
      for (final k in keys) Outcome(mass[k]! / total, bitsOf(mass[k]! / total)),
    ];
    var h = 0.0;
    for (final o in outcomes) {
      h += o.chance * o.gain;
    }
    int? at;
    if (landed != null) {
      final code = blind
          ? landed.where((m) => m == Mark.correct).length * (length + 1) +
                landed.where((m) => m == Mark.present).length
          : markCode(landed);
      final i = keys.indexOf(code);
      at = i < 0 ? null : i;
    }
    return PlotSpec(
      outcomes: outcomes,
      expected: h,
      best: best,
      landed: at,
      word: word,
      sizes: [for (final k in keys) size[k]!],
    );
  }

  // ---- the blind colouring ----

  /// The counts of each row, as the pencil's rules read them.
  List<BlindRow> get blindRows => [
    for (final r in rows) BlindRow(r.word, r.green, r.yellow),
  ];

  /// The letters of the guesses made.
  Set<String> get letters => {for (final r in rows) ...r.word.split('')};

  void _refreshPencil() {
    if (!blind) return;
    final r = blindRows;
    deduced = BlindPencil.deduce(r, letters);
    pencil.refreshSoft(r, deduced);
    forced = pencil.forcedTiles(r, deduced);
  }

  /// The colour shown on tile [i] of guess [row] in a blind game: what the
  /// helper settled, then the player's own marks. Null: none.
  Mark? shownAt(int row, int i) =>
      pencil.shown(rows[row].word[i], i, deduced, forced);

  /// Whether the helper set the colour of that tile (it cannot be changed).
  bool helperAt(int row, int i) =>
      forced.containsKey('${rows[row].word[i]}@$i');

  /// A tap on a tile of a blind game: the next colour that keeps the rules.
  /// Returns why it could not change, or null.
  String? tapTile(int row, int i) {
    if (!blind) return null;
    final r = blindRows;
    final why = pencil.tap(rows[row].word[i], i, r, deduced, forced);
    _refreshPencil();
    notifyListeners();
    return why;
  }

  /// The colour of each key after the guesses so far, in a classic game or a
  /// mastermind: the best mark the letter got.
  Map<String, Mark> get keyMarks {
    final out = <String, Mark>{};
    for (final r in rows) {
      for (var i = 0; i < r.word.length; i++) {
        final ch = r.word[i];
        final m = r.marks[i];
        final old = out[ch];
        if (old == null || m.index < old.index) out[ch] = m;
      }
    }
    return out;
  }

  /// In a blind game, for each letter guessed: the chance (over the words that
  /// fit, by how likely they are) that a copy of it is in place, and that a copy
  /// is in the word and not yet in place. A letter that the counts rule out is
  /// not here: its key is grey.
  Map<String, (double green, double yellow)> get keyChances {
    final out = <String, (double, double)>{};
    final w = weights;
    final places = <String, Set<int>>{};
    for (final r in rows) {
      for (var i = 0; i < r.word.length; i++) {
        (places[r.word[i]] ??= {}).add(i);
      }
    }
    var total = 0.0;
    for (final t in pool) {
      total += w == null ? 1.0 : max(w[t] ?? 1, 1).toDouble();
    }
    if (total <= 0) return out;
    for (final ch in places.keys) {
      if (deduced[ch] == Mark.absent) continue;
      var g = 0.0, y = 0.0;
      for (final t in pool) {
        final x = w == null ? 1.0 : max(w[t] ?? 1, 1).toDouble();
        var copies = 0, placed = 0;
        for (var i = 0; i < t.length; i++) {
          if (t[i] != ch) continue;
          copies++;
          if (places[ch]!.contains(i)) placed++;
        }
        if (placed > 0) g += x;
        if (copies - placed > 0) y += x;
      }
      out[ch] = (g / total, y / total);
    }
    return out;
  }
}
