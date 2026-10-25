// Do skill, luck and daring, as logic.dart now scores them under an answer law,
// spread over their ranges and together predict the tries a game takes?
//
// Plays simulated players of mixed habits (as predict_tries2.dart) against
// answers drawn by one law and scores every guess with the app's own maths:
//
//   u   every word of the length equally likely (frequency off)
//   f   each word by how common it is (frequency on)
//   d   the daily: the 3,000 most common words, equally likely, no others
//
// The game's tries are fitted on the means of its guesses' skill, luck and
// daring using the first half of the games; R^2 is read on the second half,
// which the fit never saw. Also printed: how evenly each score fills its range
// (the share of all guesses in each tenth), the correlations between the three
// and their variance inflation factors. Run from app:
//
//   dart run tools/predict_tries3.dart [law] [code] [length] [games]
import 'dart:io';
import 'dart:math';

import 'package:lexodle/logic.dart';

import 'predict_tries.dart' show ols;

double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

double _corr(List<double> a, List<double> b) {
  final ma = _mean(a), mb = _mean(b);
  var sab = 0.0, saa = 0.0, sbb = 0.0;
  for (var i = 0; i < a.length; i++) {
    sab += (a[i] - ma) * (b[i] - mb);
    saa += (a[i] - ma) * (a[i] - ma);
    sbb += (b[i] - mb) * (b[i] - mb);
  }
  return sab / sqrt(saa * sbb);
}

/// The variance inflation factors of the columns of [x]: the diagonal of the
/// inverse of their correlation matrix (3 columns, by cofactors).
List<double> _vifs(List<List<double>> cols) {
  final r = [
    for (final a in cols) [for (final b in cols) _corr(a, b)],
  ];
  final det =
      r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1]) -
      r[0][1] * (r[1][0] * r[2][2] - r[1][2] * r[2][0]) +
      r[0][2] * (r[1][0] * r[2][1] - r[1][1] * r[2][0]);
  return [
    (r[1][1] * r[2][2] - r[1][2] * r[2][1]) / det,
    (r[0][0] * r[2][2] - r[0][2] * r[2][0]) / det,
    (r[0][0] * r[1][1] - r[0][1] * r[1][0]) / det,
  ];
}

