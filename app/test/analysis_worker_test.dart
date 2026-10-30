import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis_worker.dart';
import 'package:lexodle/logic.dart';

void main() {
  setUp(() => analyseOffMainThread = true);
  tearDown(() => analyseOffMainThread = false);

  List<String> words(int n, int seed) {
    final rng = Random(seed);
    return {
      for (var i = 0; i < n; i++)
        String.fromCharCodes(List.generate(5, (_) => 97 + rng.nextInt(26))),
    }.toList();
  }

  test('the worker gives the numbers the main thread gives', () async {
    final w = words(300, 1);
    final law = {for (final x in w) x: 1 + x.codeUnitAt(0)};
    final here = await analyseGuesses(w, w, weights: law, answer: w[7]);
    final there = await analyseOffThread(w, w, weights: law, answer: w[7]);
    expect(there.bestGain, here.bestGain);
    expect(there.bestRisk, here.bestRisk);
    expect(there.gains, here.gains);
    expect(there.top.map((r) => r.word), here.top.map((r) => r.word));
    expect(
      there.luckiest.map((p) => (p.word, p.luck)),
      here.luckiest.map((p) => (p.word, p.luck)),
    );
  });

  test('replies find their own asker when several are outstanding', () async {
    final a = words(120, 2), b = words(90, 3);
    final out = await Future.wait([
      analyseOffThread(a, a, answer: a[1]),
      analyseOffThread(b, b, answer: b[1]),
      analyseOffThread(a, a, answer: a[2]),
    ]);
    expect(out[0].gains.length, a.length);
    expect(out[1].gains.length, b.length);
    expect(out[2].luckiest.first.word, a[2]);
    expect(out[0].luckiest.first.word, a[1]);
  });

  test('warming an opening does not disturb the next analysis', () async {
    final w = words(2100, 4);
    warmOpening(w, w);
    var land = await analyseOffThread(w, w, answer: w[5]);
    // an opening kept on the disk has no luckiest guesses: they are asked for
    if (land.partial) {
      land = await analyseOffThread(w, w, answer: w[5], useDisk: false);
    }
    expect(land.luckiest.first.word, w[5]);
    expect(land.gains.length, w.length);
  });
}
