import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(
      lang: 'en',
      length: 5,
      tries: 6,
      mode: GameMode.classic,
      useFrequency: true,
    );
    appState.ach.clear();
  });

  Future<void> home(
    WidgetTester tester, [
    Size size = const Size(420, 1700),
  ]) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
  }

  group('frequency row', () {
    Finder label() => find.byKey(const ValueKey('frequency-label'));

    testWidgets('says which it is, just above the mode button', (tester) async {
      await home(tester);
      expect(tester.widget<Text>(label()).data, 'common words likelier');
      appState.setup(useFrequency: false);
      await tester.pump();
      expect(tester.widget<Text>(label()).data, 'all words equally likely');
      final row = tester.getRect(find.byKey(const ValueKey('frequency-row')));
      final mode = tester.getRect(find.byKey(const ValueKey('mode-button')));
      expect(row.bottom, lessThanOrEqualTo(mode.top));
      expect(mode.top - row.bottom, lessThan(16));
    });

    testWidgets('the switch toggles it and a toast says more', (tester) async {
      await home(tester);
      final sw = find.byKey(const ValueKey('frequency-switch'));
      expect(tester.widget<Switch>(sw).value, isTrue);
      await tester.tap(sw);
      await tester.pump();
      expect(appState.useFrequency, isFalse);
      expect(
        find.textContaining('every word of the length is equally likely'),
        findsOneWidget,
      );
      // the row is tappable too, and only one toast shows at a time
      await tester.tap(find.byKey(const ValueKey('frequency-row')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(appState.useFrequency, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('answers are drawn by how common'),
        findsOneWidget,
      );
      expect(find.textContaining('every word of the length'), findsNothing);
      // it goes away by itself
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('the mode button above play', () {
    testWidgets('it names the mode; play shows no mode text', (tester) async {
      for (final m in GameMode.values) {
        appState.setup(mode: m);
        await home(tester);
        expect(find.byKey(ValueKey('mode-name-${m.name}')), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(FilledButton, 'play'),
            matching: find.text(m.label),
          ),
          findsNothing,
          reason: m.label,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the button is above play and the daily, which share a row', (
      tester,
    ) async {
      await home(tester);
      final mode = tester.getRect(find.byKey(const ValueKey('mode-button')));
      final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
      final daily = tester.getRect(find.byKey(const ValueKey('daily-button')));
      final style = tester.getRect(find.byKey(const ValueKey('style-chip')));
      expect(mode.bottom, lessThan(play.top));
      expect(daily.top, play.top);
      expect(play.right, lessThan(daily.left));
      expect(style.bottom, lessThan(mode.top));
    });

    testWidgets('the chevrons turn the loop both ways', (tester) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('mode-next')));
      await tester.pump();
      expect(appState.mode, GameMode.quartet);
      await tester.tap(find.byKey(const ValueKey('mode-next')));
      await tester.pump();
      expect(appState.mode, GameMode.relay);
      await tester.tap(find.byKey(const ValueKey('mode-next')));
      await tester.pump();
      expect(appState.mode, GameMode.classic);
      await tester.tap(find.byKey(const ValueKey('mode-prev')));
      await tester.pump();
      expect(appState.mode, GameMode.relay);
    });

    testWidgets('a swipe over the area changes the mode, not the page', (
      tester,
    ) async {
      await home(tester);
      await tester.drag(
        find.byKey(const ValueKey('mode-button')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(appState.mode, GameMode.quartet);
      expect(find.byType(HomePage), findsOneWidget);
      await tester.drag(
        find.widgetWithText(FilledButton, 'play'),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      expect(appState.mode, GameMode.classic);
    });

    testWidgets('a short drag does nothing, a tap opens the game modes', (
      tester,
    ) async {
      await home(tester);
      await tester.drag(
        find.byKey(const ValueKey('mode-button')),
        const Offset(-20, 0),
      );
      await tester.pumpAndSettle();
      expect(appState.mode, GameMode.classic);
      await tester.tap(find.byKey(const ValueKey('mode-button')));
      await tester.pumpAndSettle();
      expect(find.byType(DifficultyMatrix), findsOneWidget);
    });

    testWidgets('the dots show where the mode is in the loop', (tester) async {
      await home(tester);
      Color dot(GameMode m) =>
          ((tester
                      .widget<Container>(
                        find.byKey(ValueKey('mode-dot-${m.name}')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color)!;
      expect(dot(GameMode.classic), isNot(dot(GameMode.quartet)));
      expect(dot(GameMode.quartet), dot(GameMode.relay));
    });

    testWidgets('the daily and its streak follow the mode', (tester) async {
      appState.setup(mode: GameMode.quartet);
      appState.recordDaily(dailyDate(), dailySolved, mode: GameMode.quartet);
      await home(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('streak-mode'))).data,
        'quartet',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('streak-count'))).data,
        '1',
      );
      appState.setup(mode: GameMode.classic);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('streak-count'))).data,
        '0',
      );
    });
  });

  group('the playstyle and history row', () {
    testWidgets('sits under achievements, with history as a text button', (
      tester,
    ) async {
      await home(tester);
      final ach = tester.getRect(
        find.byKey(const ValueKey('achievements-button')),
      );
      final style = tester.getRect(find.byKey(const ValueKey('style-chip')));
      final hist = tester.getRect(find.byKey(const ValueKey('history-button')));
      expect(style.top, greaterThan(ach.bottom));
      expect(hist.top, style.top);
      expect(style.left, lessThan(hist.left));
      expect(style.width, style.height);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-button')),
          matching: find.text('history'),
        ),
        findsOneWidget,
      );
      final how = tester.getRect(find.byKey(const ValueKey('how-to-button')));
      expect(how.top, greaterThan(hist.bottom));
    });

    testWidgets('history opens the history page', (tester) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('history-button')));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HistoryPage), findsNothing);
    });

    testWidgets('the playstyle button opens the playstyle card', (
      tester,
    ) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('style-chip')));
      await tester.pumpAndSettle();
      expect(find.byType(PlaystyleDialog), findsOneWidget);
      expect(find.byType(HistoryPage), findsNothing);
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
    });

    testWidgets('both layouts have it', (tester) async {
      for (final size in [const Size(420, 900), const Size(1000, 900)]) {
        await home(tester, size);
        expect(find.byKey(const ValueKey('history-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('style-chip')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('latest achievements on the achievements button', () {
    Finder glyphs() => find.byKey(const ValueKey('recent-achievements'));

    testWidgets('none when nothing is unlocked', (tester) async {
      await home(tester);
      expect(glyphs(), findsNothing);
    });

    testWidgets('the three newest by date, newest first', (tester) async {
      appState.ach['first_light'] = AchState(times: 1, dates: ['2026-01-01']);
      appState.ach['one_shot'] = AchState(
        times: 2,
        dates: ['2026-02-01', '2026-05-01'],
      );
      appState.ach['last_1'] = AchState(times: 1, dates: ['2026-03-01']);
      appState.ach['quick_4'] = AchState(times: 1, dates: ['2026-04-01']);
      await home(tester);
      expect(glyphs(), findsOneWidget);
      Finder g(String id) => find.byKey(ValueKey('recent-ach-$id'));
      expect(g('one_shot'), findsOneWidget);
      expect(g('quick_4'), findsOneWidget);
      expect(g('last_1'), findsOneWidget);
      expect(g('first_light'), findsNothing);
      // newest first, left to right, inside the achievements button
      final xs = [
        for (final id in ['one_shot', 'quick_4', 'last_1'])
          tester.getCenter(g(id)).dx,
      ];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('achievements-button')),
          matching: glyphs(),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('achievements-button')),
          matching: find.textContaining('achievements  '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('fewer than three show what there is', (tester) async {
      appState.ach['first_light'] = AchState(times: 1, dates: ['2026-01-01']);
      await home(tester);
      expect(
        find.byKey(const ValueKey('recent-ach-first_light')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: glyphs(), matching: find.byType(Padding)),
        findsOneWidget,
      );
    });
  });

  group('language popup', () {
    testWidgets('has the app background and a rectangular shape', (
      tester,
    ) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('language-button')));
      await tester.pumpAndSettle();
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final scaffold = Theme.of(tester.element(find.byType(Dialog)))
          .scaffoldBackgroundColor;
      expect(dialog.backgroundColor, scaffold);
      expect(dialog.surfaceTintColor, Colors.transparent);
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(3));
      expect(shape.side.width, greaterThan(0));
      // what is drawn is that colour too
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, scaffold);
    });
  });
}
