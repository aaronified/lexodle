import 'dart:math';

import 'dart:typed_data';

import 'analysis_worker.dart';
import 'logic.dart';

/// The maths of the quartet and the relay race.
///
/// Every board is judged the way a single game is (see [scoreGuess]): for a
/// board with n words still possible, a guess splits them into groups, and the
/// expected size of the group you land in is E = n * sum(q^2), q being the
/// chance of each group (its size over n when the words are equally likely).
/// Its skill is H / H* * 100, the expected gain of the guess (the entropy of
/// its split, in bits) as a share of the best real guess's H*, and its luck is
/// the chance of gaining less than you did less that of gaining more.
///
/// A guess in a quartet is made for every unsolved board at once, so its
/// skill and luck are the average over those boards, each weighted by how much
/// there was still to find out on it: log2 of its n, never less than 1 bit.
/// A board with 1,000 words left therefore counts for about ten times a board
/// with two, and a board with a single word left (which only has to be played
/// out) counts for one bit, so playing that word is rewarded and missing it is
/// not free. The weights make the combined skill the same number as the
/// combined split quality of the guess, which is also what the picks maximise.
///
/// In a relay race a guess is made for the board that is on, so it is judged
/// on that board alone. What the guess does for the boards still to come shows
/// up when they open: each begins with every earlier guess applied, and the
/// review reports how many words were left at that moment (a [HeadStart]).
double boardWeight(int before) => log(max(before, 2)) / ln2;

/// What one guess did to one board it was made for.
class BoardStep {
  const BoardStep(this.board, this.metrics, this.solved);

  /// Which board, from 0.
  final int board;
  final GuessMetrics metrics;

  /// Whether this guess solved the board.
  final bool solved;
}

/// A board opening, in a relay race: how much the guesses made before it
/// opened had already narrowed it down.
class HeadStart {
  const HeadStart(this.board, this.opensAfter, this.words, this.total);
  final int board;

  /// How many guesses had been made when the board opened.
  final int opensAfter;

  /// Words still possible on it at that moment, and in the whole list.
  final int words;
  final int total;

  /// The share of the list already ruled out, in percent.
  double get cut => total <= 0 ? 0 : (1 - words / total) * 100;
}

/// One guess of a quartet or relay race, with what it did to each live board.
class MultiStep {
  const MultiStep(
    this.guess,
    this.boards,
    this.liveBefore, {
    required this.finalTry,
    this.opened = const [],
  });
  final String guess;
  final List<BoardStep> boards;

  /// The words still possible on each live board before the guess, in the
  /// order of [boards].
  final List<List<String>> liveBefore;

  /// Whether this was the last try, when luck is the chance of the pick.
  final bool finalTry;

  /// Boards that opened right after this guess (relay race).
  final List<HeadStart> opened;

  double _mean(double Function(GuessMetrics m) f) {
    var sum = 0.0, weights = 0.0;
    for (final b in boards) {
      final w = boardWeight(b.metrics.before);
      sum += w * f(b.metrics);
      weights += w;
    }
    return weights == 0 ? 0 : sum / weights;
  }

  /// The guess's skill over every board it was made for, weighted as above.
  double get skill => _mean((m) => m.skill);

  /// Its luck, weighted the same way.
  double get luck => _mean((m) => m.luck);

  int get solvedNow => boards.where((b) => b.solved).length;

  /// Whether every board's skill is measured against its real best guess; false
  /// while that is still being worked out.
  bool get ready => boards.every((b) => b.metrics.ready);

  /// The same step with each board's skill measured against its best real
  /// guess, [bests] in the order of [boards].
  MultiStep withBests(List<double> bests) => MultiStep(
    guess,
    [
      for (var i = 0; i < boards.length; i++)
        BoardStep(
          boards[i].board,
          boards[i].metrics.withBest(bests[i]),
          boards[i].solved,
        ),
    ],
    liveBefore,
    finalTry: finalTry,
    opened: opened,
  );
}

/// A suggested guess for the live boards, and how it would have scored.
class MultiPick {
  const MultiPick(this.word, this.skill, this.possibleOn);
  final String word;

  /// The combined skill it would score (see [MultiStep.skill]).
  final double skill;

  /// On how many of the live boards it is itself a possible answer.
  final int possibleOn;
}

