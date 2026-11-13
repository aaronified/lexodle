import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'seenHowTo': true,
      'dailyIntroSeen': true,
    }),
  );

  group('the modes', () {
    test(
      'the loop: themed last, blind after lockdown, mastermind before it',
      () {
        expect(GameMode.loopFor('en'), [
          GameMode.classic,
          GameMode.quartet,
          GameMode.relay,
          GameMode.lockdown,
          GameMode.blind,
          GameMode.equations,
          GameMode.mastermind,
          GameMode.themed,
        ]);
        expect(GameMode.loopFor('fr').last, GameMode.mastermind);
      },
    );

    test('saved modes keep their place: the new ones come after the old', () {
      expect(GameMode.classic.index, 0);
      expect(GameMode.themed.index, 4);
      expect(GameMode.blind.index, 5);
      expect(GameMode.equations.index, 6);
      expect(GameMode.mastermind.index, 7);
    });

    test('every mode has a daily, the mastermind and themed ones too', () {
      for (final m in GameMode.values) {
        expect(m.hasDaily, isTrue, reason: '$m');
      }
      expect(GameMode.mastermind.endless, isTrue);
    });
  });

  group('the equations', () {
    test('what makes a guess not an equation', () {
      expect(equationProblem('1+2=3'), isNull);
      expect(equationProblem('12+34=46'), isNull);
      expect(equationProblem('6/4*2=3'), isNull);
      expect(equationProblem('48-6=42'), isNull);
      expect(equationProblem('1+2'), 'needs exactly one =');
      expect(equationProblem('1=1=1'), 'needs exactly one =');
      expect(equationProblem('1+2=3+0'), 'the right of = is one number');
      expect(equationProblem('+1+2=3'), 'check the signs');
      expect(equationProblem('1++2=3'), 'check the signs');
      expect(equationProblem('12=12'), 'needs a sum on the left');
      expect(equationProblem('01+2=3'), 'no number starts with 0');
      expect(equationProblem('5/0+1=1'), 'no dividing by 0');
      expect(equationProblem('2+2=5'), 'both sides must be equal');
      // the order of operations: 2+3*4 is 14, not 20
      expect(equationProblem('2+3*4=14'), isNull);
      expect(equationProblem('2+3*4=20'), 'both sides must be equal');
      expect(equationProblem('5+0=5'), 'a lone 0 is not allowed');
      // × and ÷ before + and −, each kind left to right
      expect(equationProblem('10-3+2=9'), isNull);
      expect(equationProblem('10-3+2=5'), 'both sides must be equal');
      expect(equationProblem('8/2*4=16'), isNull);
      expect(equationProblem('2+8/4=4'), isNull);
      // no number starts with 0
      for (final bad in ['05+3=8', '5+03=8', '12+3=015', '3*04=12']) {
        expect(equationProblem(bad), isNotNull, reason: bad);
      }
    });

    test('every equation of the lists is one, of the length of its list', () {
      final counts = {6: 206, 7: 6371, 8: 17356};
      for (final n in equationLengths) {
        final lines = File('assets/equations/$n.txt')
            .readAsLinesSync()
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines.length, counts[n], reason: '$n tiles');
        expect(lines.toSet().length, lines.length);
        for (final l in lines) {
          expect(l.length, n, reason: l);
          expect(equationProblem(l), isNull, reason: l);
        }
      }
    });

    test('the daily is one equation of 8 tiles, the same on a date', () async {
      final langs = await WordBank.languages();
      final bank = await Equations.load(langs.first);
      final a = Daily.of(bank, '2026-11-04', GameMode.equations)!;
      final b = Daily.of(bank, '2026-11-04', GameMode.equations)!;
      expect(a.answer, b.answer);
      expect(a.length, 8);
      expect(a.tries, 5);
      expect(bank.valid, contains(a.answer));
      expect(equationProblem(a.answer), isNull);
      // it is the same in another language
      final other = await Equations.load(
        langs.firstWhere((l) => l.code == 'fr'),
      );
      expect(
        Daily.of(other, '2026-11-04', GameMode.equations)!.answer,
        a.answer,
      );
      // and not the same every day
      final days = {
        for (var d = 1; d < 20; d++)
          Daily.of(
            bank,
            '2026-11-${d.toString().padLeft(2, '0')}',
            GameMode.equations,
          )!.answer,
      };
      expect(days.length, greaterThan(15));
      expect(dailyTriesOf(GameMode.equations), 5);
    });

    test('the bank takes every character of an equation', () async {
      final langs = await WordBank.languages();
      final bank = await Equations.load(
        langs.firstWhere((l) => l.code == 'en'),
      );
      expect(bank.letters(8), containsAll('0123456789+-*/='.split('')));
      expect(bank.resolve('1+2=3'), '1+2=3');
    });

    test('the signs are drawn as the times, divide and minus signs', () {
      expect(faceOf('*'), '×');
      expect(faceOf('/'), '÷');
      expect(faceOf('-'), '−');
      expect(faceOf('7'), '7');
      expect(typedEquationChar('x'), '*');
      expect(typedEquationChar('÷'), '/');
    });
  });

  group('warming the equations opening', () {
    test('on first use of the mode, and when its length changes', () {
      const eq = GameMode.equations;
      // chosen just now
      expect(equationsNewlyInUse(GameMode.classic, 8, eq, 8), isTrue);
      // the app opened on it
      expect(equationsNewlyInUse(null, null, eq, 8), isTrue);
      // already in use at that length: nothing to start
      expect(equationsNewlyInUse(eq, 8, eq, 8), isFalse);
      // its length changed while it is the mode
      expect(equationsNewlyInUse(eq, 8, eq, 7), isTrue);
      // another mode: not the equations' business
      expect(equationsNewlyInUse(eq, 8, GameMode.blind, 8), isFalse);
    });
  });

  group('the mastermind', () {
    const words = ['plate', 'peace', 'place', 'spate', 'stale', 'later'];

    test('a reply is what one of the words left would give', () {
      final rng = Random(3);
      for (var i = 0; i < 50; i++) {
        final m = mastermindReply(words, 'crane', rng);
        expect(
          words.any((w) => evaluate(w, 'crane').toString() == m.toString()),
          isTrue,
        );
      }
    });

    test('a bucket is as likely as it is big', () {
      // against "plate": place, plate and the rest fall in different buckets
      final rng = Random(11);
      final sizes = <String, int>{};
      for (final w in words) {
        final k = evaluate(w, 'plate').toString();
        sizes[k] = (sizes[k] ?? 0) + 1;
      }
      final seen = <String, int>{};
      const n = 6000;
      for (var i = 0; i < n; i++) {
        final k = mastermindReply(words, 'plate', rng).toString();
        seen[k] = (seen[k] ?? 0) + 1;
      }
      expect(seen.keys.toSet(), sizes.keys.toSet());
      for (final e in sizes.entries) {
        expect(seen[e.key]! / n, closeTo(e.value / words.length, .03));
      }
    });

    test('the all green reply is the guess alone: it ends the game', () {
      expect(
        mastermindReply(['plate'], 'plate', Random(1)),
        everyElement(Mark.correct),
      );
      // with one word left every other guess is told what that word gives
      expect(
        mastermindReply(['plate'], 'place', Random(1)),
        evaluate('plate', 'place'),
      );
    });

    test('the largest pool: the bucket with most words, no chance', () {
      // against "plate": the sizes of the buckets decide
      final sizes = <String, int>{};
      for (final w in words) {
        final k = evaluate(w, 'plate').toString();
        sizes[k] = (sizes[k] ?? 0) + 1;
      }
      final top = sizes.values.reduce(max);
      final m = mastermindLargest(words, 'plate');
      expect(sizes[m.toString()], top);
      // the same every time
      for (var i = 0; i < 5; i++) {
        expect(mastermindLargest(words, 'plate').toString(), m.toString());
      }
    });

    test(
      'the largest pool never says all green while another reply is left',
      () {
        // two words: the guess and one other, buckets of one each: not green
        final m = mastermindLargest(['plate', 'place'], 'plate');
        expect(m, evaluate('place', 'plate'));
        // alone it has to
        expect(
          mastermindLargest(['plate'], 'plate'),
          everyElement(Mark.correct),
        );
      },
    );

    test('a tie goes to the fewest greens, then the fewest yellows', () {
      // against "abcde": bbbbb has a green (and the rest grey); edcba has the
      // letters all present with one green; xxxxx is all grey: three buckets of
      // one, so the all grey one wins on fewest greens, then yellows
      final m = mastermindLargest(['abbbb', 'edcba', 'xxxxx'], 'abcde');
      expect(m, evaluate('xxxxx', 'abcde'));
    });

    test('a largest-pool game ends, on the word it kept', () async {
      final langs = await WordBank.languages();
      final bank = await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
      var left = List.of(bank.guessable(5));
      final rng = Random(4);
      var n = 0;
      while (true) {
        n++;
        expect(n, lessThan(80));
        final g = left[rng.nextInt(left.length)];
        final m = mastermindLargest(left, g);
        left = filterEligible(left, g, m);
        expect(left, isNotEmpty);
        if (m.every((x) => x == Mark.correct)) break;
      }
    });

    test('a game always ends, on a word that fits every reply', () async {
      final langs = await WordBank.languages();
      final bank = await WordBank.load(langs.firstWhere((l) => l.code == 'en'));
      final all = bank.guessable(5);
      for (var seed = 0; seed < 5; seed++) {
        final rng = Random(seed);
        var left = List.of(all);
        final replies = <(String, List<Mark>)>[];
        var n = 0;
        while (true) {
          n++;
          expect(n, lessThan(60));
          // a player: any word that fits what was said
          final g = left[rng.nextInt(left.length)];
          final m = mastermindReply(left, g, rng);
          replies.add((g, m));
          left = filterEligible(left, g, m);
          expect(left, isNotEmpty);
          if (m.every((x) => x == Mark.correct)) break;
        }
        // the word it settled on fits every reply it gave
        final word = replies.last.$1;
        for (final (g, m) in replies) {
          expect(evaluate(word, g).toString(), m.toString());
        }
      }
    });
  });

  group('the games', () {
    Future<WordBank> frBank(WidgetTester tester) async =>
        (await tester.runAsync(
          () async => WordBank.load(
            (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
          ),
        ))!;

    Future<void> typeWord(WidgetTester tester, String w) async {
      for (final ch in w.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch,
        );
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }

    testWidgets('mastermind has no limit: a row for every guess', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(lang: 'fr', length: 4, mode: GameMode.mastermind);
      final bank = await frBank(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            random: Random(5),
            mode: GameMode.mastermind,
            practice: true,
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      // one row, to be typed; no tries to count down
      expect(find.byKey(const ValueKey('tile-0-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-1-0')), findsNothing);
      expect(find.textContaining('tries left'), findsNothing);
      expect(find.byKey(const ValueKey('game-title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('game-title'))).data,
        '4 · no limit',
      );
      final guesses = bank
          .guessable(4)
          .where((w) => RegExp(r'^[a-z]+$').hasMatch(w))
          .take(12)
          .toList();
      for (final (i, g) in guesses.indexed) {
        if (find.text('the word was').evaluate().isNotEmpty) break;
        await typeWord(tester, g);
        // the board grew by one row for the guess made, and one to type
        if (find.byKey(ValueKey('tile-${i + 1}-0')).evaluate().isEmpty) break;
        expect(find.byKey(ValueKey('tile-${i + 1}-0')), findsOneWidget);
      }
      expect(find.textContaining('guess'), findsWidgets);
    });

    testWidgets('a won mastermind game shows the word\'s wiktionary page', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(lang: 'en', length: 5, mode: GameMode.mastermind);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            random: Random(5),
            mode: GameMode.mastermind,
            practice: true,
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      // play it out: the same draws as the page's, on a list of our own
      final rng = Random(5);
      var left = List.of(bank.guessable(5));
      for (var n = 0; n < 40; n++) {
        final g = left.first;
        final m = mastermindReply(left, g, rng);
        left = filterEligible(left, g, m);
        await typeWord(tester, g);
        if (m.every((x) => x == Mark.correct)) break;
      }
      expect(find.textContaining('solved in'), findsOneWidget);
      expect(find.textContaining('wiktionary'), findsWidgets);
    });

    for (final largest in [false, true]) {
      testWidgets(
        'a won mastermind game (${largest ? 'largest pool' : 'random'}) is '
        'scored and reviewable${largest ? ', with skill only' : ''}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(420, 1700));
          await appState.load();
          appState.lex.veteran = true; // every step is open
          appState.setup(
            lang: 'en',
            length: 5,
            mode: GameMode.mastermind,
            mastermindLargest: largest,
          );
          final bank = (await tester.runAsync(
            () async => WordBank.load(
              (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
            ),
          ))!;
          await tester.pumpWidget(
            MaterialApp(
              home: GamePage(
                bank: bank,
                random: Random(5),
                mode: GameMode.mastermind,
                practice: true,
              ),
              onGenerateRoute: onGenerateRoute,
            ),
          );
          await tester.pump();
          final rng = Random(5);
          var left = List.of(bank.guessable(5));
          for (var n = 0; n < 40; n++) {
            final g = left.first;
            final m = largest
                ? mastermindLargest(left, g)
                : mastermindReply(left, g, rng);
            left = filterEligible(left, g, m);
            await typeWord(tester, g);
            if (m.every((x) => x == Mark.correct)) break;
          }
          await tester.pumpAndSettle();
          expect(find.textContaining('solved in'), findsOneWidget);
          expect(find.text('review'), findsOneWidget);
          expect(find.textContaining('skill'), findsWidgets);
          expect(
            find.textContaining('luck'),
            largest ? findsNothing : findsWidgets,
          );
        },
      );
    }

    testWidgets('mastermind comes back as the word answered, not redrawn', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(lang: 'fr', length: 4, mode: GameMode.mastermind);
      final bank = await frBank(tester);
      Widget page(int seed) => MaterialApp(
        home: GamePage(
          bank: bank,
          random: Random(seed),
          mode: GameMode.mastermind,
        ),
        onGenerateRoute: onGenerateRoute,
      );
      Color? fill(int r, int i) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(ValueKey('tile-$r-$i')),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      await tester.pumpWidget(page(1));
      await tester.pump();
      final plain = bank
          .guessable(4)
          .where((w) => RegExp(r'^[a-z]+$').hasMatch(w))
          .take(2)
          .toList();
      await typeWord(tester, plain[0]);
      await typeWord(tester, plain[1]);
      final before = [
        for (var r = 0; r < 2; r++)
          for (var i = 0; i < 4; i++) fill(r, i),
      ];
      // leave and come back, with another seed: what it said is what comes back
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page(99));
      await tester.pump();
      expect(find.byKey(const ValueKey('tile-2-0')), findsOneWidget);
      final after = [
        for (var r = 0; r < 2; r++)
          for (var i = 0; i < 4; i++) fill(r, i),
      ];
      expect(after, before);
    });

    testWidgets('the mastermind daily says the same on a second visit, and '
        'to any seed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(lang: 'fr', mode: GameMode.mastermind);
      final bank = await frBank(tester);
      const daily = Daily('2026-11-12', '', length: 5, tries: 0);
      Widget page(int seed) => MaterialApp(
        home: GamePage(
          bank: bank,
          random: Random(seed),
          daily: daily,
          mode: GameMode.mastermind,
        ),
        onGenerateRoute: onGenerateRoute,
      );
      Color? fill(int r, int i) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(ValueKey('tile-$r-$i')),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      await tester.pumpWidget(page(1));
      await tester.pump();
      final plain = bank
          .guessable(5)
          .where((w) => RegExp(r'^[a-z]+$').hasMatch(w))
          .take(3)
          .toList();
      for (final w in plain) {
        await typeWord(tester, w);
      }
      final before = [
        for (var r = 0; r < 3; r++)
          for (var i = 0; i < 5; i++) fill(r, i),
      ];
      // leave and come back with another seed: the replies come from the date,
      // so they are the same, though only the guesses were kept
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page(99));
      await tester.pump();
      expect(find.byKey(const ValueKey('tile-3-0')), findsOneWidget);
      final after = [
        for (var r = 0; r < 3; r++)
          for (var i = 0; i < 5; i++) fill(r, i),
      ];
      expect(after, before);
    });

    testWidgets('equations: the keyboard has digits and signs, and a wrong '
        'guess says why', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(mode: GameMode.equations, eqTries: 7);
      final bank = (await tester.runAsync(
        () async => Equations.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.equations,
            practice: true,
            daily: const Daily('', '12+34=46', length: 8, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      for (final k in ['0', '9', '+', '×', '÷', '−', '=']) {
        expect(find.text(k), findsWidgets, reason: k);
      }
      expect(find.text('q'), findsNothing);
      // the space (a blank) is on the pad too, and types a blank
      expect(find.text('_'), findsOneWidget);
      // the pad: = ÷ × − along the top, then 7 8 9, 4 5 6, 1 2 3, then 0 and
      // backspace, the space under it all
      Rect box(String k) => tester.getRect(
        find
            .ancestor(of: find.text(k).last, matching: find.byType(InkWell))
            .first,
      );
      expect(box('=').top, lessThan(box('7').top));
      expect(box('7').top, lessThan(box('4').top));
      expect(box('4').top, lessThan(box('1').top));
      expect(box('1').top, lessThan(box('0').top));
      expect(box('0').top, lessThan(box('_').top), reason: 'space under');
      // columns line up: = over 7 over 4 over 1 over 0
      for (final k in ['7', '4', '1', '0']) {
        expect(box(k).left, closeTo(box('=').left, 1), reason: k);
      }
      expect(box('÷').left, closeTo(box('8').left, 1));
      expect(box('×').left, closeTo(box('9').left, 1));
      // the right column: − over + (two rows tall) over enter (two rows tall)
      expect(box('−').left, closeTo(box('+').left, 1));
      expect(box('+').left, closeTo(box('enter').left, 1));
      expect(box('+').height, closeTo(box('7').height * 2 + 4, 6));
      expect(box('enter').height, closeTo(box('+').height, 1));
      expect(box('+').top, closeTo(box('7').top, 1));
      expect(box('enter').top, closeTo(box('1').top, 1));
      // 0 is one key wide, backspace two
      expect(box('0').width, closeTo(box('7').width, 1));
      expect(box('⌫').width, closeTo(box('7').width * 2, 6));
      expect(box('⌫').top, closeTo(box('0').top, 1));
      // no other keys: no letters, no top bar
      expect(find.text('esc'), findsNothing);
      expect(find.text('q'), findsNothing);
      // typed on the keyboard of the screen, as a phone would
      for (final ch in '12+34=47'.split('')) {
        await tester.tap(find.text(ch).last);
        await tester.pump();
      }
      await tester.tap(find.text('enter'));
      await tester.pump();
      expect(find.text('both sides must be equal'), findsOneWidget);
      // fix the last tile and play the equation that is the answer
      await tester.tap(find.text('⌫'));
      await tester.pump();
      await tester.tap(find.text('6').last);
      await tester.pump();
      await tester.tap(find.text('enter'));
      await tester.pump();
      expect(find.textContaining('solved in 1 of 6'), findsOneWidget);
    });

    testWidgets('an equations game is scored and can be reviewed', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(mode: GameMode.equations, eqTries: 7, eqLength: 6);
      final bank = (await tester.runAsync(
        () async => Equations.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.equations,
            practice: true,
            daily: const Daily('', '4*5=20', length: 6, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      Future<void> play(String eq) async {
        for (final ch in eq.split('')) {
          await tester.tap(find.text(faceOf(ch)).last);
          await tester.pump();
        }
        await tester.tap(find.text('enter'));
        await tester.pump();
      }

      await play('1+9=10');
      await play('4*5=20');
      await tester.pumpAndSettle();
      expect(find.textContaining('solved in 2'), findsOneWidget);
      // skill and luck are there, and the review button
      expect(find.byKey(const ValueKey('measure-skill')), findsOneWidget);
      expect(find.text('review'), findsOneWidget);
    });

    testWidgets('equations: the hardware keyboard takes x as times', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.lex.veteran = true; // every step is open
      appState.setup(mode: GameMode.equations, eqTries: 7);
      final bank = (await tester.runAsync(
        () async => Equations.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: GameMode.equations,
            practice: true,
            daily: const Daily('', '3*4+8=20', length: 8, tries: 6),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      // the x from the keyboard, the digits and = too; + from the screen's
      final keys = {
        '3': LogicalKeyboardKey.digit3,
        'x': LogicalKeyboardKey.keyX,
        '4': LogicalKeyboardKey.digit4,
        '8': LogicalKeyboardKey.digit8,
        '=': LogicalKeyboardKey.equal,
        '2': LogicalKeyboardKey.digit2,
        '0': LogicalKeyboardKey.digit0,
      };
      for (final ch in '3x4+8=20'.split('')) {
        if (ch == '+') {
          await tester.tap(find.text('+').last);
        } else {
          await tester.sendKeyEvent(keys[ch]!, character: ch);
        }
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.textContaining('solved in 1 of 6'), findsOneWidget);
    });
  });
}
