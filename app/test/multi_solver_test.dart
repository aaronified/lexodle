import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_solver.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _words = ['cat', 'cot', 'cut', 'bat', 'bit', 'but', 'dog', 'dig'];
const _answers = ['cat', 'bit', 'dog', 'cut'];

MultiSolverState state(GameMode mode, {int tries = 8}) =>
    MultiSolverState(mode: mode, answers: _words, length: 3, tries: tries);

List<Mark> marks(String answer, String guess) => evaluate(answer, guess);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the state of a quartet being solved', () {
    test('every board is live and starts with the whole list', () {
      final s = state(GameMode.quartet);
      expect(s.live, [0, 1, 2, 3]);
      expect(s.triesLeft, 8);
      for (var i = 0; i < 4; i++) {
        expect(s.eligibleOf(i), _words);
      }
    });

    test('each board narrows by its own colours', () {
      final s = state(GameMode.quartet);
      s.addGuess('cot', {
        for (var i = 0; i < 4; i++) i: marks(_answers[i], 'cot'),
      });
      for (var i = 0; i < 4; i++) {
        final left = s.eligibleOf(i);
        expect(left, contains(_answers[i]));
        expect(left.length, lessThan(_words.length), reason: 'board $i');
      }
      expect(s.eligibleOf(2), ['dog']);
    });

    test('a solved board drops out of the live ones and stays solved', () {
      final s = state(GameMode.quartet);
      s.addGuess('dog', {
        for (var i = 0; i < 4; i++) i: marks(_answers[i], 'dog'),
      });
      expect(s.isSolved(2), isTrue);
      expect(s.live, [0, 1, 3]);
      expect(s.visible(2), 1);
      // later guesses are not read on the solved board
      s.addGuess('cat', {for (final i in s.live) i: marks(_answers[i], 'cat')});
      expect(s.visible(2), 1);
      expect(s.eligibleOf(2), ['dog']);
      expect(s.visible(0), 2);
      expect(s.isSolved(0), isTrue);
      expect(s.live, [1, 3]);
    });

    test(
      'out of tries nothing is live, and with every board solved it is done',
      () {
        final s = state(GameMode.quartet, tries: 1);
        s.addGuess('cat', {for (var i = 0; i < 4; i++) i: marks('bit', 'cat')});
        expect(s.triesLeft, 0);
        expect(s.live, isEmpty);
        final t = state(GameMode.quartet);
        for (final g in _answers) {
          t.addGuess(g, {for (final b in t.live) b: marks(_answers[b], g)});
        }
        expect(t.done, isTrue);
        expect(t.live, isEmpty);
      },
    );

    test('undo takes back the last guess on every board', () {
      final s = state(GameMode.quartet);
      s.addGuess('cat', {for (var i = 0; i < 4; i++) i: marks('dog', 'cat')});
      s.undo();
      expect(s.guesses, isEmpty);
      for (var i = 0; i < 4; i++) {
        expect(s.marks[i], isEmpty);
        expect(s.eligibleOf(i), _words);
      }
      s.undo(); // nothing to take back
    });
  });

  group('the state of a relay race being solved', () {
    test('only the first board is on, and the others wait', () {
      final s = state(GameMode.relay);
      expect(s.live, [0]);
      expect(s.isOpen(0), isTrue);
      expect(s.isOpen(1), isFalse);
      expect(s.visible(1), 0);
    });

    test(
      'solving a board opens the next, with every earlier guess to colour in',
      () {
        final s = state(GameMode.relay);
        s.addGuess('cot', {0: marks('cat', 'cot')});
        s.addGuess('cat', {0: marks('cat', 'cat')});
        expect(s.isSolved(0), isTrue);
        expect(s.live, [1]);
        // board 2 shows both earlier guesses, blank until their colours are in
        expect(s.visible(1), 2);
        expect(s.marks[1][0], List.filled(3, Mark.absent));
        // tapping a tile cycles grey, yellow, green
        s.cycle(1, 0, 0);
        expect(s.marks[1][0][0], Mark.present);
        s.cycle(1, 0, 0);
        expect(s.marks[1][0][0], Mark.correct);
        s.cycle(1, 0, 0);
        expect(s.marks[1][0][0], Mark.absent);
      },
    );

    test('colours that show a head start solve the new board at once', () {
      final s = state(GameMode.relay);
      s.addGuess('cat', {0: marks('cat', 'cat')});
      expect(s.live, [1]);
      for (var t = 0; t < 3; t++) {
        s.cycle(1, 0, t);
        s.cycle(1, 0, t);
      }
      expect(s.isSolved(1), isTrue);
      expect(s.live, [2]);
    });

    test('the colours entered for a board narrow it', () {
      final s = state(GameMode.relay);
      s.addGuess('cat', {0: marks('cat', 'cat')});
      s.marks[1][0].setAll(0, marks('dog', 'cat'));
      expect(s.eligibleOf(1), ['dog', 'dig']);
    });
  });

  group('the page', () {
    Future<WordBank> bank(WidgetTester tester) async => (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;

    Future<void> type(WidgetTester tester, String word) async {
      for (final ch in word.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(ch.codeUnitAt(0)),
          character: ch,
        );
      }
    }

    testWidgets('a quartet shows four boards and recommends a guess', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      appState.setup(lang: 'fr', length: 4, tries: 6, mode: GameMode.quartet);
      final b = await bank(tester);
      await tester.pumpWidget(MaterialApp(home: MultiSolverPage(bank: b)));
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('board-$i')), findsOneWidget);
      }
      expect(find.textContaining('solver · quartet'), findsOneWidget);
      expect(find.textContaining('9 tries'), findsWidgets);
      expect(find.text('recommended guess'), findsOneWidget);
      expect(find.textContaining('across the boards'), findsOneWidget);

      await type(tester, 'mais');
      await tester.tap(find.text('add guess'));
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('8 tries left'), findsOneWidget);
      expect(find.text('recommended guess'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'undo last'),
            )
            .onPressed,
        isNotNull,
      );
      appState.setup(mode: GameMode.classic);
    });

    testWidgets('a relay race shows the first board and says the rest wait', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      appState.setup(lang: 'fr', length: 4, tries: 6, mode: GameMode.relay);
      final b = await bank(tester);
      await tester.pumpWidget(MaterialApp(home: MultiSolverPage(bank: b)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('solver · relay race'), findsOneWidget);
      expect(find.textContaining('board 2 · waiting'), findsOneWidget);
      expect(find.text('recommended guess'), findsOneWidget);
      appState.setup(mode: GameMode.classic);
    });

    testWidgets(
      'with one try left it names the word that fits the most boards',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 1400));
        appState.setup(lang: 'fr', length: 4, tries: 1, mode: GameMode.quartet);
        final b = await bank(tester);
        // a quartet gets three extra tries: with one set that is four, so three
        // guesses with every tile grey leave the last
        await tester.pumpWidget(MaterialApp(home: MultiSolverPage(bank: b)));
        await tester.pump(const Duration(seconds: 3));
        for (final w in ['mais', 'lien', 'port']) {
          await type(tester, w);
          await tester.tap(find.text('add guess'));
          await tester.pump(const Duration(seconds: 3));
        }
        expect(find.textContaining('1 try left'), findsOneWidget);
        expect(
          find.text('last try: the word that fits the most boards'),
          findsOneWidget,
        );
        expect(find.textContaining('boards solved'), findsOneWidget);
        appState.setup(mode: GameMode.classic);
      },
    );
  });
}
