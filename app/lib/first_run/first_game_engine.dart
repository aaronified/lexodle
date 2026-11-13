import 'dart:math' show Random;

import '../logic.dart' show Mark, evaluate;

/// The pure logic of the first game (the tutorial game and the mode lessons),
/// ported from the mockup (`ui_v4.html`: chooseFirst, suggestion, chooseSecond,
/// oneLetterFix, shapePick, the mastermind candidate filter, the `learned`
/// flags). No widgets, no storage.
///
/// The mockup is deterministic: it never rolls a die, it takes the first word
/// that fits. [random] is therefore only used by [randomPoolWord], which the
/// mockup does not have.
///
/// A pattern is a string of `g` (right letter, right place), `y` (right letter,
/// elsewhere) and `x` (not in the word), built from [evaluate].

/// How many five-letter words the mockup's list has: the app's en list without
/// its accented words (`café`, `naïve`, ...), which the mockup left out.
const mockupWordCount = 11727;

/// The mockup's `suggestion` looks for an anagram among this many first words.
const anagramScan = 6000;

/// The first target: a word the first guess gives a [pattern] for, found among
/// the [candidates] (every word of the pool that gives that pattern).
class FirstChoice {
  const FirstChoice(this.pattern, this.candidates, this.target);
  final String pattern;
  final List<String> candidates;
  final String target;
}

/// What the mastermind mode keeps after a guess: the biggest group of words
/// that give the same [pattern], and that group as [candidates].
class CandidateStep {
  const CandidateStep(this.pattern, this.candidates);
  final String pattern;
  final List<String> candidates;
}

/// The one letter to change in an invalid word: the tile [index] and the
/// [letter] to put there.
class LetterFix {
  const LetterFix(this.index, this.letter);
  final int index;
  final String letter;
}

/// Shapes of a pattern a lesson wants its target to give (the mockup's SHAPE).
class Shape {
  Shape._();

  /// One green and one or two yellows.
  static bool classic(String p) {
    final y = count(p, 'y');
    return count(p, 'g') == 1 && y >= 1 && y <= 2;
  }

  /// One or two greens and at least one yellow.
  static bool lock(String p) {
    final g = count(p, 'g');
    return g >= 1 && g <= 2 && count(p, 'y') >= 1;
  }

  /// At least one green or yellow.
  static bool any(String p) => count(p, 'g') + count(p, 'y') >= 1;
}

/// How many times [c] is in the pattern [p].
int count(String p, String c) => c.isEmpty ? 0 : p.split(c).length - 1;

/// The pattern string of [guess] against [target].
String patternOf(String guess, String target) => evaluate(target, guess)
    .map(
      (m) => switch (m) {
        Mark.correct => 'g',
        Mark.present => 'y',
        Mark.absent => 'x',
      },
    )
    .join();

String _sorted(String w) => (w.split('')..sort()).join();

class FirstGameEngine {
  /// [words] is one language's list of one length, most common first. The
  /// target pool is its first [poolSize] words. In assets/words/en.txt the
  /// words of a length are in descending order of frequency, so the order is
  /// the commonness order the mockup relies on.
  FirstGameEngine(List<String> words, {this.poolSize = 3000, Random? random})
    : words = List.unmodifiable(words),
      random = random ?? Random(),
      pool = List.unmodifiable(words.take(poolSize)),
      valid = Set.unmodifiable(words),
      _rank = {for (var i = words.length - 1; i >= 0; i--) words[i]: i};

  final List<String> words;
  final int poolSize;
  final Random random;
  final List<String> pool;
  final Set<String> valid;
  final Map<String, int> _rank;

  bool isValid(String w) => valid.contains(w);

  /// A random word of the pool. Not in the mockup.
  String randomPoolWord() => pool[random.nextInt(pool.length)];

  /// The target of the plain game (the mockup's gameReset): the pool word at
  /// `(dayOfMonth * 37) % 400`.
  String gameTarget(int dayOfMonth) => pool[(dayOfMonth * 37) % 400];

  /// The tutorial picks its word after the first guess [g1], like the
  /// mastermind mode, only as the lesson needs it: the most common pattern
  /// among the pool words with one green and one or two yellows (else any
  /// green, else any word), and the first word of that group.
  ///
  /// With a pool that holds nothing but [g1] there is no pattern: the target
  /// is then the first pool word and the pattern is empty (the mockup would
  /// fail here).
  FirstChoice chooseFirst(String g1) {
    var c = [
      for (final t in pool)
        if (t != g1 && Shape.classic(patternOf(g1, t))) t,
    ];
    if (c.isEmpty) {
      c = [
        for (final t in pool)
          if (t != g1 && patternOf(g1, t).contains('g')) t,
      ];
    }
    if (c.isEmpty) {
      c = [
        for (final t in pool)
          if (t != g1) t,
      ];
    }
    final n = <String, int>{};
    for (final t in c) {
      final q = patternOf(g1, t);
      n[q] = (n[q] ?? 0) + 1;
    }
    String? best;
    for (final q in n.keys) {
      if (best == null || n[q]! > n[best]!) best = q;
    }
    final group = [
      for (final t in pool)
        if (t != g1 && patternOf(g1, t) == best) t,
    ];
    return FirstChoice(
      best ?? '',
      group,
      group.isEmpty ? pool.first : group.first,
    );
  }

