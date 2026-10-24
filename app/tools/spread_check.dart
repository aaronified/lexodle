// How are skill, luck and daring spread over the options in a position? For a
// few positions of a real game this prints, over every guess the game accepts
// (the options for skill and daring) and over every possible answer (the
// options for luck), how much of each lands in each tenth of its scale. Pure
// Dart, run from the app folder:
//
//   dart run tools/spread_check.dart [code] [length]
import 'dart:io';
import 'dart:math';

import 'package:lexodle/logic.dart';

String bars(
  List<double> values,
  double lo,
  double hi, {
  List<double>? weights,
}) {
  const bins = 10;
  final counts = List<double>.filled(bins, 0);
  var total = 0.0;
  for (var i = 0; i < values.length; i++) {
    final w = weights?[i] ?? 1;
    final b = (((values[i] - lo) / (hi - lo)) * bins).floor().clamp(
      0,
      bins - 1,
    );
    counts[b] += w;
    total += w;
  }
  return counts
      .map((c) => (c / total * 100).round().toString().padLeft(3))
      .join(' ');
}

void main(List<String> args) {
  final code = args.isNotEmpty ? args[0] : 'en';
  final length = args.length > 1 ? int.parse(args[1]) : 5;
  final words = <String>[];
  final weights = <String, int>{};
  for (final line in File('assets/words/$code.txt').readAsLinesSync()) {
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    final w = line.substring(0, tab);
    if (w.length != length) continue;
    words.add(w);
    weights[w] = int.parse(line.substring(tab + 1));
  }
  final rng = Random(5);
  final pool = words.take(3000).toList();
  final answers = [for (var i = 0; i < 4; i++) pool[rng.nextInt(pool.length)]];
  stdout.writeln('$code $length: ${words.length} words; answers $answers\n');
  stdout.writeln('each row: share of the options in each tenth of the scale');
  stdout.writeln(
    'skill and daring (raw) 0..100; rank daring and luck -100..100\n',
  );

  for (final answer in answers.take(2)) {
    var eligible = List.of(words);
    final plays = [
      'tares',
      'clint',
      'moody',
    ].where((w) => words.contains(w)).toList();
    for (var step = 0; step <= 2; step++) {
      final n = eligible.length;
      if (n < 3) break;
      for (final tries in [6 - step, 2]) {
        if (tries < 1) continue;
        // every option: its split, skill, and the raw daring of going for it
        final possible = eligible.toSet();
        var total = 0;
        for (final w in eligible) {
          total += weights[w]!;
        }
        final sums = <int>[];
        for (final w in words) {
          sums.add(splitSumSquares(eligible, w));
        }
        final best = sums.reduce(min) / n;
        final skills = <double>[];
        final raws = <double>[];
        for (var i = 0; i < words.length; i++) {
          final w = words[i];
          final skill = n <= 1 ? 100.0 : skillAgainst(n, sums[i] / n, best);
          skills.add(skill);
          raws.add(
            daringOf(
              possible: possible.contains(w),
              winChance: possible.contains(w) ? weights[w]! / total : 0,
              skill: skill,
              triesLeft: tries,
            ),
          );
        }
        // rank daring: the share of options less daring minus the share more
        double rank(double r) {
          var less = 0, more = 0;
          for (final x in raws) {
            if (x < r - 1e-9) less++;
            if (x > r + 1e-9) more++;
          }
          return (less - more) / raws.length * 100;
        }

        final ranked = [for (final r in raws) rank(r)];
        stdout.writeln(
          'answer $answer, after $step guesses: $n words left, $tries tries left',
        );
        stdout.writeln('  skill        ${bars(skills, 0, 100)}');
        stdout.writeln('  raw daring   ${bars(raws, 0, 100)}');
        stdout.writeln('  rank daring  ${bars(ranked, -100, 100)}');
        // luck over the possible answers, for a middling guess and the best one
        for (final (label, idx) in [
          ('best guess', sums.indexOf(sums.reduce(min))),
          (
            'median guess',
            (() {
              final order = List.generate(words.length, (i) => i)
                ..sort((a, b) => sums[a].compareTo(sums[b]));
              return order[order.length ~/ 2];
            })(),
          ),
        ]) {
          final guess = words[idx];
          final sizes = <int, int>{};
          final byAnswer = <String, int>{};
          for (final w in eligible) {
            final k = patternCode(w, guess);
            sizes[k] = (sizes[k] ?? 0) + 1;
            byAnswer[w] = k;
          }
          final groupSizes = sizes.values.toList();
          final lucks = <double>[];
          final ws = <double>[];
          for (final entry in sizes.entries) {
            final c = entry.value;
            // luck of landing in a group of c words, as the app has it
            final out = chanceLuck(groupSizes, c);
            lucks.add(out);
            ws.add(c.toDouble());
          }
          stdout.writeln(
            '  luck, $label ($guess)  ${bars(lucks, -100, 100, weights: ws)}',
          );
        }
        stdout.writeln('');
        if (tries != 2) continue;
      }
      // play on: the next guess is the first of the usual openers, filtered
      if (step < plays.length) {
        final g = plays[step];
        eligible = filterEligible(eligible, g, evaluate(answer, g));
      }
    }
  }
}
