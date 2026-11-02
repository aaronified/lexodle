import 'dart:math';

import 'package:flutter/foundation.dart' show compute;

import 'logic.dart';
import 'modes.dart';
import 'words.dart';

/// How many words a sequence has.
const sequenceLength = 3;

/// What a sequence of words played one after another, whatever the answer,
/// tells about the answer: how finely the colours they show split the words.
class SequenceScore {
  const SequenceScore({
    required this.words,
    required this.answers,
    required this.groups,
    required this.largest,
    required this.alone,
    required this.expectedLeft,
    required this.bits,
    required this.cumulativeBits,
    required this.by4,
    required this.by5,
  });

  /// The words, in the order played.
  final List<String> words;

  /// How many answers it was scored against.
  final int answers;

  /// How many groups the answers fall into: answers that show the same colours
  /// for every word of the sequence are one group.
  final int groups;

  /// The words in the biggest group (the worst case).
  final int largest;

  /// How many groups are a single answer: those it finds outright.
  final int alone;

  /// The words expected to be left once every word has been played.
  final double expectedLeft;

  /// The bits the sequence is expected to gain in all, and after each word.
  final double bits;
  final List<double> cumulativeBits;

  /// The chance of winning with the guess after the sequence (a fourth, for
  /// three words), and with the one after that: the best word of each group is
  /// played. The second is exact for groups of up to [exactGroup] words and a
  /// lower bound beyond.
  final double by4;
  final double by5;
}

/// How many words of a group are tried as the guess after the sequence when
/// the chance of winning by the guess after is worked out.
const exactGroup = 120;

double _entropy(Map<int, double> mass, double total) {
  var h = 0.0;
  for (final m in mass.values) {
    final q = m / total;
    h -= q * log(q) / ln2;
  }
  return h;
}

/// Scores [seq] (one to three words) against [answers] under [weights] (null:
/// every word as likely as the next). Pure.
SequenceScore scoreSequence(
  List<String> answers,
  List<String> seq,
  Map<String, int>? weights,
) {
  assert(seq.isNotEmpty && seq.length <= sequenceLength);
  final n = answers.length;
  final len = seq.first.length;
  final p = pow(3, len).toInt();
  double weightOf(int i) =>
      weights == null ? 1.0 : max(weights[answers[i]] ?? 1, 1).toDouble();
  final w = [for (var i = 0; i < n; i++) weightOf(i)];
  final total = w.fold(0.0, (a, b) => a + b);
  final keys = List<int>.filled(n, 0);
  final cumulative = <double>[];
  Map<int, double> mass = {};
  for (final g in seq) {
    mass = {};
    for (var i = 0; i < n; i++) {
      keys[i] = keys[i] * p + patternCode(answers[i], g);
      mass[keys[i]] = (mass[keys[i]] ?? 0) + w[i];
    }
    cumulative.add(_entropy(mass, total));
  }
  final members = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    (members[keys[i]] ??= []).add(i);
  }
  var sumSq = 0.0, win4 = 0.0, win5 = 0.0;
  var largest = 0, alone = 0;
  for (final group in members.values) {
    final m = group.fold(0.0, (a, i) => a + w[i]);
    sumSq += m * m;
    if (group.length > largest) largest = group.length;
    if (group.length == 1) alone++;
    win4 += group.fold(0.0, (a, i) => max(a, w[i]));
    win5 += _winByNext(group, answers, w);
  }
  return SequenceScore(
    words: List.of(seq),
    answers: n,
    groups: members.length,
    largest: largest,
    alone: alone,
    expectedLeft: n == 0 ? 0 : n * sumSq / (total * total),
    bits: cumulative.last,
    cumulativeBits: cumulative,
    by4: total <= 0 ? 0 : win4 / total,
    by5: total <= 0 ? 0 : win5 / total,
  );
}

/// The chance mass of [group] won by playing the best word of it and then, if
/// that was not it, the best word of the group the colours leave: the guess
/// itself, plus the likeliest word of every group among the others.
double _winByNext(List<int> group, List<String> answers, List<double> w) {
  if (group.length == 1) return w[group.first];
  var best = 0.0;
  for (final c in group.take(exactGroup)) {
    final classes = <int, double>{};
    for (final o in group) {
      if (o == c) continue;
      final code = patternCode(answers[o], answers[c]);
      classes[code] = max(classes[code] ?? 0, w[o]);
    }
    final value = w[c] + classes.values.fold(0.0, (a, b) => a + b);
    if (value > best) best = value;
  }
  return best;
}

