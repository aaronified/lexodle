import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_pencil.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/guess_input.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<WordBank> _bank(WidgetTester tester, String code) async =>
    (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == code),
      ),
    ))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  test('the typed row comes back with its locks and cursor', () {
    final g = GuessInput(5);
    for (final ch in 'cra'.split('')) {
      g.type(ch, {'c', 'r', 'a'});
    }
    g.toggleLock(1);
    g.lockFixed([(4, 'e')]);
    final h = GuessInput(5)..restore(g.toJson());
    expect(h.slots, g.slots);
    expect(
      [for (var i = 0; i < 5; i++) h.isLocked(i)],
      [for (var i = 0; i < 5; i++) g.isLocked(i)],
    );
    expect(h.isFixed(4), isTrue);
    expect(h.cursor, g.cursor);
  });

  test('a blind game\'s colours come back', () {
    final p = BlindPencil(5)
      ..green['a'] = {1, 2}
      ..yellow['b'] = {0}
      ..grey.add('z');
    final q = BlindPencil(5)..restore(p.toJson());
    expect(q.green, p.green);
    expect(q.yellow, p.yellow);
    expect(q.grey, p.grey);
  });

  testWidgets('a game that is not a daily resumes with its answer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 5, tries: 6);
    final bank = await _bank(tester, 'fr');
    final words = bank.answers(5);
    appState.saveProgress('p|fr|classic|5|6', {
      'a': words[0],
      'g': [words[1]],
      'in': (GuessInput(5)..type(words[2][0], bank.letters(5))).toJson(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    expect(find.textContaining('5 tries left'), findsOneWidget);
  });

  testWidgets('a quartet that is not a daily resumes with its words', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'fr', length: 5, tries: 6, mode: GameMode.quartet);
    final bank = await _bank(tester, 'fr');
    final w = bank.answers(5);
    appState.saveProgress('p|fr|quartet|5|${triesFor(GameMode.quartet, 6)}', {
      'a': [w[0], w[1], w[2], w[3]],
      'g': [w[4]],
    });
    await tester.pumpWidget(
      MaterialApp(home: const SizedBox(), onGenerateRoute: onGenerateRoute),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiGamePage(bank: bank),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    final state = tester.state(find.byType(MultiGamePage));
    expect((state as dynamic).game.guesses, [w[4]]);
    expect(
      [for (final b in (state as dynamic).game.boards) b.answer],
      [w[0], w[1], w[2], w[3]],
    );
  });
}
