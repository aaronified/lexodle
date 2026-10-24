// Which definitions of skill, luck and daring predict the tries a game takes,
// and how evenly does each spread over the options? Plays simulated players of
// mixed habits (as predict_tries.dart) and, for every guess, works out
//
//   skill      the log-ratio skill of logic.dart (0..100)
//   skillPct   the share of all guesses it beats (mid-rank, 0..100)
//   luck       the app's luck (-100..100)
//   darRaw     the product daring of logic.dart (0..100)
//   darRank    a rank daring: the share of all guesses less bold than it minus
//              the share more bold (-100..100), where a guess that could be the
//              answer is as bold as its raw daring and a probe is -skill (the
//              best probe the safest)
//
// then fits the game's tries on each set of the game's means. Run from app:
//
//   dart run tools/predict_tries2.dart [code] [length] [games]
import 'dart:io';
import 'dart:math';

import 'package:lexodle/logic.dart';

import 'predict_tries.dart' show ols;

/// The mid-rank share of [values] that [x] beats, 0..100 ((less + same/2) / n).
double midRank(List<double> values, double x) {
  var less = 0, same = 0;
  for (final v in values) {
    if (v < x - 1e-9) {
      less++;
    } else if ((v - x).abs() <= 1e-9) {
      same++;
    }
  }
  return (less + same / 2) / values.length * 100;
}

/// The share of [values] below [x] minus the share above, -100..100.
double signedRank(List<double> values, double x) {
  var less = 0, more = 0;
  for (final v in values) {
    if (v < x - 1e-9) less++;
    if (v > x + 1e-9) more++;
  }
  return (less - more) / values.length * 100;
}