  /// The word to suggest after the first guess [g1] whose pattern is [p1] and
  /// whose candidates are [c]: one that keeps the green in place and moves the
  /// yellows. An anagram of [g1] when there is one (first among [c], then
  /// among the first [anagramScan] words with the same green and pattern),
  /// else the best scored word of [c]: +10 for the green kept, +3 for each
  /// yellow letter moved; the first wins a tie.
  String suggestion(String g1, String p1, List<String> c) {
    final gi = p1.indexOf('g');
    final sg = _sorted(g1);
    String? ana;
    for (final w in c) {
      if (w != g1 && _sorted(w) == sg) {
        ana = w;
        break;
      }
    }
    if (ana == null) {
      for (final w in words.take(anagramScan)) {
        // in the mockup, with no green, w[-1] === g1[-1] is undefined ===
        // undefined, so the green test passes
        if (w != g1 &&
            _sorted(w) == sg &&
            (gi < 0 || w[gi] == g1[gi]) &&
            patternOf(g1, w) == p1) {
          ana = w;
          break;
        }
      }
    }
    if (ana != null) return ana;
    String? best;
    var bs = -1;
    for (final w in c) {
      var sc = 0;
      if (gi >= 0 && w[gi] == g1[gi]) sc += 10;
      for (var i = 0; i < 5 && i < p1.length; i++) {
        if (p1[i] == 'y' && w.contains(g1[i]) && w[i] != g1[i]) sc += 3;
      }
      if (sc > bs) {
        bs = sc;
        best = w;
      }
    }
    return best ?? (c.isNotEmpty ? c.first : pool.first);
  }

  /// The target after the second guess [g2], from the first choice's
  /// [candidates], its [suggested] word and its [target]: when the player
  /// typed the suggestion, a candidate with two greens (else two or more);
  /// otherwise (or when none) a candidate with at least one green; else the
  /// first candidate; else [target].
  String chooseSecond(
    String g2, {
    required List<String> candidates,
    required String suggested,
    required String target,
  }) {
    int gr(String t) => count(patternOf(g2, t), 'g');
    final c = [
      for (final t in candidates)
        if (t != g2) t,
    ];
    String? pick;
    if (g2 == suggested) {
      pick =
          _firstWhere(c, (t) => gr(t) == 2) ??
          _firstWhere(c, (t) => gr(t) >= 2);
    }
    pick ??= _firstWhere(c, (t) => gr(t) >= 1);
    return pick ?? (c.isNotEmpty ? c.first : target);
  }

  /// One letter changed makes a word: the most common such word. Tries each
  /// tile in turn and each letter a to z; the lowest rank in [words] wins, the
  /// first found on a tie. A word of [valid] that is not in [words] has rank 0
  /// (the mockup's `max(indexOf, 0)`). Null when there is none.
  LetterFix? oneLetterFix(String g, {Set<String>? valid}) {
    final set = valid ?? this.valid;
    LetterFix? best;
    var rank = 1 << 30;
    for (var i = 0; i < g.length; i++) {
      for (var k = 0; k < 26; k++) {
        final ch = String.fromCharCode(97 + k);
        if (ch == g[i]) continue;
        final w = g.substring(0, i) + ch + g.substring(i + 1);
        if (set.contains(w)) {
          final r = _rank[w] ?? 0;
          if (r < rank) {
            rank = r;
            best = LetterFix(i, ch);
          }
        }
      }
    }
    return best;
  }

  /// What the mastermind mode keeps after [guess]: it groups [candidates] by
  /// the pattern they would give and keeps the biggest group (the first
  /// created on a tie). An empty list gives an empty step (the mockup would
  /// fail).
  CandidateStep filterCandidates(List<String> candidates, String guess) {
    final b = <String, List<String>>{};
    for (final w in candidates) {
      (b[patternOf(guess, w)] ??= []).add(w);
    }
    String? best;
    for (final q in b.keys) {
      if (best == null || b[q]!.length > b[best]!.length) best = q;
    }
    return CandidateStep(best ?? '', best == null ? const [] : b[best]!);
  }

  /// The lessons choose their target after the first guess [g]: the first word
  /// of [pool] that is not [g] nor in [exclude] and whose pattern fits
  /// [shape]; else the first word that is not excluded; else the first word.
  static String shapePick(
    String g,
    List<String> pool,
    bool Function(String pattern) shape,
    List<String> exclude,
  ) {
    bool ok(String t) => t != g && !exclude.contains(t);
    for (final t in pool) {
      if (ok(t) && shape(patternOf(g, t))) return t;
    }
    return _firstWhere(pool, ok) ?? pool.first;
  }

