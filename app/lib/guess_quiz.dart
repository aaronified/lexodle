import 'dart:math';

import 'calc_dialog.dart';
import 'logic.dart';
import 'modes.dart' show Draw;
import 'review_plots.dart' show Outcome;
import 'words.dart';

/// The two kinds of question of "guess the best".
enum GuessKind { skill, luck }

/// One of the four words of a question, with everything the verdict shows.
class GuessOption {
  const GuessOption({
    required this.word,
    required this.h,
    required this.groups,
    required this.largest,
    required this.skill,
    required this.luck,
    required this.landedMass,
    required this.landedWords,
    required this.bits,
  });
  final String word;

  /// The bits it is expected to gain.
  final double h;
  final int groups;

  /// Words in the biggest group.
  final int largest;

  /// H over H*, 0 to 100.
  final double skill;

  /// Luck of the reply the hidden word got (luck kind; 0 in the skill kind).
  final double luck;

  /// Mass and word count of the group the hidden word falls in.
  final double landedMass;
  final int landedWords;

  /// Bits that reply gains: log2 of total mass over landed mass.
  final double bits;
}

/// A real position: a first guess played against a hidden word, the words that
/// still fit, and four guesses to choose from.
class GuessQuestion {
  const GuessQuestion({
    required this.kind,
    required this.answer,
    required this.first,
    required this.marks,
    required this.eligible,
    required this.weights,
    required this.options,
    required this.bestH,
  });
  final GuessKind kind;
  final String answer;
  final String first;
  final List<Mark> marks;
  final List<String> eligible;
  final Map<String, int>? weights;

  /// The four options, in the order shown.
  final List<GuessOption> options;

  /// H*: the best expected gain of any guess of the position.
  final double bestH;

  /// The option that is right: the largest H (skill) or the largest luck.
  int get rightIndex {
    var at = 0;
    for (var i = 1; i < options.length; i++) {
      final better = kind == GuessKind.skill
          ? options[i].h > options[at].h
          : options[i].luck > options[at].luck;
      if (better) at = i;
    }
    return at;
  }

  GuessOption get right => options[rightIndex];

  /// The plot of [o] against the words that fit.
  PlotSpec plotOf(GuessOption o) => guessPlot(
    eligible,
    o.word,
    weights,
    best: bestH,
    answer: kind == GuessKind.luck ? answer : null,
    word: kind == GuessKind.luck ? answer : '',
  );
}

/// The plot of [guess] against [eligible]: the outcomes sorted ascending by
/// gain (the biggest group first), the expected gain, H*, the column [answer]
/// landed in, and the words per group.
PlotSpec guessPlot(
  List<String> eligible,
  String guess,
  Map<String, int>? weights, {
  double? best,
  String? answer,
  String word = '',
}) {
  final mass = <int, double>{};
  final size = <int, int>{};
  var total = 0.0;
  for (final t in eligible) {
    final x = weights == null ? 1.0 : max(weights[t] ?? 1, 1).toDouble();
    final c = patternCode(t, guess);
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
  if (answer != null) {
    final i = keys.indexOf(patternCode(answer, guess));
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

const _firsts = ['tares', 'crane', 'slate', 'roate'];

/// Builds a question of [kind], or null when none was found in [attempts]
/// tries. Everything is scored on this thread: about 3,000 guesses against
/// 40 to 500 words, well under a second.
GuessQuestion? buildGuessQuestion({
  required WordBank bank,
  required int length,
  required Draw draw,
  required Random rng,
  required GuessKind kind,
  int attempts = 50,
}) {
  final answers = bank.answers(length);
  final guessable = bank.guessable(length);
  if (answers.isEmpty || guessable.isEmpty) return null;
  final weights = bank.law(length, draw);
  final common = answers.take(1500).toList();
  final known = [
    for (final w in _firsts)
      if (w.length == length && bank.valid.contains(w)) w,
  ];
  for (var attempt = 0; attempt < attempts; attempt++) {
    final answer = common[rng.nextInt(common.length)];
    final first = known.isEmpty
        ? guessable.first
        : known[rng.nextInt(known.length)];
    if (first == answer) continue;
    final marks = evaluate(answer, first);
    final eligible = filterEligible(answers, first, marks);
    if (eligible.length < 40 || eligible.length > 500) continue;
    final context = SplitContext(eligible, weights);
    final candidates = <String>{
      ...guessable.take(3000),
      ...eligible,
    }..remove(first);
    final scored = <(String, double)>[
      for (final w in candidates) (w, context.stats(w).h),
    ]..sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    final bestH = scored.first.$2;
    final words = kind == GuessKind.skill
        ? _skillWords(scored, bestH, rng)
        : _luckWords(scored, context, answer, rng);
    if (words == null) continue;
    final options = [
      for (final w in words)
        _option(context, eligible, w, answer, bestH),
    ]..shuffle(rng);
    return GuessQuestion(
      kind: kind,
      answer: answer,
      first: first,
      marks: marks,
      eligible: eligible,
      weights: weights,
      options: options,
      bestH: bestH,
    );
  }
  return null;
}

/// The best word and three at ranks 6 to 400 that split strictly worse.
List<String>? _skillWords(
  List<(String, double)> scored,
  double bestH,
  Random rng,
) {
  final mid = [
    for (var i = 5; i < min(400, scored.length); i++)
      if (scored[i].$2 < bestH - 1e-9 && scored[i].$2 > 1e-9) scored[i].$1,
  ]..shuffle(rng);
  if (mid.length < 3) return null;
  return [scored.first.$1, ...mid.take(3)];
}

/// Four guesses, none the answer, whose luck for it all differ (as shown, in
/// whole percent), so the luckiest is unique.
List<String>? _luckWords(
  List<(String, double)> scored,
  SplitContext context,
  String answer,
  Random rng,
) {
  final pool = [
    for (final s in scored)
      if (s.$1 != answer) s.$1,
  ];
  if (pool.length < 4) return null;
  for (var t = 0; t < 40; t++) {
    final picked = <String>{};
    while (picked.length < 4) {
      picked.add(pool[rng.nextInt(pool.length)]);
    }
    final luck = {
      for (final w in picked) w: _luckOf(context, w, answer).round(),
    };
    if (luck.values.toSet().length == 4) return picked.toList();
  }
  return null;
}

double _luckOf(SplitContext context, String guess, String answer) {
  final st = context.stats(guess, answer: answer);
  return st.luckOf(st.landedMass ?? 0);
}

GuessOption _option(
  SplitContext context,
  List<String> eligible,
  String word,
  String answer,
  double bestH,
) {
  final st = context.stats(word, answer: answer);
  final landed = st.landedMass ?? 0;
  final code = patternCode(answer, word);
  final inGroup = eligible.where((t) => patternCode(t, word) == code).length;
  return GuessOption(
    word: word,
    h: st.h,
    groups: st.groups,
    largest: st.largest,
    skill: skillOf(st.h, bestH),
    luck: st.luckOf(landed),
    landedMass: landed,
    landedWords: inGroup,
    bits: landed > 0 && st.total > 0 ? bitsOf(landed / st.total) : 0,
  );
}