/// The words worth scoring for the live boards [live]: the likeliest answers
/// of each, and the most frequent words accepted as guesses.
Set<String> multiCandidates(List<List<String>> live, List<String> guessable) =>
    {for (final board in live) ...board.take(200), ...guessable.take(400)};

/// What the analysis of one step of a quartet or a relay race found: the best
/// picks, and for each live board (in the order given) E*, the smallest expected
/// pool any real guess leaves on it, which that board's skill is measured
/// against.
class MultiLandscape {
  const MultiLandscape(this.picks, this.bests);
  final List<MultiPick> picks;
  final List<double> bests;
}

/// Scores [candidates] (pass every word the game accepts, for E* to be the real
/// best) against the live boards [live]: the words still possible on each board
/// the guess would be made for. Each board's skill is measured against its own
/// best real guess; the picks are the candidates with the highest combined
/// skill, weighted as in [MultiStep.skill], a candidate that could be an answer
/// somewhere winning ties. Boards that share the very same list of words (all
/// of them at the start) are worked out once. Yields to the event loop now and
/// then.
Future<MultiLandscape> analyseMulti(
  List<List<String>> live,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
}) async {
  final cands = candidates.toList();
  final bests = List<double>.filled(live.length, 0);
  final active = [
    for (var i = 0; i < live.length; i++)
      if (live[i].isNotEmpty) i,
  ];
  if (active.isEmpty || cands.isEmpty) return MultiLandscape(const [], bests);

  // the expected gain of every candidate, once per distinct list
  final sums = Map<List<String>, Float64List>.identity();
  final sets = Map<List<String>, Set<String>>.identity();
  var work = 0;
  for (final i in active) {
    final board = live[i];
    if (sums.containsKey(board)) continue;
    // on other threads where there are some, so the screen stays smooth; else
    // here, yielding now and then
    var ss = await gainsOffThread(board, cands, weights);
    if (ss == null) {
      ss = Float64List(cands.length);
      for (var c = 0; c < cands.length; c++) {
        ss[c] = splitStats(board, cands[c], weights).h;
        if (++work % 20 == 0) await Future<void>.delayed(Duration.zero);
      }
    }
    sums[board] = ss;
    sets[board] = board.toSet();
  }
  for (final i in active) {
    final board = live[i];
    final highest = sums[board]!.reduce((a, b) => a > b ? a : b);
    bests[i] = highest;
  }

  final boardWeights = {for (final i in active) i: boardWeight(live[i].length)};
  final total = boardWeights.values.fold<double>(0, (a, b) => a + b);
  final scored = <MultiPick>[];
  for (var c = 0; c < cands.length; c++) {
    var sum = 0.0, fits = 0;
    for (final i in active) {
      final board = live[i];
      final n = board.length;
      final fit = sets[board]!.contains(cands[c]);
      if (fit) fits++;
      final skill = n == 1
          ? (fit ? 100.0 : 0.0)
          : skillOf(sums[board]![c], bests[i]);
      sum += boardWeights[i]! * skill;
    }
    scored.add(MultiPick(cands[c], sum / total, fits));
  }
  scored.sort((a, b) {
    final c = b.skill.compareTo(a.skill);
    return c != 0 ? c : b.possibleOn.compareTo(a.possibleOn);
  });
  return MultiLandscape(scored.take(k).toList(), bests);
}

/// The best next guesses for [live], best first (see [analyseMulti]).
Future<List<MultiPick>> recommendMulti(
  List<List<String>> live,
  Iterable<String> candidates, {
  int k = 3,
  Map<String, int>? weights,
}) async =>
    (await analyseMulti(live, candidates, k: k, weights: weights)).picks;

/// A suggested guess for the last try, and how many boards it can be expected
/// to solve.
class FinalPick {
  const FinalPick(this.word, this.expectedSolved);
  final String word;

  /// The sum, over the live boards it is a possible answer on, of 1 / the
  /// words possible there: the expected number of boards it solves.
  final double expectedSolved;
}