Future<void> main(List<String> args) async {
  final law = args.isNotEmpty ? args[0] : 'f';
  final code = args.length > 1 ? args[1] : 'en';
  final length = args.length > 2 ? int.parse(args[2]) : 5;
  final games = args.length > 3 ? int.parse(args[3]) : 2000;

  final all = <String>[];
  final wts = <int>[];
  for (final line in File('assets/words/$code.txt').readAsLinesSync()) {
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    final w = line.substring(0, tab);
    if (w.length != length) continue;
    all.add(w);
    wts.add(int.parse(line.substring(tab + 1)));
  }
  // the words an answer can be, and the weights the scores use for them
  final support = law == 'd' ? all.take(min(3000, all.length)).toList() : all;
  final weightMap = law == 'f'
      ? {for (var i = 0; i < all.length; i++) all[i]: wts[i]}
      : null;
  final drawWeights = law == 'f' ? wts : List<int>.filled(support.length, 1);
  final rng = Random(23);
  stdout.writeln(
    'law $law, $code $length: ${all.length} words, '
    '${support.length} possible answers, $games games',
  );

  // the opening position is the same every game: work it out once
  final first = await analyseGuesses(support, all, weights: weightMap);
  final firstSelf = await analyseGuesses(support, support, weights: weightMap);

  final pooled = <String, List<double>>{'skill': [], 'luck': [], 'daring': []};
  final xs = <List<double>>[], ys = <double>[];
  for (var g = 0; g < games; g++) {
    final h = List.generate(5, (_) => pow(rng.nextDouble(), 2).toDouble());
    final total = h.reduce((a, b) => a + b);
    final answer = chooseWord(support, drawWeights, rng);
    var eligible = List.of(support);
    final per = <String, List<double>>{for (final k in pooled.keys) k: []};
    var tries = 7;
    for (var t = 0; t < 6; t++) {
      var roll = rng.nextDouble() * total, habit = 0;
      while (habit < 4 && roll >= h[habit]) {
        roll -= h[habit++];
      }
      final opening = t == 0;
      final land = opening
          ? first
          : await analyseGuesses(eligible, all, weights: weightMap);
      final String guess;
      switch (habit) {
        case 0:
          guess = land.top.first.word;
        case 1:
          guess =
              (opening
                      ? firstSelf
                      : await analyseGuesses(
                          eligible,
                          eligible,
                          weights: weightMap,
                        ))
                  .top
                  .first
                  .word;
        case 2:
          guess = eligible.first;
        case 3:
          guess = eligible[rng.nextInt(eligible.length)];
        default:
          guess = all[rng.nextInt(min(all.length, 400))];
      }
      final after = filterEligible(eligible, guess, evaluate(answer, guess));
      final m = scoreGuess(
        eligible,
        guess,
        after.length,
        finalTry: t == 5,
        solved: guess == answer,
        triesLeft: 6 - t,
        weights: weightMap,
        afterWords: after,
      ).withLandscape(land);
      if (eligible.length > 1 && m.daring != null) {
        per['skill']!.add(m.skill);
        per['luck']!.add(m.luck);
        per['daring']!.add(m.daring!);
        pooled['skill']!.add(m.skill);
        pooled['luck']!.add(m.luck);
        pooled['daring']!.add(m.daring!);
      }
      eligible = after;
      if (guess == answer) {
        tries = t + 1;
        break;
      }
    }
    if (per['skill']!.isEmpty) continue;
    xs.add([for (final k in pooled.keys) _mean(per[k]!)]);
    ys.add(tries.toDouble());
  }

  stdout.writeln('\nshare of all guesses in each tenth of the scale:');
  const ranges = {
    'skill': (0.0, 100.0),
    'luck': (-100.0, 100.0),
    'daring': (0.0, 100.0),
  };
  for (final e in pooled.entries) {
    final (lo, hi) = ranges[e.key]!;
    final counts = List<int>.filled(10, 0);
    for (final v in e.value) {
      counts[(((v - lo) / (hi - lo)) * 10).floor().clamp(0, 9)]++;
    }
    stdout.writeln(
      '  ${e.key.padRight(8)} '
      '${counts.map((c) => (c / e.value.length * 100).round().toString().padLeft(3)).join(' ')}'
      '   mean ${_mean(e.value).toStringAsFixed(1)}',
    );
  }

  final n = ys.length;
  final cut = n ~/ 2;
  stdout.writeln(
    '\n$n games (fit on $cut, read on ${n - cut}); '
    'tries mean ${_mean(ys).toStringAsFixed(2)}, '
    'lost ${(ys.where((y) => y > 6).length / n * 100).toStringAsFixed(1)}%',
  );
  final keys = pooled.keys.toList();
  void fit(String name, List<String> cols) {
    final c = [for (final k in cols) keys.indexOf(k)];
    List<List<double>> rows(int from, int to) => [
      for (var i = from; i < to; i++) [for (final j in c) xs[i][j]],
    ];
    final (beta, rIn) = ols(rows(0, cut), ys.sublist(0, cut));
    final test = rows(cut, n);
    final yt = ys.sublist(cut);
    final my = _mean(yt);
    var ssRes = 0.0, ssTot = 0.0;
    for (var i = 0; i < test.length; i++) {
      var p = beta[0];
      for (var j = 0; j < c.length; j++) {
        p += beta[j + 1] * test[i][j];
      }
      ssRes += (yt[i] - p) * (yt[i] - p);
      ssTot += (yt[i] - my) * (yt[i] - my);
    }
    stdout.writeln(
      '${name.padRight(26)} R^2 fit ${rIn.toStringAsFixed(3)}  '
      'held out ${(1 - ssRes / ssTot).toStringAsFixed(3)}  '
      '${beta.map((b) => b.toStringAsFixed(4)).join(', ')}',
    );
  }

  fit('skill', ['skill']);
  fit('luck', ['luck']);
  fit('daring', ['daring']);
  fit('skill + luck', ['skill', 'luck']);
  fit('skill + luck + daring', ['skill', 'luck', 'daring']);

  final cols = [
    for (final k in keys) [for (final x in xs) x[keys.indexOf(k)]],
  ];
  stdout.writeln('\ncorrelations of the game means:');
  for (var i = 0; i < 3; i++) {
    for (var j = i + 1; j < 3; j++) {
      stdout.writeln(
        '  ${keys[i]} ~ ${keys[j]}  ${_corr(cols[i], cols[j]).toStringAsFixed(3)}',
      );
    }
  }
  final v = _vifs(cols);
  stdout.writeln(
    'VIF  ${[for (var i = 0; i < 3; i++) '${keys[i]} ${v[i].toStringAsFixed(2)}'].join('  ')}',
  );
}
