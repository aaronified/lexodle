import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_analysis.dart';
import 'package:lexodle/multi_review.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/review_plots.dart';
import 'package:lexodle/review_text.dart';
import 'package:lexodle/wiki_links.dart';
import 'package:lexodle/words.dart';

import 'support/text_of.dart';

/// Every explanation of a review screen must fit two lines on a phone.
const maxChars = 110;

void fits(String text, {String? what}) => expect(
  text.length,
  lessThanOrEqualTo(maxChars),
  reason: '${what ?? 'text'} is ${text.length} characters: "$text"',
);

GuessMetrics gm(
  String g,
  double skill,
  double luck,
  int before,
  int after, {
  double? risk,
}) => GuessMetrics(
  guess: g,
  skill: skill,
  luck: luck,
  before: before,
  after: after,
  expected: 1,
  groups: 1,
  largest: 1,
  risk: risk,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => wikiOpener = null);

  group('the shared lines', () {
    test('skill carries its number and says what it is against', () {
      expect(skillLine(82.4), startsWith('skill 82: '));
      expect(skillLine(82.4), contains('best guess\'s (100)'));
      fits(skillLine(100));
    });

    test('luck carries its sign: plus gained more, minus less', () {
      expect(luckLine(40), startsWith('luck +40: '));
      expect(luckLine(40), contains('gained more than usual'));
      expect(luckLine(-35.4), startsWith('luck −35: '));
      expect(luckLine(-35.4), contains('gained less than usual'));
      expect(luckLine(0.3), startsWith('luck 0: '));
      expect(luckLine(0.3), contains('average'));
      for (final v in [-100.0, -40.0, 0.0, 40.0, 100.0]) {
        fits(luckLine(v));
      }
    });

    test('risk and bits carry their numbers', () {
      expect(riskLine(60), startsWith('risk 60: '));
      expect(riskLine(0), startsWith('risk 0: '));
      expect(riskLine(null), startsWith('risk –: '));
      expect(bitsLine(2.345, 3), startsWith('bits 2.35: '));
      expect(bitsLine(2.345, 3), contains('cut 3.00'));
      for (final v in [null, 0.0, 60.0, 100.0]) {
        fits(riskLine(v));
      }
      fits(bitsLine(2.345, 3));
    });

    test('the fixed lines are short', () {
      for (final l in [...tableHelp, lastTryLine]) {
        fits(l);
      }
      expect(lastTryLine, contains('only a word that fits can win'));
    });
  });

  group('the step comment is a verdict and at most one fact', () {
    Recommendation rec(String w, double skill) =>
        Recommendation(w, skill, 1.1, false);
    int sentences(String t) => RegExp(r'[.!?…](\s|$)').allMatches(t).length;

    test('single game: every branch is short', () {
      final cases = <String>[
        // a top pick
        stepComment(
          m: gm('grout', 98, 0, 7, 1),
          picks: [rec('turbo', 99), rec('grout', 98)],
          after: ['grout'],
          solved: false,
        ),
        // a touch sharper, decent, missed
        for (final skill in [96.0, 90.0, 40.0])
          stepComment(
            m: gm('mamma', skill, 0, 400, 280),
            picks: [rec('rates', 99)],
            after: List.filled(280, 'x'),
            solved: false,
          ),
        // few words left, lucky, unlucky
        stepComment(
          m: gm('crane', 80, 50, 300, 4),
          picks: [rec('rates', 90)],
          after: ['abcde', 'fghij', 'klmno', 'pqrst'],
          solved: false,
        ),
        stepComment(
          m: gm('crane', 80, 50, 300, 90),
          picks: [rec('rates', 90)],
          after: List.filled(90, 'x'),
          solved: false,
        ),
        stepComment(
          m: gm('crane', 80, -50, 300, 200),
          picks: [rec('rates', 90)],
          after: List.filled(200, 'x'),
          solved: false,
        ),
        // solved, nothing left to compare, last try in each form
        stepComment(
          m: gm('a', 100, 0, 1, 1),
          picks: [],
          after: ['a'],
          solved: true,
        ),
        stepComment(
          m: gm('a', 100, 0, 1, 1),
          picks: [],
          after: ['a'],
          solved: false,
        ),
        for (final (fit, eq, possible) in [
          (true, true, true),
          (true, false, true),
          (false, true, true),
          (true, true, false),
        ])
          stepComment(
            m: gm('grout', 40, 0, 12, 1),
            picks: [rec('turbo', 90)],
            after: ['grout'],
            solved: false,
            finalTry: true,
            guessFits: fit,
            equalChances: eq,
            guessIsPossible: possible,
          ),
      ];
      for (final t in cases) {
        fits(t, what: 'comment');
        expect(sentences(t), lessThanOrEqualTo(2), reason: t);
      }
    });

    test('multi: every branch is short', () {
      MultiStep step(List<BoardStep> boards, {bool finalTry = false}) =>
          MultiStep('crane', boards, [
            for (final _ in boards) const <String>[],
          ], finalTry: finalTry);
      final cases = <String>[
        for (final skill in [100.0, 96.0, 90.0, 40.0])
          multiComment(
            step([
              BoardStep(0, gm('crane', skill, 0, 400, 100), false),
              BoardStep(1, gm('crane', skill, 0, 400, 100), false),
            ]),
            bestWord: 'rates',
            bestSkill: 100,
          ),
        // everything at once: two solved, a wide spread, lucky
        multiComment(
          step([
            BoardStep(0, gm('crane', 100, 0, 5, 1), true),
            BoardStep(1, gm('crane', 100, 0, 5, 1), true),
            BoardStep(2, gm('crane', 90, 60, 400, 20), false),
            BoardStep(3, gm('crane', 20, 60, 400, 200), false),
          ]),
          bestWord: 'rates',
          bestSkill: 20,
        ),
        multiComment(step(const []), ready: false),
        for (final mine in [0.0, 1.5])
          multiComment(
            step([
              BoardStep(0, gm('crane', 0, 0, 5, 1), false),
              BoardStep(1, gm('crane', 0, 0, 5, 1), false),
            ], finalTry: true),
            yourSolved: mine,
            bestFinalWord: 'house',
            bestSolved: 2.0,
          ),
      ];
      for (final t in cases) {
        fits(t, what: 'multi comment');
        expect(sentences(t), lessThanOrEqualTo(2), reason: t);
      }
    });

    test('multi: the one fact that is shown', () {
      MultiStep step(List<BoardStep> b) => MultiStep('crane', b, [
        for (final _ in b) const <String>[],
      ], finalTry: false);
      final t = multiComment(
        step([
          BoardStep(0, gm('crane', 100, 0, 5, 1), true),
          BoardStep(1, gm('crane', 70, 60, 400, 20), false),
        ]),
        bestWord: 'rates',
        bestSkill: 70,
      );
      expect(t, startsWith('Terrific choice'));
      expect(t, endsWith('It solved board 1.'));
    });
  });

  group('the plots', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );
    testWidgets('the last-try plot: the line, the chance, a link', (
      tester,
    ) async {
      Uri? opened;
      wikiOpener = (u) async {
        opened = u;
        return true;
      };
      await tester.pumpWidget(
        host(const EqualChancePlot(fitting: 3, guessAt: 1, luck: -33.3)),
      );
      expect(
        textOf(
          tester.widget<Text>(find.byKey(const ValueKey('chance-caption'))),
        ),
        lastTryLine,
      );
      final luck = textOf(
        tester.widget<Text>(find.byKey(const ValueKey('chance-luck'))),
      )!;
      expect(luck, startsWith('luck −33: '));
      expect(luck, contains('3 words that fit'));
      expect(luck, contains('33% chance'));
      fits(luck);
      await tester.tap(find.byKey(const ValueKey('wiki-skillLuckRisk')));
      expect(opened, WikiPage.skillLuckRisk.uri);
    });

    testWidgets('a last try that did not fit says it had no chance', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const EqualChancePlot(fitting: 3, guessAt: -1, luck: 0)),
      );
      final luck = textOf(
        tester.widget<Text>(find.byKey(const ValueKey('chance-luck'))),
      )!;
      expect(luck, startsWith('luck 0: '));
      expect(luck, contains('did not fit'));
      fits(luck);
    });
  });

  group('the single-game review', () {
    late WordBank bank;
    late GameRecord record;

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      );
      final pool = bank.guessable(4);
      final answer = chooseWord(
        bank.answers(4),
        bank.answerWeights(4),
        Random(7),
      );
      var eligible = pool;
      final guesses = [pool[10], pool[20]];
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
            provisional: true,
          ),
        );
        befores.add(eligible);
        marks.add(m);
        eligible = after;
      }

      guesses.forEach(play);
      final third = eligible.firstWhere((w) => w != answer);
      guesses.add(third);
      play(third, last: true);
      record = GameRecord(
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
      );
    });

    Future<void> open(WidgetTester tester, int step) async {
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SizedBox()); // a fresh page each time
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: ReviewPage(record: record, initialStep: step),
        ),
      );
      await tester.pump(const Duration(seconds: 40));
    }

    const lineKeys = ['chance-caption', 'chance-luck', 'pick-each'];

    testWidgets('every explanation on every step is short', (tester) async {
      var seen = 0;
      for (var step = 0; step < 3; step++) {
        await open(tester, step);
        for (final k in lineKeys) {
          for (final e in find.byKey(ValueKey(k)).evaluate()) {
            fits(textOf(e.widget as Text)!, what: k);
            seen++;
          }
        }
        // each pill's explanation, and the step comment
        for (final k in ['skill', 'luck', 'risk', 'bits']) {
          await tester.tap(find.byKey(ValueKey('pill-$k')));
          await tester.pumpAndSettle();
          for (final e in find.byType(RichText).evaluate()) {
            final t = (e.widget as RichText).text.toPlainText();
            if (t.startsWith('$k ')) {
              fits(t, what: '$k, step $step');
              seen++;
            }
          }
          await tester.tapAt(const Offset(2, 2));
          await tester.pumpAndSettle();
        }
        for (final e in find.byType(Text).evaluate()) {
          final t = textOf(e.widget as Text) ?? '';
          if (t.startsWith('Terrific') ||
              t.startsWith('Good choice') ||
              t.startsWith('Decent') ||
              t.startsWith('A missed') ||
              t.startsWith('Last try') ||
              t.startsWith('Only ') ||
              t.startsWith('You ')) {
            fits(t, what: 'step $step');
            seen++;
          }
        }
      }
      expect(seen, greaterThan(12));
    });

    testWidgets('the numbers in the pills are the table\'s', (tester) async {
      await open(tester, 0);
      final m = record.metrics[0];
      final land = await tester.runAsync(
        () => analyseGuesses(
          record.befores[0],
          bank.guessable(4),
          answer: record.answer,
        ),
      );
      final skill = m.withLandscape(land!).skill.round();
      expect(
        textOf(
          tester.widget<Text>(find.byKey(const ValueKey('pill-value-skill'))),
        ),
        '$skill',
      );
      await tester.tap(find.byKey(const ValueKey('pill-luck')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(luckLine(m.luck).split(':').first),
        findsOneWidget,
      );
    });

    testWidgets('links open the wiki: pills, picks', (tester) async {
      final opened = <Uri>[];
      wikiOpener = (u) async {
        opened.add(u);
        return true;
      };
      await open(tester, 0);
      expect(find.byKey(const ValueKey('wiki-solverAndLearn')), findsOneWidget);
      final f = find.byKey(const ValueKey('wiki-solverAndLearn'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      expect(opened, [WikiPage.solverAndLearn.uri]);
      // each pill's explanation links to the page on skill, luck and risk
      await tester.tap(find.byKey(const ValueKey('pill-risk')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wiki-skillLuckRisk')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wiki-skillLuckRisk')));
      expect(opened.last, WikiPage.skillLuckRisk.uri);
    });

    testWidgets('the last try still links', (tester) async {
      await open(tester, 2);
      expect(find.byKey(const ValueKey('wiki-skillLuckRisk')), findsWidgets);
    });
  });

  group('the quartet and relay review', () {
    late WordBank bank;
    late List<String> words;

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      );
      words = bank.guessable(5);
    });

    Future<MultiRecord> record(
      WidgetTester tester,
      GameMode mode,
      List<String> guesses,
    ) async {
      final g = MultiGame(
        mode,
        ['house', 'light', 'brand', 'dying'],
        9,
        words: words,
      );
      for (final w in guesses) {
        g.guess(w);
      }
      final analysis = <Future<MultiLandscape>?>[];
      for (final s in g.steps) {
        final land = await tester.runAsync(
          () => analyseMulti(s.liveBefore, words.take(150)),
        );
        analysis.add(Future.value(land));
      }
      return MultiRecord(
        bank: bank,
        mode: mode,
        length: 5,
        tries: 9,
        answers: ['house', 'light', 'brand', 'dying'],
        guesses: g.guesses,
        steps: g.steps,
        won: g.won,
        analysis: analysis,
      );
    }

    Future<void> open(WidgetTester tester, MultiRecord r) async {
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: MultiReviewPage(record: r),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
    }

    for (final mode in [GameMode.quartet, GameMode.relay]) {
      testWidgets('${mode.name}: short lines and working links', (
        tester,
      ) async {
        final opened = <Uri>[];
        wikiOpener = (u) async {
          opened.add(u);
          return true;
        };
        final r = await record(tester, mode, ['crane', 'light', 'point']);
        await open(tester, r);
        // the picks always link
        expect(
          find.byKey(const ValueKey('wiki-solverAndLearn')),
          findsOneWidget,
        );
        // the help opens with short lines and its own link
        await tester.tap(find.text('explain this table'));
        await tester.pump();
        final help = [
          for (final e in find.byType(Text).evaluate())
            if (((e.widget as Text).data ?? '').startsWith(
              RegExp(r'words left:|skill:|luck:|all:|a relay|last try:|head'),
            ))
              (e.widget as Text).data!,
        ];
        expect(help.length, greaterThanOrEqualTo(5));
        for (final t in help) {
          fits(t, what: 'help');
        }
        expect(
          help.any((t) => t.startsWith('head start:')),
          mode == GameMode.relay,
        );
        final link = find.byKey(const ValueKey('wiki-skillLuckRisk'));
        expect(link, findsOneWidget);
        await tester.ensureVisible(link);
        await tester.tap(link);
        final picks = find.byKey(const ValueKey('wiki-solverAndLearn'));
        await tester.ensureVisible(picks);
        await tester.tap(picks);
        expect(opened, [
          WikiPage.skillLuckRisk.uri,
          WikiPage.solverAndLearn.uri,
        ]);
        // every step's comment and opened-board line is short
        for (var i = 0; i < r.steps.length; i++) {
          await tester.tap(find.byKey(ValueKey('guess-row-$i')));
          await tester.pump();
          fits(
            textOf(
              tester.widget<Text>(find.byKey(const ValueKey('multi-comment'))),
            )!,
            what: 'multi-comment $i',
          );
          for (final e in find.byType(Text).evaluate()) {
            final k = (e.widget as Text).key;
            if (k is ValueKey && '${k.value}'.startsWith('opened-')) {
              fits((e.widget as Text).data!, what: '${k.value}');
            }
          }
        }
      });
    }
  });
}