/// The picks for the last try of a quartet or a relay race. Nothing is left to
/// learn, so only a word that is still possible on a live board is worth
/// naming; each such word solves a board with the chance 1 / n of the words
/// possible there, so a word that is possible on several boards is worth the
/// sum. Best first; equal words keep the order of the most common first. With
/// [weights] a word has its share of the weight there as its chance on a board.
List<FinalPick> finalPicks(
  List<List<String>> live, {
  int k = 3,
  Map<String, int>? weights,
}) {
  int weightOf(String w) => weights == null ? 1 : max(weights[w] ?? 1, 1);
  final boards = [
    for (final b in live)
      if (b.isNotEmpty) b,
  ];
  final value = <String, double>{};
  for (final b in boards) {
    final total = b.fold<int>(0, (a, w) => a + weightOf(w));
    for (final w in b) {
      value[w] = (value[w] ?? 0) + weightOf(w) / total;
    }
  }
  final words = value.keys.toList();
  // stable: the order words first appeared in (most common first)
  final order = {for (var i = 0; i < words.length; i++) words[i]: i};
  words.sort((a, b) {
    final c = value[b]!.compareTo(value[a]!);
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return [for (final w in words.take(k)) FinalPick(w, value[w]!)];
}

/// The expected number of boards [guess] solves on the last try (see
/// [finalPicks]): the sum of 1 / n over the live boards it is possible on.
double expectedSolved(
  List<List<String>> live,
  String guess, {
  Map<String, int>? weights,
}) {
  int weightOf(String w) => weights == null ? 1 : max(weights[w] ?? 1, 1);
  var sum = 0.0;
  for (final b in live) {
    if (b.isNotEmpty && b.contains(guess)) {
      sum += weightOf(guess) / b.fold<int>(0, (a, w) => a + weightOf(w));
    }
  }
  return sum;
}

/// A short plain-English reading of one step of a quartet or relay race: one
/// sentence of verdict, then at most one short sentence of fact.
/// [bestWord] and [bestSkill] are the best pick's, [bestFinalWord] and
/// [bestSolved] the best last-try pick's with its expected boards solved, and
/// [yourSolved] the same for the guess played; [ready] is false while the
/// picks are still being worked out.
String multiComment(
  MultiStep s, {
  String? bestWord,
  double? bestSkill,
  bool ready = true,
  String? bestFinalWord,
  double? bestSolved,
  double? yourSolved,
}) {
  final out = <String>[];
  // the fact, chosen below: the first that applies
  final facts = <String>[];
  final names = [for (final b in s.boards.where((b) => b.solved)) b.board + 1];
  final open = [
    for (final b in s.boards)
      if (!b.solved && b.metrics.before > 1) b,
  ]..sort((a, b) => b.metrics.skill.compareTo(a.metrics.skill));
  if (!ready) {
    out.add('Working out the alternatives…');
  } else if (s.finalTry) {
    // the last try: only a word that fits a board can win one
    final mine = yourSolved ?? 0;
    final n = s.boards.length;
    out.add(
      mine == 0
          ? 'Last try: ${s.guess} fits no open board, so it could not win one.'
          : 'Last try: ${s.guess} could solve about ${mine.toStringAsFixed(2)} '
                'of the $n boards left.',
    );
    if (bestFinalWord != null &&
        bestSolved != null &&
        bestSolved > mine + 1e-9) {
      facts.add('$bestFinalWord was better: ${bestSolved.toStringAsFixed(2)}.');
    }
  } else if (bestWord != null && bestSkill != null) {
    final gap = bestSkill - s.skill;
    if (gap <= 0.5) {
      out.add('Terrific choice: ${s.guess} was as good as any I found.');
    } else if (gap <= 4) {
      out.add('Good choice, but $bestWord was a touch sharper.');
    } else if (gap <= 12) {
      out.add('Decent, but $bestWord was a better split.');
    } else {
      out.add('A missed chance: $bestWord was a much better split.');
    }
  }
  if (names.isNotEmpty) {
    facts.add(
      names.length == 1
          ? 'It solved board ${names.single}.'
          : 'It solved boards ${names.join(' and ')}.',
    );
  }
  if (open.length >= 2 &&
      open.first.metrics.skill - open.last.metrics.skill >= 15) {
    facts.add(
      'It helped board ${open.first.board + 1} most and board '
      '${open.last.board + 1} least.',
    );
  }
  if (!s.finalTry) {
    if (s.luck >= 25) {
      facts.add('You got lucky: the clues were kind.');
    } else if (s.luck <= -25) {
      facts.add('Unlucky: the clues were harsh.');
    }
  }
  if (facts.isNotEmpty) out.add(facts.first);
  return out.join(' ');
}
