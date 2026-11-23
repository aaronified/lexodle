import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/guess_quiz.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('questions of both kinds are real and have one right option', (
    tester,
  ) async {
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    for (final kind in GuessKind.values) {
      for (final seed in [1, 2]) {
        final q = buildGuessQuestion(
          bank: bank,
          length: 5,
          draw: Draw.sigmoid,
          rng: Random(seed),
          kind: kind,
        );
        expect(q, isNotNull, reason: '$kind $seed');
        q!;
        expect(q.eligible.length, inInclusiveRange(40, 500));
        expect(q.eligible, contains(q.answer));
        expect(q.options.map((o) => o.word).toSet().length, 4);
        expect(evaluate(q.answer, q.first), q.marks);
        final right = q.right;
        if (kind == GuessKind.skill) {
          for (final o in q.options.where((o) => o != right)) {
            expect(o.h, lessThan(right.h));
          }
          expect(right.skill, closeTo(100, 1e-6));
        } else {
          expect(q.options.any((o) => o.word == q.answer), isFalse);
          for (final o in q.options.where((o) => o != right)) {
            expect(o.luck, lessThan(right.luck));
          }
          final plot = q.plotOf(right);
          expect(plot.landed, isNotNull);
        }
      }
    }
  });
}
