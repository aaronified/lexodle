// Plays bots of different habits through the real skill / daring maths, to see
// where each kind of player lands, so the playstyle thresholds in
// lib/playstyle.dart rest on something. Pure Dart (no Flutter), run from the
// app folder:
//
//   dart run tools/calibrate_styles.dart [code] [length] [games]
//
// The answers are drawn from the 3000 most common words, as the daily is.
import 'dart:io';
import 'dart:math';

import 'package:lexodle/logic.dart';

Future<void> main(List<String> args) async {
  final code = args.isNotEmpty ? args[0] : 'en';
  final length = args.length > 1 ? int.parse(args[1]) : 5;
  final games = args.length > 2 ? int.parse(args[2]) : 40;

  final words = <String>[];
  final weights = <int>[];
  for (final line in File('assets/words/$code.txt').readAsLinesSync()) {
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    final w = line.substring(0, tab);
    if (w.length != length) continue;
    words.add(w);
    weights.add(int.parse(line.substring(tab + 1)));
  }
  final pool = words.length > 3000 ? 3000 : words.length;
  stdout.writeln('$code $length: ${words.length} words, answers from $pool');

  // the first position is the same every game: analyse it once
  final first = await analyseGuesses(words, words);
  final rng = Random(2026);

  Future<String> pick(String bot, List<String> eligible, bool opening) async {
    switch (bot) {
      case 'best':
        final land = opening ? first : await analyseGuesses(eligible, words);
        return land.top.first.word;
      case 'frequent': // the commonest word that still fits
        return eligible.first;
      case 'random-fit': // any word that still fits
        return eligible[rng.nextInt(eligible.length)];
      case 'near-best': // one of the three best, at random
        final land = opening
            ? first
            : await analyseGuesses(eligible, words, k: 3);
        final top = land.top.take(3).toList();
        return top[rng.nextInt(top.length)].word;
      case 'sharp-bold': // of the 30 best, the riskiest
      case 'sharp-safe': // of the 30 best, the least risky
        final land = opening
            ? first
            : await analyseGuesses(eligible, words, k: 30);
        final top = land.top.take(30).map((r) => r.word).toList();
        double risk(String w) => scoreGuess(eligible, w, 0).risk;
        top.sort((a, b) => risk(a).compareTo(risk(b)));
        return bot == 'sharp-bold' ? top.last : top.first;
      case 'wild': // a common word, whatever the clues say
        return words[rng.nextInt(min(words.length, 400))];
      case 'wild-bold': // a rare word, whatever the clues say
        return words[words.length ~/ 2 + rng.nextInt(words.length ~/ 2)];
      default:
        throw ArgumentError(bot);
    }
  }

  // every (skill, daring) pair of every bot, to see how the two go together
  final pairs = <(double, double)>[];
  for (final bot in [
    'best',
    'near-best',
    'sharp-safe',
    'sharp-bold',
    'frequent',
    'random-fit',
    'wild',
    'wild-bold',
  ]) {
    var skills = <double>[], darings = <double>[];
    var wins = 0, used = 0;
    final perGameSkill = <double>[], perGameDaring = <double>[];
    for (var g = 0; g < games; g++) {
      final answer = chooseWord(
        words.sublist(0, pool),
        weights.sublist(0, pool),
        rng,
      );
      var eligible = List.of(words);
      final s = <double>[], d = <double>[];
      var won = false;
      for (var t = 0; t < 6 && !won; t++) {
        final guess = await pick(bot, eligible, t == 0);
        final marks = evaluate(answer, guess);
        final after = filterEligible(eligible, guess, marks);
        final land = t == 0 && eligible.length == words.length
            ? first
            : await analyseGuesses(eligible, words);
        final m = scoreGuess(
          eligible,
          guess,
          after.length,
          finalTry: t == 5,
          solved: guess == answer,
        ).withLandscape(land);
        if (m.before > 1) {
          s.add(m.skill);
          if (m.daring != null) {
            d.add(m.daring!);
            pairs.add((m.skill, m.daring!));
          }
        }
        eligible = after;
        used++;
        won = guess == answer;
      }
      if (won) wins++;
      skills.addAll(s);
      darings.addAll(d);
      if (s.isNotEmpty) perGameSkill.add(s.reduce((a, b) => a + b) / s.length);
      if (d.isNotEmpty) {
        perGameDaring.add(d.reduce((a, b) => a + b) / d.length);
      }
    }
    double mean(List<double> v) =>
        v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    double q(List<double> v, double p) {
      if (v.isEmpty) return 0;
      final s = List.of(v)..sort();
      return s[((s.length - 1) * p).round()];
    }

    stdout.writeln(
      '${bot.padRight(10)} win ${(wins / games * 100).toStringAsFixed(0).padLeft(3)}%'
      '  guesses/game ${(used / games).toStringAsFixed(1)}'
      '  skill mean ${mean(skills).toStringAsFixed(1).padLeft(5)}'
      ' (game p10 ${q(perGameSkill, .1).toStringAsFixed(0)}'
      ' p50 ${q(perGameSkill, .5).toStringAsFixed(0)}'
      ' p90 ${q(perGameSkill, .9).toStringAsFixed(0)})'
      '  daring mean ${mean(darings).toStringAsFixed(1).padLeft(5)}'
      ' (game p10 ${q(perGameDaring, .1).toStringAsFixed(0)}'
      ' p50 ${q(perGameDaring, .5).toStringAsFixed(0)}'
      ' p90 ${q(perGameDaring, .9).toStringAsFixed(0)})',
    );
  }

  stdout.writeln(
    '\ndaring by the skill of the guess (all bots, ${pairs.length} guesses)',
  );
  for (final (lo, hi) in [
    (0, 40),
    (40, 55),
    (55, 70),
    (70, 80),
    (80, 90),
    (90, 99.99),
    (99.99, 101),
  ]) {
    final d = [
      for (final (s, dr) in pairs)
        if (s >= lo && s < hi) dr,
    ];
    if (d.isEmpty) continue;
    d.sort();
    double q(double p) => d[((d.length - 1) * p).round()];
    stdout.writeln(
      'skill ${lo.toString().padLeft(3)}-${hi.toStringAsFixed(0).padRight(3)}'
      ' n=${d.length.toString().padLeft(5)}'
      '  daring p10 ${q(.1).toStringAsFixed(0).padLeft(3)}'
      ' p50 ${q(.5).toStringAsFixed(0).padLeft(3)}'
      ' p90 ${q(.9).toStringAsFixed(0).padLeft(3)}',
    );
  }
}
