import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/puzzle.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    dailyClock = () => DateTime(2026, 10, 28, 12);
  });
  tearDown(() => dailyClock = DateTime.now);

  Uri uriOf(Puzzle p) => Uri.parse(p.link.substring(p.link.indexOf('#') + 1));

  group('the link', () {
    test('a puzzle reads back, with its guesses', () {
      final p = Puzzle.hashed(
        'fr',
        GameMode.quartet,
        length: 5,
        tries: 9,
        answers: ['crane', 'light', 'house', 'dying'],
        guesses: ['abcde', 'fghij'],
      );
      expect(p.link, startsWith(puzzleBase));
      expect(p.link, isNot(contains('crane')));
      expect(uriOf(p).path, Routes.puzzle);
      final back = Puzzle.parse(uriOf(p))!;
      expect(back.lang, 'fr');
      expect(back.mode, GameMode.quartet);
      expect((back.length, back.tries), (5, 9));
      expect(back.hashes, p.hashes);
      expect(back.guesses, ['abcde', 'fghij']);
    });

    test('without guesses the link has none', () {
      final p = Puzzle.hashed(
        'en',
        GameMode.classic,
        length: 5,
        tries: 6,
        answers: ['crane'],
      );
      expect(p.link, isNot(contains('&g=')));
      expect(Puzzle.parse(uriOf(p))!.guesses, isEmpty);
    });

    test('the hash is the same everywhere, and tells words apart', () {
      expect(wordHash('crane'), wordHash('crane'));
      expect(wordHash('crane'), hasLength(16));
      expect(wordHash('crane'), isNot(wordHash('crate')));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(wordHash('crane')), isTrue);
    });

    test('a link that is not a puzzle is not one', () {
      final h = wordHash('crane');
      Puzzle? p(String q) => Puzzle.parse(Uri.parse('/puzzle?$q'));
      expect(p('l=en&m=classic&n=5&t=6&w=$h'), isNotNull);
      expect(p('m=classic&n=5&t=6&w=$h'), isNull, reason: 'no language');
      expect(p('l=en&n=5&t=6&w=$h'), isNull, reason: 'no mode');
      expect(p('l=en&m=blitz&n=5&t=6&w=$h'), isNull, reason: 'unknown mode');
      expect(p('l=EN!&m=classic&n=5&t=6&w=$h'), isNull, reason: 'odd language');
      expect(p('l=en&m=classic&n=5&t=6&w=$h.$h'), isNull, reason: 'one word');
      expect(p('l=en&m=quartet&n=5&t=9&w=$h'), isNull, reason: 'four words');
      expect(p('l=en&m=classic&n=5&t=6&w=nothex'), isNull);
      expect(p('l=en&m=classic&n=3&t=6&w=$h'), isNull, reason: 'length');
      expect(p('l=en&m=classic&n=5&t=0&w=$h'), isNull, reason: 'tries');
      expect(p('l=en&m=classic&n=5&t=2&w=$h&g=crane.slate.audio'), isNull);
      expect(p('l=en&m=classic&n=5&t=6&w=$h&g=cran'), isNull, reason: 'length');
      expect(p('l=en&m=classic&d=2026-10-24'), isNull, reason: 'no day links');
    });
  });

  group('opening a link', () {
    Future<WordBank> english(WidgetTester tester) async =>
        (await tester.runAsync(
          () async => WordBank.load(
            (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
          ),
        ))!;

    Future<void> open(WidgetTester tester, String link) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: link,
          onGenerateRoute: onGenerateRoute,
          onGenerateInitialRoutes: onGenerateInitialRoutes,
        ),
      );
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();
    }

    String routeOf(Puzzle p) => p.link.substring(p.link.indexOf('#') + 1);

    testWidgets('a classic puzzle is played as practice, nothing counted', (
      tester,
    ) async {
      final bank = await english(tester);
      final answer = bank.answers(5)[100];
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.classic,
            length: 5,
            tries: 6,
            answers: [answer],
          ),
        ),
      );
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.textContaining('practice'), findsOneWidget);
      // the colours and the tries left, no skill or luck while playing
      expect(find.text('6 tries left'), findsOneWidget);
      for (final ch in answer.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('solved in 1 of 6'), findsOneWidget);
      expect(find.text('practice · not counted'), findsOneWidget);
      expect(appState.history.games, isEmpty);
      expect(appState.stats.played, 0);
      expect(appState.dailyLogOf('en'), isEmpty);
      expect(appState.unlockedCount, 0);
    });

    testWidgets('the length and the tries are the link\'s', (tester) async {
      final bank = await english(tester);
      final answer = bank.answers(7)[10];
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.classic,
            length: 7,
            tries: 4,
            answers: [answer],
          ),
        ),
      );
      expect(find.text('4 tries left'), findsOneWidget);
    });

    testWidgets('a quartet puzzle opens its four words', (tester) async {
      final bank = await english(tester);
      final words = [
        for (final i in [3, 30, 300, 1000]) bank.answers(5)[i],
      ];
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.quartet,
            length: 5,
            tries: 9,
            answers: words,
          ),
        ),
      );
      final page = tester.widget<MultiGamePage>(find.byType(MultiGamePage));
      expect(page.practice, isTrue);
      expect(page.daily!.answers, words);
      expect(page.daily!.tries, 9);
    });

    testWidgets('the language is the link\'s, not the player\'s', (
      tester,
    ) async {
      final bank = await english(tester);
      await appState.load();
      appState.setup(lang: 'fr');
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.classic,
            length: 5,
            tries: 6,
            answers: [bank.answers(5)[7]],
          ),
        ),
      );
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.textContaining('english'), findsOneWidget);
    });

    testWidgets('a link whose word is not in the list goes home', (
      tester,
    ) async {
      await english(tester);
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.classic,
            length: 5,
            tries: 6,
            answers: ['zzzzz'],
          ),
        ),
      );
      expect(find.byType(GamePage), findsNothing);
      expect(find.byType(HomePage), findsWidgets);
      await open(tester, '/puzzle?l=xx&m=classic');
      expect(find.byType(GamePage), findsNothing);
    });

    testWidgets('a link with the guesses opens already played', (tester) async {
      final bank = await english(tester);
      final answer = bank.answers(5)[50];
      await open(
        tester,
        routeOf(
          Puzzle.hashed(
            'en',
            GameMode.classic,
            length: 5,
            tries: 6,
            answers: [answer],
            guesses: ['crane', 'slate'],
          ),
        ),
      );
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.text('4 tries left'), findsOneWidget);
      expect(appState.history.games, isEmpty);
      expect(appState.stats.played, 0);
    });

    testWidgets(
      'the share menu copies the puzzle hashed, or with the guesses',
      (tester) async {
        final bank = await english(tester);
        final answer = bank.answers(5)[200];
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await open(
          tester,
          routeOf(
            Puzzle.hashed(
              'en',
              GameMode.classic,
              length: 5,
              tries: 6,
              answers: [answer],
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('share-puzzle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('share-word')));
        await tester.pump();
        expect(find.text('link copied'), findsOneWidget);
        expect(copied, isNot(contains(answer)), reason: 'the word is hashed');
        expect(copied, contains(wordHash(answer)));
        expect(copied, isNot(contains('&g=')));
        expect(
          Puzzle.parse(
            uriOf(
              Puzzle.parse(
                Uri.parse(copied!.substring(copied!.indexOf('#') + 1)),
              )!,
            ),
          )!.answersIn(bank),
          [answer],
        );
        // with a guess made, the guesses go in plain
        for (final ch in 'crane'.split('')) {
          await tester.sendKeyEvent(_key(ch), character: ch);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('share-puzzle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('share-guesses')));
        await tester.pump();
        expect(copied, contains('&g=crane'));
        expect(copied, isNot(contains(answer)));
      },
    );

    testWidgets('an ordinary game can be shared, a daily cannot', (
      tester,
    ) async {
      final bank = await english(tester);
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      appState.setup(lang: 'en', length: 5, tries: 6);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('share-puzzle')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: bank, daily: Daily.of(bank, '2026-10-24')),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('share-puzzle')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: MultiGamePage(
            bank: bank,
            daily: DailyMulti.of(bank, GameMode.quartet, '2026-10-24'),
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('share-puzzle')), findsNothing);
    });
  });
}