Future<void> main(List<String> args) async {
  final code = args.isNotEmpty ? args[0] : 'en';
  final length = args.length > 1 ? int.parse(args[1]) : 5;
  final games = args.length > 2 ? int.parse(args[2]) : 300;

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
  final index = {for (var i = 0; i < words.length; i++) words[i]: i};
  final weightOf = {
    for (var i = 0; i < words.length; i++) words[i]: weights[i],
  };
  final pool = words.length > 3000 ? 3000 : words.length;
  final rng = Random(11);
  stdout.writeln('$code $length: ${words.length} words, $games games');

  // the opening is the same every game: work it out once
  final openSums = [for (final w in words) splitSumSquares(words, w)];
  final first = await analyseGuesses(words, words);

  // pooled over every guess: how each score lands in each tenth of its scale
  final pooled = <String, List<double>>{
    'skill': [],
    'skillPct': [],
    'luck': [],
    'darRaw': [],
    'darRank': [],
  };
  final xs = <List<double>>[], ys = <double>[];
  for (var g = 0; g < games; g++) {
    final h = List.generate(5, (_) => pow(rng.nextDouble(), 2).toDouble());
    final total = h.reduce((a, b) => a + b);
    final answer = chooseWord(
      words.sublist(0, pool),
      weights.sublist(0, pool),
      rng,
    );
    var eligible = List.of(words);
    final per = <String, List<double>>{for (final k in pooled.keys) k: []};
    var tries = 7;
    for (var t = 0; t < 6; t++) {
      var roll = rng.nextDouble() * total, habit = 0;
      while (habit < 4 && roll >= h[habit]) {
        roll -= h[habit++];
      }
      final opening = t == 0;
      final land = opening ? first : await analyseGuesses(eligible, words);
      final String guess;
      switch (habit) {
        case 0:
          guess = land.top.first.word;
        case 1:
          guess = (opening ? first : await analyseGuesses(eligible, eligible))
              .top
              .first
              .word;
        case 2:
          guess = eligible.first;
        case 3:
          guess = eligible[rng.nextInt(eligible.length)];
        default:
          guess = words[rng.nextInt(min(words.length, 400))];
      }
      final after = filterEligible(eligible, guess, evaluate(answer, guess));
      final m = scoreGuess(
        eligible,
        guess,
        after.length,
        finalTry: t == 5,
        solved: guess == answer,
        triesLeft: 6 - t,
      ).withBest(land.bestExpected);
      final n = eligible.length;
      if (n > 1) {
        // every option's skill and boldness in this position
        final sums = opening
            ? openSums
            : [for (final w in words) splitSumSquares(eligible, w)];
        final possible = eligible.toSet();
        var tw = 0;
        for (final w in eligible) {
          tw += weightOf[w]!;
        }
        final skills = [
          for (final s in sums) skillAgainst(n, s / n, land.bestExpected),
        ];
        final raws = <double>[];
        final bold = <double>[];
        for (var i = 0; i < words.length; i++) {
          final poss = possible.contains(words[i]);
          final raw = daringOf(
            possible: poss,
            winChance: poss ? weightOf[words[i]]! / tw : 0,
            skill: skills[i],
            triesLeft: 6 - t,
          );
          raws.add(raw);
          bold.add(poss ? raw : -skills[i]);
        }
        final i = index[guess]!;
        final scores = {
          'skill': m.skill,
          'skillPct': midRank(skills, skills[i]),
          'luck': m.luck,
          'darRaw': raws[i],
          'darRank': signedRank(bold, bold[i]),
        };
        for (final e in scores.entries) {
          per[e.key]!.add(e.value);
          pooled[e.key]!.add(e.value);
        }
      }
      eligible = after;
      if (guess == answer) {
        tries = t + 1;
        break;
      }
    }
    if (per['skill']!.isEmpty) continue;
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    xs.add([for (final k in pooled.keys) mean(per[k]!)]);
    ys.add(tries.toDouble());
  }

  stdout.writeln('\nshare of all guesses in each tenth of the scale:');
  const ranges = {
    'skill': (0.0, 100.0),
    'skillPct': (0.0, 100.0),
    'luck': (-100.0, 100.0),
    'darRaw': (0.0, 100.0),
    'darRank': (-100.0, 100.0),
  };
  for (final e in pooled.entries) {
    final (lo, hi) = ranges[e.key]!;
    final counts = List<int>.filled(10, 0);
    for (final v in e.value) {
      counts[(((v - lo) / (hi - lo)) * 10).floor().clamp(0, 9)]++;
    }
    stdout.writeln(
      '  ${e.key.padRight(9)} ${counts.map((c) => (c / e.value.length * 100).round().toString().padLeft(3)).join(' ')}',
    );
  }

  stdout.writeln(
    '\n${ys.length} games; tries mean ${(ys.reduce((a, b) => a + b) / ys.length).toStringAsFixed(2)}',
  );
  final keys = pooled.keys.toList();
  void fit(String name, List<String> cols) {
    final c = [for (final k in cols) keys.indexOf(k)];
    final (beta, r2) = ols([
      for (final x in xs) [for (final i in c) x[i]],
    ], ys);
    stdout.writeln(
      '${name.padRight(34)} R^2 ${r2.toStringAsFixed(3)}  ${beta.map((b) => b.toStringAsFixed(4)).join(', ')}',
    );
  }

  fit('skill', ['skill']);
  fit('skillPct', ['skillPct']);
  fit('luck', ['luck']);
  fit('darRaw', ['darRaw']);
  fit('darRank', ['darRank']);
  fit('A  skill + luck + darRaw (now)', ['skill', 'luck', 'darRaw']);
  fit('B  skillPct + luck + darRaw', ['skillPct', 'luck', 'darRaw']);
  fit('C  skillPct + luck + darRank', ['skillPct', 'luck', 'darRank']);
  fit('D  skill + luck + darRank', ['skill', 'luck', 'darRank']);
  fit('E  skill + skillPct + luck + darRank', [
    'skill',
    'skillPct',
    'luck',
    'darRank',
  ]);
}
