import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  late WordBank bank;

  Future<void> guess(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  Future<void> loadBank(WidgetTester tester) async {
    await appState.load();
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
  }

  /// Double taps [a] then [b], [ms] apart, and says whether greens locked
  /// (a toast says so).
  Future<bool> doubleTap(
    WidgetTester tester,
    Offset a,
    Offset b, {
    int ms = 100,
  }) async {
    // no toast left from an earlier try
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(a);
    await tester.pump(Duration(milliseconds: ms));
    await tester.tapAt(b);
    await tester.pump(const Duration(milliseconds: 400));
    final locked = find.text('all greens are locked').evaluate().isNotEmpty;
    return locked;
  }

  testWidgets('a double tap on the guesses locks the greens, the gaps between '
      'the rows and the tiles too', (tester) async {
    await loadBank(tester);
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          bank: bank,
          mode: GameMode.classic,
          practice: true,
          daily: const Daily('', 'crane', length: 5, tries: 6),
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    await guess(tester, 'stare');
    await guess(tester, 'slate');
    final t00 = tester.getRect(find.byKey(const ValueKey('tile-0-0')));
    final t01 = tester.getRect(find.byKey(const ValueKey('tile-0-1')));
    final t10 = tester.getRect(find.byKey(const ValueKey('tile-1-0')));
    final onTile = t00.center;
    final betweenTiles = Offset((t00.right + t01.left) / 2, t00.center.dy);
    final betweenRows = Offset(t00.center.dx, (t00.bottom + t10.top) / 2);
    expect(await doubleTap(tester, onTile, onTile), isTrue, reason: 'a tile');
    expect(
      await doubleTap(tester, betweenTiles, betweenTiles),
      isTrue,
      reason: 'between tiles',
    );
    expect(
      await doubleTap(tester, betweenRows, betweenRows),
      isTrue,
      reason: 'the gap between two rows',
    );
    expect(
      await doubleTap(tester, onTile, t10.center),
      isTrue,
      reason: 'one tap on a row, the next on another',
    );
    expect(
      await doubleTap(tester, onTile, betweenRows),
      isTrue,
      reason: 'a tile then the gap under it',
    );
    // the row being typed is not part of it
    final typed = tester.getCenter(find.byKey(const ValueKey('tile-2-0')));
    expect(await doubleTap(tester, typed, typed), isFalse);
  });

  testWidgets('on a quartet the gaps of a board count too', (tester) async {
    await loadBank(tester);
    appState.setup(lang: 'en', length: 5, mode: GameMode.quartet);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiGamePage(
          bank: bank,
          practice: true,
          daily: DailyMulti(
            '',
            GameMode.quartet,
            const ['crane', 'plumb', 'ghost', 'fifty'],
            length: 5,
            tries: 9,
          ),
        ),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    await guess(tester, 'stare');
    await guess(tester, 'slate');
    final area = tester.getRect(find.byKey(const ValueKey('greens-area-0')));
    // the middle of the gap under the first row of board 1
    final rows = area.height / 2;
    final inGap = Offset(area.center.dx, area.top + rows - 3);
    expect(await doubleTap(tester, inGap, inGap), isTrue);
  });
}
