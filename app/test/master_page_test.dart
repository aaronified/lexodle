import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/master_game.dart';
import 'package:lexodle/master_page.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  Future<(WordBank, MasterGame)> open(
    WidgetTester tester,
    MasterKind kind,
  ) async {
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    final game = MasterGame(
      bank: bank,
      kind: kind,
      length: 5,
      answer: 'prism',
      analyse: false,
    );
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MasterPage(bank: bank, kind: kind, game: game),
      ),
    );
    return (bank, game);
  }

  Future<void> play(WidgetTester tester, MasterGame game, String w) async {
    for (final ch in w.split('')) {
      game.type(ch);
    }
    await tester.pump();
    await tester.runAsync(() => game.submit());
    await tester.pump();
  }

  testWidgets('classic: a guess, the pool, the logic and the word list', (
    tester,
  ) async {
    final (_, game) = await open(tester, MasterKind.classic);
    expect(find.text('guess the hidden word'), findsOneWidget);
    await play(tester, game, 'crane');
    expect(game.rows.length, 1);
    expect(find.textContaining('words fit'), findsOneWidget);
    expect(find.text('likeliest'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('master-logic')));
    await tester.pumpAndSettle();
    expect(find.text('the logic, letter by letter'), findsOneWidget);
    expect(find.textContaining('of the'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('master-pool')));
    await tester.pumpAndSettle();
    expect(find.textContaining('words that fit'), findsWidgets);
    expect(find.byKey(const ValueKey('master-all-words')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('master-likeliest')));
    await tester.pumpAndSettle();
    expect(find.text('likeliest answers'), findsOneWidget);
    await tester.tap(find.text('use').first);
    await tester.pumpAndSettle();
    expect(game.typed.length, 5);
  });

  testWidgets('blind: two count tiles, and a tap on a tile does not throw', (
    tester,
  ) async {
    final (_, game) = await open(tester, MasterKind.blind);
    await play(tester, game, 'crane');
    expect(find.byKey(const ValueKey('count-green-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('count-yellow-0')), findsOneWidget);
    await tester.tap(find.text('c').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('master-logic')));
    await tester.pumpAndSettle();
    expect(find.text('the logic, letter by letter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
