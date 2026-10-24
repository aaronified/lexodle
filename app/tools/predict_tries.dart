// Do skill, luck and daring predict how many tries a game takes? Plays
// simulated players of mixed habits through the real maths, and fits the
// number of tries (a failed game counts as 7) on each game's mean skill, mean
// luck and mean daring by least squares, with and without the daring. Pure Dart,
// run from the app folder:
//
//   dart run tools/predict_tries.dart [code] [length] [games]
//
// Each game draws its own habits: the chance, per guess, of playing the best
// guess, the best split among the words that fit, the commonest word that fits,
// a word that fits at random, or a common word whatever the clues say.
import 'dart:io';
import 'dart:math';

import 'package:lexodle/logic.dart';

/// Least-squares fit of [y] on the columns of [x] (and a constant): returns the
/// coefficients (constant first) and R squared.
(List<double>, double) ols(List<List<double>> x, List<double> y) {
  final n = y.length, k = x.first.length + 1;
  final a = List.generate(k, (_) => List.filled(k + 1, 0.0));
  for (var r = 0; r < n; r++) {
    final row = [1.0, ...x[r]];
    for (var i = 0; i < k; i++) {
      for (var j = 0; j < k; j++) {
        a[i][j] += row[i] * row[j];
      }
      a[i][k] += row[i] * y[r];
    }
  }
  for (var i = 0; i < k; i++) {
    var p = i;
    for (var r = i + 1; r < k; r++) {
      if (a[r][i].abs() > a[p][i].abs()) p = r;
    }
    final t = a[i];
    a[i] = a[p];
    a[p] = t;
    for (var r = 0; r < k; r++) {
      if (r == i) continue;
      final f = a[r][i] / a[i][i];
      for (var c = i; c <= k; c++) {
        a[r][c] -= f * a[i][c];
      }
    }
  }
  final beta = [for (var i = 0; i < k; i++) a[i][k] / a[i][i]];
  final mean = y.reduce((p, q) => p + q) / n;
  var ssRes = 0.0, ssTot = 0.0;
  for (var r = 0; r < n; r++) {
    var f = beta[0];
    for (var i = 0; i < x[r].length; i++) {
      f += beta[i + 1] * x[r][i];
    }
    ssRes += (y[r] - f) * (y[r] - f);
    ssTot += (y[r] - mean) * (y[r] - mean);
  }
  return (beta, 1 - ssRes / ssTot);
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
  final pool = words.length > 3000 ? 3000 : words.length;
  final weightOf = {
    for (var i = 0; i < words.length; i++) words[i]: weights[i],
  };
  final first = await analyseGuesses(words, words);
  final firstFit = first; // the opening: every word fits
  final rng = Random(7);
  stdout.writeln('$code $length: ${words.length} words, $games games');

  final xs = <List<double>>[], ys = <double>[];
  for (var g = 0; g < games; g++) {
    // this player's habits for the game
    final h = List.generate(5, (_) => pow(rng.nextDouble(), 2).toDouble());
    final total = h.reduce((a, b) => a + b);
    final answer = chooseWord(
      words.sublist(0, pool),
      weights.sublist(0, pool),
      rng,
    );
    var eligible = List.of(words);
    final s = <double>[], l = <double>[], d = <double>[];
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
          guess =
              (opening ? firstFit : await analyseGuesses(eligible, eligible))
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
        weights: weightOf,
      ).withLandscape(land);
      if (m.before > 1) {
        s.add(m.skill);
        l.add(m.luck);
        d.add(m.daring ?? 0);
      }
      eligible = after;
      if (guess == answer) {
        tries = t + 1;
        break;
      }
    }
    if (s.isEmpty) continue;
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    xs.add([mean(s), mean(l), mean(d)]);
    ys.add(tries.toDouble());
  }

  stdout.writeln(
    '${ys.length} games with a choice in them; tries mean '
    '${(ys.reduce((a, b) => a + b) / ys.length).toStringAsFixed(2)}',
  );
  void fit(String name, List<int> cols) {
    final (beta, r2) = ols([
      for (final x in xs) [for (final c in cols) x[c]],
    ], ys);
    stdout.writeln(
      '${name.padRight(24)} R^2 ${r2.toStringAsFixed(3)}  coefficients '
      '${beta.map((b) => b.toStringAsFixed(4)).join(', ')}',
    );
  }

  fit('skill', [0]);
  fit('luck', [1]);
  fit('daring', [2]);
  fit('skill + luck', [0, 1]);
  fit('skill + daring', [0, 2]);
  fit('skill + luck + daring', [0, 1, 2]);
}
