import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final pool = bank.answers(4);
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

  testWidgets(
    'on the last try the picks are only words that fit the clues, all equal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      final pool = bank.answers(4);
      final answer = pool[3];
      var eligible = pool;
      // three tries, the last one a word that still fits the clues
      final g1 = pool[10], g2 = pool[20];
      final guesses = [g1, g2];
      final marks = <List<Mark>>[], metrics = <GuessMetrics>[];
      final befores = <List<String>>[];
      void play(String g, {bool last = false}) {
        final m = evaluate(answer, g);
        final after = filterEligible(eligible, g, m);
        metrics.add(
          scoreGuess(
            eligible,
            g,
            after.length,
            finalTry: last,
            solved: g == answer,
          ),
        );
        befores.add(eligible);
        marks.add(m);
        eligible = after;
      }

      guesses.forEach(play);
      final third = eligible.firstWhere((w) => w != answer);
      guesses.add(third);
      final fitting = List.of(eligible);
      play(third, last: true);
      expect(fitting.length, greaterThan(2), reason: 'several words fit');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: ReviewPage(
            initialStep: 2,
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
              tries: 3,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 10));

      bool isPick(Widget w) =>
          w is Text &&
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('pick-word-');
      final shown = [
        for (final e in find.byWidgetPredicate(isPick).evaluate())
          ((e.widget as Text).key as ValueKey).value.toString().substring(
            'pick-word-'.length,
          ),
      ];
      expect(shown, isNotEmpty);
      for (final w in shown) {
        expect(fitting, contains(w), reason: '$w does not fit the clues');
      }
      // at most three, as on every other step
      expect(shown.length, min(fitting.length, 3));
      expect(find.byKey(const ValueKey('pick-each')), findsOneWidget);
      expect(
        find.textContaining('equally likely'),
        findsNWidgets(2),
      ); // note and comment
      // all at the same chance, 1 in the number that fit
      final chance = 100 / fitting.length;
      final shownChance = chance < 10
          ? '${chance.toStringAsFixed(1)}%'
          : '${chance.round()}%';
      for (final w in shown) {
        final t = tester.widget<Text>(find.byKey(ValueKey('pick-skill-$w')));
        expect(t.data, shownChance);
      }
      // luck at the last try is the chance of the pick, not the pool landed in
      expect(
        metrics.last.luck,
        closeTo(-100 / fitting.length, 1e-9),
        reason: 'a wrong pick among n words: minus the 1 in n chance',
      );
      expect(find.textContaining('This was your last try'), findsOneWidget);
      // the plot of the possible words is on the last step...
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
      // the earlier steps keep the ranked picks (words that split best)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.byKey(const ValueKey('pick-each')), findsNothing);
      // ...and on every step
      expect(find.byKey(const ValueKey('freq-plot')), findsOneWidget);
    },
  );
}