/// The skill of a sequence: its bits against the best sequence found, 0 to 100.
/// A sequence as good as the benchmark is 100.
double sequenceSkill(SequenceScore mine, SequenceScore best) =>
    skillOf(mine.bits, best.bits);

/// What the search for a good sequence needs, in plain lists so it can run on
/// another isolate.
class SequenceJob {
  const SequenceJob(this.answers, this.pool, this.firsts, this.weights);

  /// The answers it is scored against (the likelier ones, to keep it quick).
  final List<String> answers;

  /// The words tried as the second and third of the sequence.
  final List<String> pool;

  /// The words tried as the first.
  final List<String> firsts;
  final Map<String, int>? weights;
}

/// A good sequence of three words, found greedily: for each of the [firsts], the
/// word that adds the most information to it, then the word that adds the most
/// to those two; the best of the sequences is returned. It is a search, not a
/// proof: there may be a better one. Pure, so a test can run it on a small list.
List<String> greedySequence(SequenceJob job) {
  final answers = job.answers;
  final n = answers.length;
  if (n == 0 || job.firsts.isEmpty) return const [];
  final len = answers.first.length;
  final p = pow(3, len).toInt();
  final w = [
    for (final a in answers)
      job.weights == null ? 1.0 : max(job.weights![a] ?? 1, 1).toDouble(),
  ];
  final total = w.fold(0.0, (a, b) => a + b);

  // the information of the keys so far, and of those with [c] played too
  double joint(List<int> keys, String c) {
    final mass = <int, double>{};
    for (var i = 0; i < n; i++) {
      final k = keys[i] * p + patternCode(answers[i], c);
      mass[k] = (mass[k] ?? 0) + w[i];
    }
    return _entropy(mass, total);
  }

  List<int> extend(List<int> keys, String c) => [
    for (var i = 0; i < n; i++) keys[i] * p + patternCode(answers[i], c),
  ];

  List<String>? bestSeq;
  var bestBits = -1.0;
  for (final first in job.firsts) {
    var keys = extend(List.filled(n, 0), first);
    final seq = [first];
    while (seq.length < sequenceLength) {
      String? pick;
      var pickBits = -1.0;
      for (final c in job.pool) {
        if (seq.contains(c)) continue;
        final h = joint(keys, c);
        if (h > pickBits) {
          pickBits = h;
          pick = c;
        }
      }
      if (pick == null) break;
      seq.add(pick);
      keys = extend(keys, pick);
    }
    final mass = <int, double>{};
    for (var i = 0; i < n; i++) {
      mass[keys[i]] = (mass[keys[i]] ?? 0) + w[i];
    }
    final h = _entropy(mass, total);
    if (h > bestBits) {
      bestBits = h;
      bestSeq = seq;
    }
  }
  return bestSeq ?? const [];
}

/// How many answers, and how many second and third words, the search looks at.
const searchAnswers = 3000;
const searchPool = 600;

final _benchmarks = <String, Future<SequenceScore>>{};

/// The best sequence found for [bank] at [length], scored against every word:
/// worked out once on another isolate (on the web, in the page) and kept. The
/// [firsts] are the opening guesses to start from.
Future<SequenceScore> benchmarkSequence({
  required WordBank bank,
  required int length,
  required Draw draw,
  required List<String> firsts,
}) => _benchmarks.putIfAbsent(
  '${bank.language.code}|$length|${draw.name}',
  () async {
    final all = bank.guessable(length);
    final weights = bank.law(length, draw);
    final job = SequenceJob(
      all.take(searchAnswers).toList(),
      {...firsts, ...all.take(searchPool)}.toList(),
      firsts.take(2).toList(),
      weights,
    );
    final words = await compute(greedySequence, job);
    return scoreSequence(all, words, weights);
  },
);

/// Forgets what [benchmarkSequence] kept (for a test).
void clearSequenceBenchmarks() => _benchmarks.clear();
