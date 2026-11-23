import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_guide.dart';
import 'package:lexodle/learn_home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appState.load();
    // the guides and drills open at the 'learn' step: a veteran has it
    appState.lex.veteran = true;
  });

  test('every mode has a guide, and no other game is named', () {
    for (final m in GameMode.values) {
      final g = modeGuide(m);
      expect(g, isNotEmpty, reason: '$m');
      final text = [
        for (final sec in g) '${sec.heading} ${sec.lines.join(' ')}',
      ].join(' ').toLowerCase();
      for (final sec in g) {
        for (final l in sec.lines) {
          expect(l.length, lessThan(70), reason: '$m: $l');
        }
      }
      for (final name in ['wordle', 'nerdle', 'absurdle', 'sudoku']) {
        expect(text, isNot(contains(name)), reason: '$m');
      }
    }
  });

  Future<void> open(WidgetTester tester, GameMode mode) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'en', length: 5, mode: mode);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnHomePage(bank: bank),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  testWidgets('learn for equations has its guide and its drills', (
    tester,
  ) async {
    await open(tester, GameMode.equations);
    expect(find.text('equations: how to play it well'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-opening')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-card-guide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mode-guide')), findsOneWidget);
    expect(find.text('the shape'), findsOneWidget);
  });

  testWidgets('learn for classic is four things, with no guide card', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    expect(find.byKey(const ValueKey('learn-card-opening')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('learn-card-how-to-play')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('learn-card-master')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-guess')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-guide')), findsNothing);
    expect(find.byKey(const ValueKey('learn-card-free')), findsNothing);
  });

  testWidgets('learn for equations and places does not talk about words', (
    tester,
  ) async {
    for (final (mode, thing) in [
      (GameMode.equations, 'equation'),
      (GameMode.themed, 'place'),
    ]) {
      await open(tester, mode);
      final texts = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (t.data != null) t.data!,
      ].join(' | ');
      expect(texts, isNot(contains('word')), reason: '$mode: $texts');
      expect(texts, contains(thing), reason: '$mode');
    }
  });
}
