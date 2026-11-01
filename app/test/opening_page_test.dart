import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/opening.dart';
import 'package:lexodle/opening_page.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The analyses run in slices that give the event loop back, so the test lets
  // the (fake) clock run until what it waits for is on screen.
  Future<void> waitFor(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 600 && f.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f, findsWidgets);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    appState.setup(lang: 'fr', length: 4);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: OpeningPage(bank: bank)));
    await waitFor(tester, find.byKey(const ValueKey('opening-first')));
  }

  String text(WidgetTester tester, String key) =>
      textOf(tester.widget<Text>(find.byKey(ValueKey(key))))!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('it names the best first guess, with how it splits the words', (
    tester,
  ) async {
    await open(tester);
    final first = text(tester, 'opening-first');
    expect(first.length, 4);
    final stats = text(tester, 'opening-stats');
    expect(stats, contains('groups · the biggest'));
    expect(stats, contains('words left'));
    expect(stats, contains('bits expected'));
    // other first guesses to compare, the best among them at 100
    expect(find.byKey(const ValueKey('opening-alt-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('opening-alt-1')), findsOneWidget);
    expect(find.text('$first 100'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('each likely outcome gets a best second guess, filling in', (
    tester,
  ) async {
    await open(tester);
    // the rows are there at once, the second guesses come one by one
    expect(find.byKey(const ValueKey('opening-row-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opening-row-${openingOutcomeCount - 1}')),
      findsOneWidget,
    );
    await waitFor(tester, find.byKey(const ValueKey('opening-second-0')));
    await waitFor(
      tester,
      find.byKey(const ValueKey('opening-second-${openingOutcomeCount - 1}')),
    );
    for (var i = 0; i < openingOutcomeCount; i++) {
      final line = text(tester, 'opening-second-$i');
      expect(line, startsWith('play '));
      // a word of the language's length
      final word = line.substring(5).split(' ').first;
      expect(word.length, 4, reason: 'row $i: $line');
    }
    await settle(tester);
  });

  testWidgets('a row opens to the other good second guesses and its words', (
    tester,
  ) async {
    await open(tester);
    await waitFor(tester, find.byKey(const ValueKey('opening-second-0')));
    await tester.tap(find.byKey(const ValueKey('opening-row-0')));
    await tester.pump();
    final more = find.byWidgetPredicate(
      (w) => w.key.toString().contains('opening-more-0-'),
    );
    expect(more, findsWidgets);
    final line = textOf(tester.widget<Text>(more.first))!;
    expect(line, contains('skill 100'));
    expect(line, contains('words left'));
    expect(line, contains('bits'));
    // a second tap closes it
    await tester.tap(find.byKey(const ValueKey('opening-row-0')));
    await tester.pump();
    expect(more, findsNothing);
    await settle(tester);
  });

  testWidgets('choosing another first guess starts its outcomes afresh', (
    tester,
  ) async {
    await open(tester);
    final first = text(tester, 'opening-first');
    await waitFor(tester, find.byKey(const ValueKey('opening-second-0')));
    await tester.tap(find.byKey(const ValueKey('opening-alt-1')));
    await tester.pump();
    final other = text(tester, 'opening-first');
    expect(other, isNot(first));
    // the second guesses of the old choice are gone, and fill in again
    expect(find.byKey(const ValueKey('opening-second-0')), findsNothing);
    await waitFor(tester, find.byKey(const ValueKey('opening-second-0')));
    await settle(tester);
  });
}
