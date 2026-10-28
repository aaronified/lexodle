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

  group('the link', () {
    test('it names a language, a mode and a day, and reads back', () {
      for (final m in GameMode.values) {
        final p = Puzzle('en', m, '2026-10-24');
        expect(p.link, startsWith(puzzleBase));
        final uri = Uri.parse(p.link.substring(p.link.indexOf('#') + 1));
        expect(uri.path, Routes.puzzle);
        final back = Puzzle.parse(uri, today: '2026-10-28')!;
        expect((back.lang, back.mode, back.date), ('en', m, '2026-10-24'));
      }
    });

    test('a hashed puzzle reads back, with its guesses', () {
      final p = Puzzle.hashed(
        'fr',
        GameMode.quartet,
        length: 5,
        tries: 9,
        answers: ['crane', 'light', 'house', 'dying'],
        guesses: ['abcde', 'fghij'],
      );
      expect(p.link, isNot(contains('crane')));
      final back = Puzzle.parse(
        Uri.parse(p.link.substring(p.link.indexOf('#') + 1)),
        today: '2026-10-28',
      )!;
      expect(back.lang, 'fr');
      expect(back.mode, GameMode.quartet);
      expect((back.length, back.tries), (5, 9));
      expect(back.hashes, p.hashes);
      expect(back.guesses, ['abcde', 'fghij']);
    });

    test('the hash is the same everywhere, and tells words apart', () {
      expect(wordHash('crane'), wordHash('crane'));
      expect(wordHash('crane'), hasLength(16));
      expect(wordHash('crane'), isNot(wordHash('crate')));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(wordHash('crane')), isTrue);
    });

    test('a hashed link that is not a puzzle is not one', () {
      final h = wordHash('crane');
      Puzzle? p(String q) => Puzzle.parse(Uri.parse('/puzzle?$q'));
      expect(p('l=en&m=classic&n=5&t=6&w=$h'), isNotNull);
      expect(p('l=en&m=classic&n=5&t=6&w=$h.$h'), isNull, reason: 'one word');
      expect(p('l=en&m=quartet&n=5&t=9&w=$h'), isNull, reason: 'four words');
      expect(p('l=en&m=classic&n=5&t=6&w=nothex'), isNull);
      expect(p('l=en&m=classic&n=3&t=6&w=$h'), isNull, reason: 'length');
      expect(p('l=en&m=classic&n=5&t=0&w=$h'), isNull, reason: 'tries');
      expect(p('l=en&m=classic&n=5&t=2&w=$h&g=crane.slate.audio'), isNull);
      expect(p('l=en&m=classic&n=5&t=6&w=$h&g=cran'), isNull, reason: 'length');
    });

    test('a link that names no puzzle is not one', () {
      Puzzle? p(String q) =>
          Puzzle.parse(Uri.parse('/puzzle?$q'), today: '2026-10-28');
      expect(p('l=en&m=quartet&d=2026-10-28'), isNotNull, reason: 'today');
      expect(p('m=quartet&d=2026-10-24'), isNull, reason: 'no language');
      expect(p('l=en&d=2026-10-24'), isNull, reason: 'no mode');
      expect(p('l=en&m=blitz&d=2026-10-24'), isNull, reason: 'unknown mode');
      expect(p('l=en&m=classic'), isNull, reason: 'no day');
      expect(p('l=en&m=classic&d=yesterday'), isNull);
      expect(p('l=en&m=classic&d=2026-02-31'), isNull, reason: 'no such day');
      expect(p('l=EN!&m=classic&d=2026-10-24'), isNull, reason: 'odd language');
      expect(
        p('l=en&m=classic&d=2026-10-29'),
        isNull,
        reason: 'tomorrow would spoil it',
      );
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

    testWidgets('a classic puzzle is the daily of that day, as practice', (
      tester,
    ) async {
      final bank = await english(tester);
      final answer = Daily.of(bank, '2026-10-24')!.answer;
      await open(tester, '/puzzle?l=en&m=classic&d=2026-10-24');
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.textContaining('practice · 2026-10-24'), findsOneWidget);
      // the colours and the tries left, no skill or luck while playing
      expect(find.text('6 tries left'), findsOneWidget);
      for (final ch in answer.split('')) {
        await tester.sendKeyEvent(_key(ch), character: ch);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('solved in 1 of 6'), findsOneWidget);
      expect(find.text('practice 2026-10-24 · not counted'), findsOneWidget);
      // nothing was counted
      expect(appState.history.games, isEmpty);
      expect(appState.stats.played, 0);
      expect(appState.dailyLogOf('en'), isEmpty);
      expect(appState.dailyFor('en', '2026-10-24'), isNull);
      expect(appState.unlockedCount, 0);
    });

    testWidgets('a quartet puzzle opens the four words of that day', (
      tester,
    ) async {
      final bank = await english(tester);
      final d = DailyMulti.of(bank, GameMode.quartet, '2026-10-24')!;
      await open(tester, '/puzzle?l=en&m=quartet&d=2026-10-24');
      expect(find.byType(MultiGamePage), findsOneWidget);
      expect(find.textContaining('practice · 2026-10-24'), findsOneWidget);
      expect(d.answers, hasLength(4));
      final page = tester.widget<MultiGamePage>(find.byType(MultiGamePage));
      expect(page.practice, isTrue);
      expect(page.daily!.answers, d.answers);
    });

    testWidgets('the language is the link\'s, not the player\'s', (
      tester,
    ) async {
      await appState.load();
      appState.setup(lang: 'fr');
      await open(tester, '/puzzle?l=en&m=classic&d=2026-10-24');
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.textContaining('english'), findsOneWidget);
    });

    testWidgets('a link that names no puzzle goes home', (tester) async {
      await open(tester, '/puzzle?l=en&m=classic&d=2026-10-29');
      expect(find.byType(GamePage), findsNothing);
      expect(find.byType(HomePage), findsWidgets);
      await open(tester, '/puzzle?l=xx&m=classic&d=2026-10-24');
      expect(find.byType(GamePage), findsNothing);
    });

    testWidgets(
      'the share menu copies the puzzle, hashed, or with the guesses',
      (tester) async {
        final bank = await english(tester);
        final answers = DailyMulti.of(
          bank,
          GameMode.relay,
          '2026-10-24',
        )!.answers;
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
        await open(tester, '/puzzle?l=en&m=relay&d=2026-10-24');
        // the puzzle: the words only as hashes
        await tester.tap(find.byKey(const ValueKey('share-puzzle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('share-word')));
        await tester.pump();
        expect(find.text('link copied'), findsOneWidget);
        for (final w in answers) {
          expect(copied, isNot(contains(w)), reason: 'the word is hashed');
          expect(copied, contains(wordHash(w)));
        }
        expect(copied, isNot(contains('&g=')));
        final p = Puzzle.parse(
          Uri.parse(copied!.substring(copied!.indexOf('#') + 1)),
          today: '2026-10-28',
        )!;
        expect(p.mode, GameMode.relay);
        expect(p.answersIn(bank), answers);
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
        for (final w in answers) {
          expect(copied, isNot(contains(w)));
        }
      },
    );

    testWidgets('a link with the guesses opens already played', (tester) async {
      final bank = await english(tester);
      final answer = Daily.of(bank, '2026-10-24')!.answer;
      final p = Puzzle.hashed(
        'en',
        GameMode.classic,
        length: 5,
        tries: 6,
        answers: [answer],
        guesses: ['crane', 'slate'],
      );
      await open(tester, p.link.substring(p.link.indexOf('#') + 1));
      expect(find.byType(GamePage), findsOneWidget);
      expect(find.textContaining('shared puzzle'), findsNothing);
      expect(find.text('practice'), findsNothing);
      // two guesses are on the board, four tries are left
      expect(find.text('4 tries left'), findsOneWidget);
      expect(appState.history.games, isEmpty);
      expect(appState.stats.played, 0);
    });
  });
}
