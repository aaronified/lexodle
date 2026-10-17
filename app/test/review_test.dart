import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the picks share one right edge for the words and another for the skill',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      // a short game against a known answer
      final pool = bank.answers(4, 500);
      final answer = pool[3];
      var eligible = pool;
      final guesses = [pool[10], pool[20]];
      final marks = <List<Mark>>[], metrics = <GuessMetrics>[];
      final befores = <List<String>>[];
      for (final g in guesses) {
        final m = evaluate(answer, g);
        final after = filterEligible(eligible, g, m);
        metrics.add(scoreGuess(eligible, g, after.length));
        befores.add(eligible);
        marks.add(m);
        eligible = after;
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: ReviewPage(
            record: GameRecord(
              bank: bank,
              length: 4,
              poolSize: 500,
              answer: answer,
              guesses: guesses,
              marks: marks,
              metrics: metrics,
              befores: befores,
              finalEligible: eligible,
              won: false,
            ),
          ),
        ),
      );
      await tester.pump(
        const Duration(seconds: 10),
      ); // the picks are worked out

      bool isKey(Widget w, String prefix) =>
          w is Text &&
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith(prefix);
      final words = find.byWidgetPredicate((w) => isKey(w, 'pick-word-'));
      final skills = find.byWidgetPredicate((w) => isKey(w, 'pick-skill-'));
      final n = words.evaluate().length;
      expect(n, greaterThanOrEqualTo(2), reason: 'several picks are listed');
      expect(skills.evaluate().length, n);

      final wordEdges = [
        for (var i = 0; i < n; i++) tester.getTopRight(words.at(i)).dx,
      ];
      final skillEdges = [
        for (var i = 0; i < n; i++) tester.getTopRight(skills.at(i)).dx,
      ];
      // the top pick is set larger than the rest, but every word ends in the
      // same place, and every skill ends in the same place, to the right of them
      expect(wordEdges.reduce(max) - wordEdges.reduce(min), lessThan(.01));
      expect(skillEdges.reduce(max) - skillEdges.reduce(min), lessThan(.01));
      expect(skillEdges.first, greaterThan(wordEdges.first));
      // and the skill numbers are not part of the words
      for (var i = 0; i < n; i++) {
        expect(
          tester.getTopLeft(skills.at(i)).dx,
          greaterThanOrEqualTo(wordEdges[i]),
        );
      }
    },
  );
}
