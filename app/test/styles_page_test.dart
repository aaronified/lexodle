import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/styles_page.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The examples are worked out in slices that give the event loop back, so the
  // test lets the (fake) clock run until they are on screen.
  Future<void> waitFor(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 600 && f.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f, findsWidgets);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 6000));
    appState.setup(lang: 'fr', length: 4);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: StylesPage(bank: bank)));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'all five habits are taught, with their rule and when to play it',
    (tester) async {
      await open(tester);
      for (final b in Behaviour.values) {
        expect(find.byKey(ValueKey('style-card-${b.label}')), findsOneWidget);
        expect(find.text(b.what), findsOneWidget);
        expect(find.text('counted when: ${b.rule}'), findsOneWidget);
        expect(
          textOf(
            tester.widget<Text>(find.byKey(ValueKey('style-when-${b.label}'))),
          ),
          whenRight(b),
        );
      }
      // three in the opening, two at the end
      expect(
        Behaviour.values.where((b) => b.phase == Phase.early),
        hasLength(3),
      );
      expect(Behaviour.values.where((b) => b.phase == Phase.end), hasLength(2));
      expect(
        find.textContaining('the opening · $earlyFrom or more'),
        findsOneWidget,
      );
      expect(
        find.textContaining('the end · $endUpTo or fewer'),
        findsOneWidget,
      );
      await settle(tester);
    },
  );

  testWidgets('each opening habit gets a real example with its numbers', (
    tester,
  ) async {
    await open(tester);
    for (final b in [
      Behaviour.maximiser,
      Behaviour.eliminator,
      Behaviour.gambler,
    ]) {
      await waitFor(tester, find.byKey(ValueKey('style-example-${b.label}')));
      final numbers = textOf(
        tester.widget<Text>(find.byKey(ValueKey('style-numbers-${b.label}'))),
      )!;
      expect(
        numbers,
        matches(
          RegExp(r'skill \d+ · risk [\d–]+ · rank [\d–]+% · \d+ fresh letters'),
        ),
      );
    }
    // the maximiser's example is a top split
    final max = textOf(
      tester.widget<Text>(
        find.byKey(const ValueKey('style-numbers-maximiser')),
      ),
    )!;
    final rank = int.parse(RegExp(r'rank (\d+)%').firstMatch(max)![1]!);
    expect(rank, lessThanOrEqualTo(topRank));
    expect(find.textContaining('style: maximiser'), findsOneWidget);
    await settle(tester);
  });

  testWidgets(
    'the closing habits get an endgame each: a word that fits, a probe',
    (tester) async {
      await open(tester);
      await waitFor(tester, find.byKey(const ValueKey('style-example-closer')));
      await waitFor(tester, find.byKey(const ValueKey('style-example-prober')));
      expect(find.textContaining('wins in time'), findsWidgets);
      expect(find.textContaining('← the best'), findsNWidgets(2));
      expect(find.textContaining('style: closer'), findsOneWidget);
      expect(find.textContaining('cannot win now'), findsWidgets);
      await settle(tester);
    },
  );

  testWidgets('luck is explained, with an example that averages nothing', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text('luck: explained, not taught'.toLowerCase()),
      findsOneWidget,
    );
    expect(find.textContaining('there is nothing to practise'), findsOneWidget);
    await waitFor(tester, find.byKey(const ValueKey('style-luck-mean')));
    expect(
      textOf(
        tester.widget<Text>(find.byKey(const ValueKey('style-luck-mean'))),
      ),
      endsWith('is 0'),
    );
    expect(find.textContaining('in a group of'), findsWidgets);
    await settle(tester);
  });

  testWidgets('the pairs of habits make the six playstyles', (tester) async {
    await open(tester);
    for (final p in playstyles) {
      expect(
        find.byKey(ValueKey('style-grid-${p.id}')),
        findsOneWidget,
        reason: p.id,
      );
    }
    expect(find.textContaining('maximiser + closer'), findsOneWidget);
    await settle(tester);
  });
}
