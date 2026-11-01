import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/drill.dart';
import 'package:lexodle/drill_page.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.learnLog = LearnLog();
    appState.achOf('').clear();
  });

  DrillRound? finished;

  // A position is worked out in slices that give the event loop back between
  // them, so the test lets the (fake) clock run until it is on screen.
  Future<void> waitFor(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 300 && f.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f, findsOneWidget);
  }

  Future<void> open(
    WidgetTester tester, {
    LearnKind kind = LearnKind.choose,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'fr', length: 4);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    finished = null;
    await tester.pumpWidget(
      MaterialApp(
        home: DrillPage(
          bank: bank,
          kind: kind,
          seed: 7,
          onRound: (r) => finished = r,
        ),
      ),
    );
    await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
  }

  String text(WidgetTester tester, String key) =>
      textOf(tester.widget<Text>(find.byKey(ValueKey(key))))!;

  testWidgets('shows the clues, how many words fit, and four words', (
    tester,
  ) async {
    await open(tester);
    expect(text(tester, 'drill-fits'), endsWith('words fit the clues'));
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('drill-option-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('drill-option-4')), findsNothing);
    expect(find.textContaining('1 of 10'), findsOneWidget);
    // nothing is said about the answer before a pick
    expect(find.byKey(const ValueKey('drill-verdict')), findsNothing);
  });

  testWidgets('a pick says whether it was the best, and why', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('drill-option-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('drill-verdict')), findsOneWidget);
    expect(find.byKey(const ValueKey('drill-next')), findsOneWidget);
    // every option now shows its skill, one of them 'best · 100'
    expect(find.textContaining('best · 100'), findsOneWidget);
    // a second tap on another option changes nothing
    await tester.tap(
      find.byKey(const ValueKey('drill-option-1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.textContaining('best · 100'), findsOneWidget);
  });

  testWidgets('ten picks make a round with a score, reported once', (
    tester,
  ) async {
    await open(tester);
    for (var q = 1; q <= drillRoundLength; q++) {
      expect(find.textContaining('$q of 10'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('drill-option-0')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('drill-next')));
      await tester.tap(find.byKey(const ValueKey('drill-next')));
      await tester.pump();
      if (q < drillRoundLength) {
        await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
      }
    }
    expect(finished, isNotNull);
    expect(finished!.answers, hasLength(drillRoundLength));
    expect(finished!.language, 'fr');
    expect(finished!.length, 4);
    final score = text(tester, 'drill-score');
    expect(score, '${finished!.right} of 10 right');
    // the first round ever earns the first level of choose the best
    expect(find.byKey(const ValueKey('earned-rows')), findsOneWidget);
    expect(find.textContaining('first round'), findsOneWidget);
    expect(
      text(tester, 'drill-average'),
      'average skill ${finished!.averageSkill.round()}',
    );
    // another round starts over
    await tester.ensureVisible(find.byKey(const ValueKey('drill-again')));
    await tester.tap(find.byKey(const ValueKey('drill-again')));
    await tester.pump();
    await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
    expect(find.textContaining('1 of 10'), findsOneWidget);
  });

  testWidgets('the groups of every option can be shown, with their sums', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('drill-calc')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('drill-option-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('drill-calculations')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('drill-calc')));
    await tester.tap(find.byKey(const ValueKey('drill-calc')));
    await tester.pump();
    expect(find.byKey(const ValueKey('drill-calculations')), findsOneWidget);
    // one walk for each of the four options, each with its sums
    expect(find.byKey(const ValueKey('drill-calc')), findsOneWidget);
    final sums = find.byWidgetPredicate(
      (w) => w.key.toString().contains('drill-sums-'),
    );
    expect(sums, findsNWidgets(4));
    final lines = [
      for (final e in sums.evaluate()) textOf((e.widget as Text))!,
    ];
    // the best guess is 100 of itself: expected bits over the best's own
    expect(lines.where((l) => l.endsWith('= 100')), hasLength(1));
    for (final l in lines) {
      expect(l, contains('groups · words left on average'));
      expect(l, contains('expected bits'));
    }
    expect(find.textContaining('← the answer was here'), findsNWidgets(4));
    // hiding it, and the next position starts without it
    await tester.tap(find.byKey(const ValueKey('drill-calc')));
    await tester.pump();
    expect(find.byKey(const ValueKey('drill-calculations')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('drill-calc')));
    await tester.pump();
    // the panel is long: the next button is below it
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drill-next')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('drill-next')));
    await tester.pump();
    await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
    expect(find.byKey(const ValueKey('drill-calculations')), findsNothing);
    expect(find.byKey(const ValueKey('drill-calc')), findsNothing);
    // the position after this one is being built: let it finish
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('a finished round goes in the learn log, once', (tester) async {
    await open(tester);
    for (var q = 1; q <= drillRoundLength; q++) {
      await tester.tap(find.byKey(const ValueKey('drill-option-0')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('drill-next')));
      await tester.tap(find.byKey(const ValueKey('drill-next')));
      await tester.pump();
      if (q < drillRoundLength) {
        expect(appState.learnLog.events, isEmpty, reason: 'not before the end');
        await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
      }
    }
    final e = appState.learnLog.events.single;
    expect(e.kind, LearnKind.choose);
    expect(e.language, 'fr');
    expect(e.length, 4);
    expect(e.questions, drillRoundLength);
    expect(e.right, finished!.right);
    expect(e.avgSkill, closeTo(finished!.averageSkill, 0.1));
  });

  testWidgets('closing: tries left, the chance each wins, and a logged round', (
    tester,
  ) async {
    await open(tester, kind: LearnKind.closing);
    expect(find.textContaining('closing'), findsWidgets);
    expect(find.textContaining('1 of 10'), findsOneWidget);
    expect(
      find.textContaining('tries left (this one included)'),
      findsOneWidget,
    );
    // no groups button: the explanation is the groups
    for (var q = 1; q <= drillRoundLength; q++) {
      await tester.tap(find.byKey(const ValueKey('drill-option-0')));
      await tester.pump();
      // every option shows the chance it wins in time, one marked the best
      expect(find.textContaining('wins '), findsWidgets);
      expect(find.textContaining('best · wins '), findsWidgets);
      expect(find.byKey(const ValueKey('drill-calc')), findsNothing);
      expect(find.textContaining('wins within'), findsWidgets);
      await tester.ensureVisible(find.byKey(const ValueKey('drill-next')));
      await tester.tap(find.byKey(const ValueKey('drill-next')));
      await tester.pump();
      if (q < drillRoundLength) {
        await waitFor(tester, find.byKey(const ValueKey('drill-option-0')));
      }
    }
    expect(text(tester, 'drill-score'), '${finished!.right} of 10 right');
    final e = appState.learnLog.events.single;
    expect(e.kind, LearnKind.closing);
    expect(e.questions, drillRoundLength);
  });

  test('a round counts its right answers and averages the skill', () {
    final round = DrillRound('fr', 4, [
      const DrillAnswer('a', 100, true),
      const DrillAnswer('b', 50, false),
      const DrillAnswer('c', 80, false),
    ]);
    expect(round.right, 1);
    expect(round.averageSkill, closeTo(76.67, 0.01));
    expect(round.complete, isFalse);
    expect(const DrillRound('fr', 4, []).averageSkill, 0);
  });
}
