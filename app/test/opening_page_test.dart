import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
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
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningPage(bank: bank, random: Random(3)),
      ),
    );
    await waitFor(tester, find.byKey(const ValueKey('opening-first')));
  }

  // a word is a row of letter tiles: its text is the letters, in order
  String text(WidgetTester tester, String key) {
    final f = find.byKey(ValueKey(key));
    if (tester.widget(f) is Text) {
      return textOf(tester.widget<Text>(f))!;
    }
    return find
        .descendant(of: f, matching: find.byType(Text))
        .evaluate()
        .map((e) => textOf(e.widget as Text)!)
        .join();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool shown(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

  testWidgets('it names the best first guess, how it splits the words', (
    tester,
  ) async {
    await open(tester);
    final first = text(tester, 'opening-first');
    expect(first.length, 4);
    // the stats strip: number and label pairs, the bits first
    final stats = [
      for (final e
          in find
              .descendant(
                of: find.byKey(const ValueKey('opening-stats')),
                matching: find.byType(Text),
              )
              .evaluate())
        textOf(e.widget as Text)!,
    ];
    expect(stats, hasLength(6));
    expect(stats[0], matches(r'^\d+\.\d\d$'));
    expect(stats[1], 'bits expected');
    expect(stats[2], matches(r'^\d+$'));
    expect(stats[4], matches(r'^\d+%$'));
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('opening-reply-0-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('opening-reply-0-5')), findsNothing);
    expect(
      text(tester, 'opening-cover-0'),
      matches(r'^the five cover [\d.]+% of the words\.$'),
    );
    expect(shown('opening-second'), isFalse);
    await settle(tester);
  });

  testWidgets('tapping a reply shows the second guess, then the third', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('opening-reply-0-0')));
    await waitFor(tester, find.byKey(const ValueKey('opening-second')));
    expect(text(tester, 'opening-second').length, 4);
    expect(shown('opening-third'), isFalse);
    await tester.tap(find.byKey(const ValueKey('opening-reply-1-0')));
    await waitFor(tester, find.byKey(const ValueKey('opening-third')));
    expect(text(tester, 'opening-end'), startsWith('three guesses in: about '));
    // changing the first reply clears the levels below
    await tester.tap(find.byKey(const ValueKey('opening-reply-0-1')));
    await tester.pump();
    expect(shown('opening-third'), isFalse);
    expect(shown('opening-second'), isFalse);
    await waitFor(tester, find.byKey(const ValueKey('opening-second')));
    expect(shown('opening-reply-1-0'), isTrue);
    await settle(tester);
  });

  testWidgets('set colours: a reply no word gives is said so', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('opening-set-0')));
    await tester.pump();
    // tiles cycle grey, yellow, green: three green and one yellow cannot be
    for (var i = 0; i < 4; i++) {
      final t = find.byKey(ValueKey('opening-tile-0-$i'));
      for (var n = 0; n < (i < 3 ? 2 : 1); n++) {
        await tester.tap(t);
        await tester.pump();
      }
    }
    await tester.tap(find.byKey(const ValueKey('opening-use-0')));
    await tester.pump();
    expect(text(tester, 'opening-no-word'), 'no word gives these colours.');
    expect(shown('opening-second'), isFalse);
    // a reply that exists is used: tapping the likeliest one
    await tester.tap(find.byKey(const ValueKey('opening-reply-0-0')));
    await waitFor(tester, find.byKey(const ValueKey('opening-second')));
    await settle(tester);
  });

  testWidgets('set colours with all green: only the guess itself fits', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('opening-set-0')));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      final t = find.byKey(ValueKey('opening-tile-0-$i'));
      await tester.tap(t);
      await tester.pump();
      await tester.tap(t);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('opening-use-0')));
    await waitFor(tester, find.byKey(const ValueKey('opening-second')));
    // the one word that fits is the second guess: the first guess itself
    expect(text(tester, 'opening-second'), text(tester, 'opening-first'));
    await settle(tester);
  });

  testWidgets('randomise picks a reply and goes on to the next guess', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('opening-random-0')));
    await waitFor(tester, find.byKey(const ValueKey('opening-second')));
    await tester.tap(find.byKey(const ValueKey('opening-random-1')));
    await waitFor(tester, find.byKey(const ValueKey('opening-third')));
    await settle(tester);
  });

  testWidgets('the calculation of a guess opens from its dot', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('opening-dot-0')));
    await tester.pumpAndSettle();
    expect(find.text('the best first guess'), findsOneWidget);
    expect(find.textContaining('bits it gains on average'), findsOneWidget);
    // the dialog and the stats strip both say it
    expect(find.textContaining('words left on average'), findsWidgets);
  });
}
