import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/split_plot.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('solver narrows the words and recommends a guess', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4);
    // word files are read with real file IO, which fake-async cannot await
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    // recommend() yields to the event loop; advance the fake clock past it
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('alternatives'), findsOneWidget);
    expect(find.textContaining('words fit'), findsOneWidget);
    expect(
      find.text('type a guess, tap its tiles to match the game'),
      findsOneWidget,
    );

    // a guess with every tile left grey rules out all words sharing its letters
    for (final ch in 'mais'.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));

    final undo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'undo'),
    );
    expect(undo.onPressed, isNotNull); // the guess is in the history
    expect(find.text('alternatives'), findsOneWidget);
    expect(
      find.text('type a guess, tap its tiles to match the game'),
      findsNothing,
    );
  });

  testWidgets('solver uses the difficulty: its word list and its tries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 3);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    // the answer can be any word of the length
    final pool = bank.answers(4).length;
    expect(pool, bank.guessable(4).length);
    expect(find.textContaining('$pool words fit'), findsOneWidget);
    expect(find.textContaining('3 tries left'), findsOneWidget);

    for (final ch in 'mais'.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('2 tries left'), findsOneWidget);
  });

  for (final tries in [1, 2, 6]) {
    testWidgets('solver with $tries tries left offers alternatives', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      appState.setup(lang: 'fr', length: 4, tries: tries);
      final bank = await _bank(tester, 'fr');
      await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
      await tester.pump(const Duration(seconds: 2));
      expect(_chips(), findsNWidgets(5));
      expect(find.byKey(const ValueKey('plot-use')), findsOneWidget);
    });
  }

  testWidgets('an excluded word is neither listed nor recommended', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 6);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    final total = bank.answers(4).length;
    expect(find.textContaining('$total words fit'), findsOneWidget);
    final rec = _altWords(tester).first;
    final first = bank.answers(4).first;

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: SolverPage(bank: bank, excluded: {rec, first}),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.textContaining('${total - {rec, first}.length} words fit'),
      findsOneWidget,
    );
    expect(_altWords(tester), isNot(contains(rec)));
    expect(_altWords(tester), isNot(contains(first)));
  });

  testWidgets('up to five alternatives, the recommended one first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 6);
    final bank = await _bank(tester, 'fr');
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    final words = _altWords(tester);
    expect(words.length, 5);
    expect(words.toSet().length, 5);
    final pool = bank.answers(4);
    final best = await tester.runAsync(
      () => recommend(
        pool,
        recommendationCandidates(pool, bank.guessable(4)),
        weights: bank.law(4, appState.drawOf(appState.mode)),
      ),
    );
    expect(words.first, best!.word);
    expect(_plotTitle(tester), startsWith(words.first));
  });

  testWidgets('selecting a chip changes the plot; use puts it in the row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 6);
    final bank = await _bank(tester, 'fr');
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    final words = _altWords(tester);
    await tester.tap(find.byKey(ValueKey('alt-${words[2]}')));
    await tester.pump();
    expect(_plotTitle(tester), startsWith(words[2]));
    await tester.tap(find.byKey(const ValueKey('plot-use')));
    await tester.pump();
    // the word is in the row now: its own plot shows, with no use button
    expect(find.byKey(const ValueKey('plot-use')), findsNothing);
    expect(_plotTitle(tester), startsWith(words[2]));
    expect(find.byKey(const ValueKey('plot-bar-hl')), findsOneWidget);
  });

  testWidgets('a typed word shows its own plot and tiles light its bars', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 6);
    final bank = await _bank(tester, 'fr');
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    final own = bank
        .answers(4)
        .firstWhere((w) => !_altWords(tester).contains(w));
    await _typeWord(tester, own);
    expect(_plotTitle(tester), startsWith(own));
    expect(find.byKey(const ValueKey('plot-use')), findsNothing);
    final before = _countText(tester);
    final hlBefore = tester.getTopLeft(
      find.byKey(const ValueKey('plot-bar-hl')),
    );
    // the row being typed is the only row: tap its first tile
    await tester.tap(find.byType(MarkTile).first);
    await tester.pump();
    final after = _countText(tester);
    final hlAfter = tester.getTopLeft(
      find.byKey(const ValueKey('plot-bar-hl')),
    );
    expect(
      before != after || hlBefore != hlAfter,
      isTrue,
      reason: 'marking a tile moves the lit bar',
    );
  });

  testWidgets('a plot with many groups scrolls inside its card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'en', length: 5, tries: 6);
    final bank = await _bank(tester, 'en');
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 5));
    final card = find.ancestor(
      of: find.byKey(const ValueKey('plot-scroll')),
      matching: find.byType(Container),
    );
    final width = tester.getSize(card.first).width;
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('plot-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(scroll.position.pixels, 0);
    await tester.drag(
      find.byKey(const ValueKey('plot-scroll')),
      const Offset(-120, 0),
    );
    await tester.pump();
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.getSize(card.first).width, width);
  });

  testWidgets('a complete word that is not in the list says so', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'fr', length: 4, tries: 6);
    final bank = await _bank(tester, 'fr');
    await tester.pumpWidget(MaterialApp(home: SolverPage(bank: bank)));
    await tester.pump(const Duration(seconds: 2));
    var word = 'zzzz';
    for (final w in ['zxqz', 'qxzq', 'wxwx', 'zzzz']) {
      if (!bank.guessable(4).contains(w)) {
        word = w;
        break;
      }
    }
    await _typeWord(tester, word);
    expect(find.text('$word is not in the word list'), findsOneWidget);
    expect(find.byType(SplitPlot), findsNothing);
  });
}

Future<WordBank> _bank(WidgetTester tester, String lang) async =>
    (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == lang),
      ),
    ))!;

Finder _chips() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('alt-'),
);

List<String> _altWords(WidgetTester tester) => [
  for (final e in _chips().evaluate())
    (e.widget.key as ValueKey<String>).value.substring(4),
];

String _plotTitle(WidgetTester tester) => tester
    .widget<RichText>(
      find
          .descendant(
            of: find.byType(SplitPlot),
            matching: find.byType(RichText),
          )
          .first,
    )
    .text
    .toPlainText();

String _countText(WidgetTester tester) => tester
    .widgetList<Text>(find.textContaining('if the game shows this'))
    .first
    .data!;

Future<void> _typeWord(WidgetTester tester, String word) async {
  for (final ch in word.split('')) {
    await tester.sendKeyEvent(
      LogicalKeyboardKey(ch.codeUnitAt(0)),
      character: ch,
    );
  }
  await tester.pump();
}
