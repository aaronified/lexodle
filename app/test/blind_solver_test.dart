import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_solver.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/split_plot.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _words = [
  'crane',
  'crate',
  'crave',
  'slate',
  'brick',
  'mount',
  'ghost',
  'plumb',
];

WordBank _bank() => WordBank.custom(
  const Language('en', 'English', 'English', [5]),
  {5: _words},
  {5: List.filled(_words.length, 1)},
  curveOrigin: WordBank.defaultCurveOrigin,
  curveWidth: WordBank.defaultCurveWidth,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the counts narrow the words', () {
    // crane against crate: four in place, none elsewhere; crave is the same
    expect(blindNarrow(_words, [('crane', 4, 0)]), ['crate', 'crave']);
    // all five in place is the word itself
    expect(blindNarrow(_words, [('crane', 5, 0)]), ['crane']);
    // nothing right: only the words with none of its letters
    expect(blindNarrow(_words, [('crane', 0, 0)]), ['ghost', 'plumb']);
    // two guesses narrow it twice
    expect(blindNarrow(_words, [('crane', 4, 0), ('crate', 5, 0)]), ['crate']);
    // counts no word gives leave nothing
    expect(blindNarrow(_words, [('crane', 2, 3)]), isEmpty);
  });

  test('blindGroups counts by blindCode, biggest first', () {
    final g = blindGroups(_words, 'crane');
    expect(g.fold<int>(0, (a, e) => a + e.$2), _words.length);
    for (var i = 1; i < g.length; i++) {
      expect(g[i - 1].$2 >= g[i].$2, isTrue);
    }
  });

  test('the marks of counts are sorted greens, yellows, absents', () {
    expect(blindMarks(4, 1, 2).map((m) => m.name), [
      'correct',
      'present',
      'present',
      'absent',
    ]);
  });

  test('the recommendation splits the words by their counts', () async {
    final r = await blindRecommend(_words, _words, 5);
    expect(r, isNotNull);
    expect(_words, contains(r!.word));
    // no guess leaves more than the whole pool
    expect(r.expected, lessThan(_words.length));
    // two words left: a guess that tells them apart wins at once
    final two = await blindRecommend(['crate', 'crave'], _words, 2);
    expect(two!.winChance, 1.0);
    // one try left: a word that fits
    final one = await blindRecommend(['crate', 'crave'], _words, 1);
    expect(['crate', 'crave'], contains(one!.word));
    expect(one.canWin, isTrue);
    // nothing fits: nothing to recommend
    expect(await blindRecommend([], _words, 5), isNull);
  });

  testWidgets('the page narrows by the counts typed in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'en', length: 5, blindTries: 10);
    await tester.pumpWidget(
      MaterialApp(
        home: BlindSolverPage(bank: _bank(), excluded: const {'ghost'}),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('7 words fit · 10 tries left'), findsOneWidget);

    for (final ch in 'crane'.split('')) {
      await tester.tap(find.text(ch).last);
    }
    // four letters in place
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('count-0-g')));
      await tester.pump();
    }
    await tester.tap(find.text('add guess'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('2 words fit · 9 tries left'), findsOneWidget);
  });

  testWidgets('alternatives, their plot, use and the lit count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    appState.setup(lang: 'en', length: 5, blindTries: 10);
    await tester.pumpWidget(MaterialApp(home: BlindSolverPage(bank: _bank())));
    await tester.pump(const Duration(seconds: 2));
    final chips = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('alt-'),
    );
    expect(chips, findsAtLeastNWidgets(2));
    expect(chips.evaluate().length, lessThanOrEqualTo(5));
    final rec = await blindRecommend(_words, _words, 10);
    final firstKey =
        (chips.first.evaluate().single.widget.key as ValueKey).value;
    expect(firstKey, 'alt-${rec!.word}');
    String plotWord() => tester.widget<SplitPlot>(find.byType(SplitPlot)).word;
    expect(plotWord(), rec.word);
    // selecting another chip changes the plot
    final second = chips.at(1);
    final secondWord =
        '${(second.evaluate().single.widget.key as ValueKey).value}'.substring(
          4,
        );
    await tester.tap(second);
    await tester.pump();
    expect(plotWord(), secondWord);
    // use puts the word in the row
    await tester.tap(find.byKey(const ValueKey('plot-use')));
    await tester.pump();
    for (final ch in secondWord.split('')) {
      expect(find.text(ch), findsWidgets);
    }
    // the typed row is plotted; stepping a count moves the lit bar and label
    expect(plotWord(), secondWord);
    expect(find.byKey(const ValueKey('plot-use')), findsNothing);
    expect(find.textContaining('0 in place · 0 elsewhere'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('count-0-g')));
    await tester.pump();
    expect(find.textContaining('1 in place · 0 elsewhere'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('count-0-y')));
    await tester.pump();
    expect(find.textContaining('1 in place · 1 elsewhere'), findsOneWidget);
  });
}
