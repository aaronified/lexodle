import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/diy.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('blind feedback counts', () {
    test('marks are the same whichever letters they are on', () {
      // prism: r in place; crane gives the same count as grate would
      final a = evaluate('prism', 'crane', blind: true);
      expect(a.where((m) => m == Mark.correct).length, 1);
      expect(a.where((m) => m == Mark.present).length, 0);
      expect(evaluate('crane', 'nacre', blind: true), [
        Mark.correct,
        Mark.present,
        Mark.present,
        Mark.present,
        Mark.present,
      ]);
      // greens first, then yellows, then absents
      final m = evaluate('plate', 'pleat', blind: true);
      expect(m.map((x) => x.index).toList(), [0, 0, 1, 1, 1]);
    });

    test('the words left are those with the same two counts', () {
      const words = ['plate', 'peace', 'place', 'spate', 'stale', 'later'];
      final marks = evaluate('plate', 'place', blind: true);
      final left = filterEligible(words, 'place', marks, blind: true);
      expect(left, containsAll(['plate', 'peace']));
      // the colour version tells plate from peace; the counts cannot
      final colour = filterEligible(words, 'place', evaluate('plate', 'place'));
      expect(colour, isNot(contains('peace')));
    });

    test('a guess splits the words into at most the count pairs', () {
      final words = [
        'crane',
        'slate',
        'trace',
        'react',
        'caret',
        'cater',
        'prism',
        'plate',
        'pleat',
        'place',
        'spate',
        'stale',
        'later',
        'alert',
      ];
      final colour = SplitContext(words, null).stats('crane');
      final blind = SplitContext(words, null, blind: true).stats('crane');
      expect(blind.groups, lessThanOrEqualTo(colour.groups));
      expect(blind.h, lessThanOrEqualTo(colour.h + 1e-9));
      // the answer's group is found by the counts too
      final landed = SplitContext(
        words,
        null,
        blind: true,
      ).stats('crane', answer: 'react');
      expect(landed.landedMass, greaterThan(0));
    });
  });

  group('diy links', () {
    test('every letter is four digits and the word comes back', () {
      for (final w in [
        'crane',
        'zürich',
        'łódź',
        'ő'
            'rség',
        'aaaaa',
      ]) {
        final d = diyEncode(w);
        expect(d.length, w.runes.length * 4);
        expect(diyDecode(d), w);
      }
    });

    test('a repeated letter does not repeat its digits', () {
      final d = diyEncode('aaaa');
      final four = [for (var i = 0; i < 16; i += 4) d.substring(i, i + 4)];
      expect(four.toSet().length, 4);
    });

    test('the link names the language, the tries and the word', () {
      final p = DiyPuzzle('fr', 'élève', 8);
      expect(p.link, contains('#/diy?l=fr&t=8&w='));
      final back = DiyPuzzle.parse(Uri.parse(routeOf(p.link)));
      expect(back?.word, 'élève');
      expect(back?.lang, 'fr');
      expect(back?.tries, 8);
      expect(DiyPuzzle.parse(Uri.parse('/diy?l=fr&t=8&w=12')), isNull);
      expect(DiyPuzzle.parse(Uri.parse('/diy?l=fr&t=8')), isNull);
    });
  });

  group('geography', () {
    late WordBank places;
    setUp(() async {
      final en = (await WordBank.languages()).firstWhere((l) => l.code == 'en');
      places = await Geography.load(en);
    });

    test('every length has at least 1,500 answers to draw from', () {
      for (final n in [4, 5, 6, 7, 8]) {
        expect(places.answers(n).length, greaterThan(2000), reason: '$n');
      }
    });

    test('places are the only valid words', () {
      expect(places.valid, contains('spain'));
      expect(places.valid, isNot(contains('house')));
      final spain = Geography.placeOf('spain')!;
      expect(spain.kind, 'country');
      expect(spain.link.toString(), contains('wikipedia.org'));
    });

    test('the draw curve is about even to 1,200 and nothing past 2,000', () {
      final w = places.curveWeights(5);
      expect(w.first, greaterThan(990));
      expect(w[1199], greaterThan(900));
      expect(w[1499], inInclusiveRange(450, 550));
      expect(w[2300], lessThan(30));
    });
  });

  group('the games', () {
    Future<void> open(
      WidgetTester tester,
      GameMode mode,
      WordBank bank,
      String answer,
      int tries,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, mode: mode);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            bank: bank,
            mode: mode,
            practice: true,
            daily: Daily('', answer, length: 5, tries: tries),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
    }

    Future<void> guess(WidgetTester tester, String w) async {
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

    testWidgets('blind shows two counts and no tile colours', (tester) async {
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      ))!;
      await open(tester, GameMode.blind, bank, 'prism', 10);
      await guess(tester, 'crane');
      // prism has the r of crane in place and no other letter of it
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('count-0-g')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('count-0-y')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '0',
      );
    });

    testWidgets('themed takes only places, and every guess has an info dot', (
      tester,
    ) async {
      final places = (await tester.runAsync(() async {
        final en = (await WordBank.languages()).firstWhere(
          (l) => l.code == 'en',
        );
        return Geography.load(en);
      }))!;
      await open(tester, GameMode.themed, places, 'spain', 6);
      await guess(tester, 'house');
      expect(find.text('not a place name'), findsOneWidget);
      expect(find.byKey(const ValueKey('place-dot-0')), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
      }
      await guess(tester, 'egypt');
      await tester.tap(find.byKey(const ValueKey('place-dot-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('place-kind')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('place-kind'))).data,
        'country · Egypt',
      );
    });
  });
}
