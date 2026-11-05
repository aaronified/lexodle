import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  group('the draw is the mode\'s own', () {
    test('each mode remembers what was chosen for it', () {
      final s = AppState();
      s.setup(mode: GameMode.classic, draw: Draw.equal);
      s.setup(mode: GameMode.blind, draw: Draw.frequency);
      expect(s.draw, Draw.frequency);
      s.setup(mode: GameMode.classic);
      expect(s.draw, Draw.equal);
      s.setup(mode: GameMode.quartet);
      // none chosen yet: what the single setting was
      expect(s.draw, Draw.sigmoid);
      expect(s.drawOf(GameMode.blind), Draw.frequency);
    });

    test('the draw given with a mode is that mode\'s', () {
      final s = AppState();
      s.setup(mode: GameMode.relay, draw: Draw.frequency);
      expect(s.drawOf(GameMode.relay), Draw.frequency);
      expect(s.drawOf(GameMode.classic), Draw.sigmoid);
    });

    test('the themed wordle has no frequency: the curve stands for it', () {
      final s = AppState();
      s.setup(mode: GameMode.classic, draw: Draw.frequency);
      expect(s.drawOf(GameMode.themed), Draw.sigmoid);
      s.setup(lang: 'en', mode: GameMode.themed, draw: Draw.equal);
      expect(s.draw, Draw.equal);
    });

    test(
      'an old single setting is every mode\'s until one is chosen',
      () async {
        SharedPreferences.setMockInitialValues({'draw': Draw.equal.index});
        final s = AppState();
        await s.load();
        for (final m in GameMode.values) {
          expect(s.drawOf(m), Draw.equal, reason: '$m');
        }
        s.setup(mode: GameMode.blind, draw: Draw.frequency);
        expect(s.drawOf(GameMode.classic), Draw.equal);
      },
    );

    test('it is saved and loaded again', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      a.setup(mode: GameMode.lockdown, draw: Draw.frequency);
      a.setup(mode: GameMode.classic, draw: Draw.equal);
      final b = AppState();
      await b.load();
      expect(b.drawOf(GameMode.lockdown), Draw.frequency);
      expect(b.drawOf(GameMode.classic), Draw.equal);
      expect(b.drawOf(GameMode.relay), Draw.sigmoid);
    });

    test('a backup carries the draw of every mode, and refuses a bad one', () {
      final a = AppState();
      a.setup(mode: GameMode.blind, draw: Draw.frequency);
      a.setup(mode: GameMode.classic, draw: Draw.equal);
      final text = backupToText(a);
      final b = parseBackup(text);
      expect(b.settings['draws'], {'blind': 2, 'classic': 1});
      final j = jsonDecode(text) as Map<String, dynamic>;
      for (final bad in [
        {'nonsense': 1},
        {'blind': 7},
        {'blind': 'x'},
      ]) {
        (j['settings'] as Map<String, dynamic>)['draws'] = bad;
        expect(() => parseBackup(jsonEncode(j)), throwsA(anything));
      }
      // a backup from before has none, and is read all the same
      (j['settings'] as Map<String, dynamic>).remove('draws');
      expect(parseBackup(jsonEncode(j)).settings.containsKey('draws'), isFalse);
    });
  });

  group('the draw row follows the mode', () {
    Future<void> home(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
    }

    Finder label() => find.byKey(const ValueKey('frequency-label'));
    Finder dots() => find.descendant(
      of: find.byKey(const ValueKey('frequency-dots')),
      matching: find.byType(Container),
    );
    String text(WidgetTester tester) => tester.widget<Text>(label()).data!;

    testWidgets('the words of a mode: three choices, kept for the mode', (
      tester,
    ) async {
      appState.setup(lang: 'en', mode: GameMode.blind);
      await home(tester);
      expect(text(tester), 'word draw · sigmoid curve');
      expect(dots(), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(appState.drawOf(GameMode.blind), Draw.equal);
      // another mode has its own
      appState.setup(mode: GameMode.classic);
      await tester.pump();
      expect(text(tester), 'word draw · sigmoid curve');
      appState.setup(mode: GameMode.blind);
      await tester.pump();
      expect(text(tester), 'word draw · every word');
    });

    testWidgets('the places: two choices, and they are places', (tester) async {
      appState.setup(lang: 'en', mode: GameMode.themed);
      await home(tester);
      expect(text(tester), 'place draw · sigmoid curve');
      expect(dots(), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(text(tester), 'place draw · every place');
      expect(find.textContaining('every place of the length'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(text(tester), 'place draw · sigmoid curve');
    });

    testWidgets('the equations: nothing to choose, and it says why', (
      tester,
    ) async {
      appState.setup(lang: 'en', mode: GameMode.equations);
      await home(tester);
      expect(text(tester), 'equation draw · every equation');
      expect(dots(), findsNWidgets(1));
      final before = appState.drawOf(GameMode.equations);
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(appState.drawOf(GameMode.equations), before);
      expect(find.textContaining('there is nothing to choose'), findsOneWidget);
    });

    testWidgets('the mastermind: the pool, random or the largest', (
      tester,
    ) async {
      appState.setup(
        lang: 'en',
        mode: GameMode.mastermind,
        mastermindLargest: false,
      );
      await home(tester);
      expect(text(tester), 'pool · random');
      expect(dots(), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(appState.mastermindLargest, isTrue);
      expect(text(tester), 'pool · largest');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      expect(appState.mastermindLargest, isFalse);
      expect(text(tester), 'pool · random');
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
