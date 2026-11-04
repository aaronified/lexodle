import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_guide.dart';
import 'package:lexodle/learn_home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('the word drills fit the modes that play single words', () {
    expect(learnDrillsFit(GameMode.classic), isTrue);
    expect(learnDrillsFit(GameMode.mastermind), isTrue);
    expect(learnDrillsFit(GameMode.equations), isFalse);
    expect(learnDrillsFit(GameMode.blind), isFalse);
  });

  Future<void> open(WidgetTester tester, GameMode mode) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'en', length: 5, mode: mode);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    await tester.pumpWidget(MaterialApp(home: LearnHomePage(bank: bank)));
    await tester.pump();
  }

  testWidgets('learn for equations has its guide and no word drills', (
    tester,
  ) async {
    await open(tester, GameMode.equations);
    expect(find.text('equations: how to play it well'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-opening')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('learn-card-guide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mode-guide')), findsOneWidget);
    expect(find.text('the shape'), findsOneWidget);
  });

  testWidgets('learn for classic keeps its drills and adds the guide', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    expect(find.byKey(const ValueKey('learn-card-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-opening')), findsOneWidget);
  });
}
