import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/lex.dart';
import 'package:lexodle/lex_page.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/logic.dart' show Mark;
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.lex = Lex();
  });

  Future<void> show(WidgetTester tester, Widget w) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: w)),
      ),
    );
  }

  group('chip and bar', () {
    testWidgets('LexChip is 28px high and shows the number', (tester) async {
      await show(tester, const LexChip(38));
      expect(find.text('38'), findsOneWidget);
      expect(tester.getSize(find.byType(LexChip)).height, 28);
    });

    testWidgets('HintBar looks 28px, taps 44px, and calls back', (
      tester,
    ) async {
      var taps = 0;
      await show(
        tester,
        HintBar(free: 1, lex: 12, onTap: () => taps++, expanded: true),
      );
      expect(find.text('hint'), findsOneWidget);
      expect(find.text('1 free'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(tester.getSize(find.byType(HintBar)).height, 44);
      expect(tester.getSize(find.byType(LexChip)).height, 28);
      await tester.tapAt(
        tester.getTopRight(find.byType(HintBar)) + const Offset(-4, 40),
      );
      expect(taps, 1);
    });

    testWidgets('HintBar hides the free count and the chip', (tester) async {
      await show(tester, HintBar(free: 0, lex: null, onTap: () {}));
      expect(find.text('hint'), findsOneWidget);
      expect(find.textContaining('free'), findsNothing);
      expect(find.byType(LexChip), findsNothing);
    });
  });

  group('hold row', () {
    Widget row({
      int free = 0,
      int lex = 30,
      HintKind kind = HintKind.yellow,
      required VoidCallback onBuy,
    }) => HintHoldRow(
      kind: kind,
      price: kind.price,
      free: free,
      lex: lex,
      onBuy: onBuy,
    );

    testWidgets('holding to the end buys once', (tester) async {
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HintHoldRow)),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(bought, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(bought, 1);
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(bought, 1);
    });

    testWidgets('an early release buys nothing and resets the bar', (
      tester,
    ) async {
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HintHoldRow)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(bought, 0);
      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('hold-fill')),
      );
      expect(fill.widthFactor, 0);
    });

    testWidgets('dragging away cancels', (tester) async {
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HintHoldRow)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await g.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(seconds: 2));
      expect(bought, 0);
      await g.up();
    });

    testWidgets('a plain tap buys nothing and says to keep holding', (
      tester,
    ) async {
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      await tester.tap(find.byType(HintHoldRow));
      await tester.pump();
      expect(bought, 0);
      expect(find.text('keep holding until the bar is full'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the keyboard path arms, then buys', (tester) async {
      final handle = tester.ensureSemantics();
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      tester.semantics.tap(find.semantics.byAction(SemanticsAction.tap).first);
      await tester.pump();
      expect(bought, 0);
      expect(find.text('press again to buy for 25 lex'), findsOneWidget);
      tester.semantics.tap(find.semantics.byAction(SemanticsAction.tap).first);
      await tester.pump();
      expect(bought, 1);
      expect(find.textContaining('hold to buy'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an armed row relaxes after four seconds', (tester) async {
      final handle = tester.ensureSemantics();
      var bought = 0;
      await show(tester, row(onBuy: () => bought++));
      tester.semantics.tap(find.semantics.byAction(SemanticsAction.tap).first);
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('hold to buy'), findsOneWidget);
      expect(bought, 0);
      handle.dispose();
    });

    testWidgets('a free hint shows the free chip', (tester) async {
      await show(tester, row(free: 2, lex: 0, onBuy: () {}));
      expect(find.text('free · 2'), findsOneWidget);
      expect(find.byType(LexChip), findsNothing);
    });

    testWidgets('one that cannot be afforded is disabled', (tester) async {
      var bought = 0;
      await show(tester, row(lex: 20, onBuy: () => bought++));
      expect(
        find.text('you need 5 more lex · earn it from achievement medals'),
        findsOneWidget,
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HintHoldRow)),
      );
      await tester.pump(const Duration(seconds: 1));
      await g.up();
      expect(bought, 0);
    });

    testWidgets('reduced motion: no sweep, a tap arms and a second buys', (
      tester,
    ) async {
      var bought = 0;
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: row(onBuy: () => bought++)),
          ),
        ),
      );
      await tester.tap(find.byType(HintHoldRow));
      await tester.pump();
      expect(bought, 0);
      expect(find.text('press again to buy for 25 lex'), findsOneWidget);
      await tester.tap(find.byType(HintHoldRow));
      await tester.pump();
      expect(bought, 1);
    });
  });

  group('mini rows', () {
    testWidgets('green: five tiles, one solid', (tester) async {
      await show(
        tester,
        const HintMiniRow(kind: HintKind.green, letter: 'r', pos: 1),
      );
      expect(find.byType(MarkTile), findsNWidgets(5));
      expect(find.text('in its place'), findsOneWidget);
      expect(tester.getSize(find.byType(MarkTile).first), const Size(22, 22));
      expect(
        tester
            .widgetList<MarkTile>(find.byType(MarkTile))
            .where((t) => t.mark == Mark.correct)
            .length,
        1,
      );
    });

    testWidgets('yellow and grey: one tile and a caption', (tester) async {
      await show(tester, const HintMiniRow(kind: HintKind.yellow, letter: 'a'));
      expect(find.byType(MarkTile), findsOneWidget);
      expect(find.text('is in the word, somewhere'), findsOneWidget);
      await show(tester, const HintMiniRow(kind: HintKind.grey, letter: 'z'));
      expect(find.byType(MarkTile), findsOneWidget);
      expect(find.text('is not in the word'), findsOneWidget);
    });
  });

  group('page', () {
    Future<void> page(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2000));
      await tester.pumpWidget(const MaterialApp(home: LexPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('an empty ledger', (tester) async {
      await page(tester);
      expect(find.text('lex'), findsOneWidget);
      expect(find.text('earned today: 0'), findsOneWidget);
      expect(find.text('how to earn it'), findsOneWidget);
      expect(find.text('hints cost'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('buy lex'), findsOneWidget);
      expect(find.textContaining('soon'), findsOneWidget);
      await tester.tap(find.text('the details'));
      await tester.pumpAndSettle();
      expect(find.text('nothing yet'), findsOneWidget);
    });

    testWidgets('a filled ledger', (tester) async {
      final lex = appState.lex;
      lex.activate(10, veteran: true);
      lex.earn(
        [achievementById('wins')!.atLevel(1)],
        lang: 'en',
        today: '2026-11-13',
        hinted: false,
      );
      final game = GameHints();
      lex.spend(game, HintKind.grey, guesses: 1);
      await page(tester);
      expect(find.text('earned today: 2'), findsOneWidget);
      await tester.tap(find.text('the details'));
      await tester.pumpAndSettle();
      expect(find.text('regular'), findsWidgets);
      expect(find.text('starting grant'), findsOneWidget);
      expect(find.text('hint · rule one out'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);
    });
  });
}