  /// [shapePick] over this engine's pool.
  String pick(
    String g,
    bool Function(String pattern) shape, [
    List<String> exclude = const [],
  ]) => shapePick(g, pool, shape, exclude);
}

String? _firstWhere(List<String> l, bool Function(String) f) {
  for (final x in l) {
    if (f(x)) return x;
  }
  return null;
}

/// What the player has shown they understand in the first game (the mockup's
/// `learned`) and the tutorial's coach step (`T.step`, 0 to 6). Immutable:
/// every event returns the next progress.
///
/// Steps: 0 type a word, 1 colours (suggestion shown), 2 blanks and the
/// cursor, 3 lock a letter, 4 clear the row, 5 hints, 6 free.
class FirstGameProgress {
  const FirstGameProgress({
    this.swipe = false,
    this.fix = false,
    this.blank = false,
    this.lock = false,
    this.step = 0,
  });

  final bool swipe;
  final bool fix;
  final bool blank;
  final bool lock;
  final int step;

  FirstGameProgress copyWith({
    bool? swipe,
    bool? fix,
    bool? blank,
    bool? lock,
    int? step,
  }) => FirstGameProgress(
    swipe: swipe ?? this.swipe,
    fix: fix ?? this.fix,
    blank: blank ?? this.blank,
    lock: lock ?? this.lock,
    step: step ?? this.step,
  );

  /// Typing [ch]; a blank (`_`) is learned, and ends step 2.
  FirstGameProgress onType(String ch, {required bool tutorial}) {
    final isBlank = ch == '_';
    return copyWith(
      blank: isBlank ? true : blank,
      step: tutorial && step == 2 && isBlank ? 3 : step,
    );
  }

  /// Delete (the backspace): in step 4 it counts as clearing the row (the
  /// mockup sets swipe here too).
  FirstGameProgress onDelete({required bool tutorial}) =>
      tutorial && step == 4 ? copyWith(swipe: true, step: 5) : this;

  /// The row is cleared by a swipe: always learned; ends step 4.
  FirstGameProgress onClear({required bool tutorial}) =>
      copyWith(swipe: true, step: tutorial && step == 4 ? 5 : step);

  /// Tapping tile [i]; [fixIndex] is the tile of the one-letter-fix arrow
  /// shown for an invalid word, if any. Tapping it learns the fix. Any tap
  /// ends step 2.
  FirstGameProgress onTap(int i, {int? fixIndex, required bool tutorial}) =>
      copyWith(
        fix: fixIndex != null && fixIndex == i ? true : fix,
        step: tutorial && step == 2 ? 3 : step,
      );

  /// Moving the cursor with the left arrow key: ends step 2.
  FirstGameProgress onArrowLeft({required bool tutorial}) =>
      tutorial && step == 2 ? copyWith(step: 3) : this;

  /// A tile was locked (not unlocked): learned; ends step 3, going to step 5
  /// when the row was already cleared before, else to step 4.
  FirstGameProgress onLocked({required bool tutorial}) => copyWith(
    lock: true,
    step: tutorial && step == 3 ? (swipe ? 5 : 4) : step,
  );

  /// A valid guess that did not solve the game: steps 0, 1 and 5 move on.
  FirstGameProgress onGuess({required bool tutorial}) {
    if (!tutorial) return this;
    return switch (step) {
      0 => copyWith(step: 1),
      1 => copyWith(step: 2),
      5 => copyWith(step: 6),
      _ => this,
    };
  }

  /// The lamp was tapped or a hint was bought: ends step 5.
  FirstGameProgress onHint({required bool tutorial}) =>
      tutorial && step == 5 ? copyWith(step: 6) : this;

  /// The coach's next button: at least step 6.
  FirstGameProgress onNext() => copyWith(step: step < 6 ? 6 : step);

  /// The coach's line for an invalid word, as the mockup words it, by what is
  /// learned: [hasFix] is whether a one-letter fix exists.
  String? invalidHint({required bool hasFix}) {
    if (!swipe) {
      return 'not a word. swipe the row to clear it, or press ⌫.'
          '${hasFix ? ' tap the arrow to change a letter.' : ''}';
    }
    return 'not a word.${hasFix && !fix ? ' tap the arrow to change a letter.' : ''}';
  }

  /// In the plain game, the next thing to teach, or null: lock after a green,
  /// then blanks after two guesses. [rows] is the guesses made so far and
  /// [hasGreen] whether any of them has a green.
  String? gameHint({required int rows, required bool hasGreen}) {
    if (rows > 0 && !lock && hasGreen) return 'double tap a green to lock it.';
    if (rows > 1 && !blank) return 'press _ for a blank.';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FirstGameProgress &&
      other.swipe == swipe &&
      other.fix == fix &&
      other.blank == blank &&
      other.lock == lock &&
      other.step == step;

  @override
  int get hashCode => Object.hash(swipe, fix, blank, lock, step);
}
