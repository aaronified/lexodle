import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_wheel.dart';
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

    testWidgets('says which it is, just above the play row', (tester) async {
      await home(tester);
      expect(tester.widget<Text>(label()).data, 'common words likelier');
      appState.setup(useFrequency: false);
      await tester.pump();
      expect(tester.widget<Text>(label()).data, 'all words equally likely');
      final row = tester.getRect(find.byKey(const ValueKey('frequency-row')));
      final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
      expect(row.bottom, lessThanOrEqualTo(play.top));
      expect(play.top - row.bottom, lessThan(16));
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

  group('mode on the play row', () {
    testWidgets('the mode name is under play', (tester) async {
      for (final m in GameMode.values) {
        appState.setup(mode: m);
        await home(tester);
        expect(find.widgetWithText(FilledButton, 'play'), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(FilledButton, 'play'),
            matching: find.text(m.label),
          ),
          findsOneWidget,
          reason: m.label,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the game modes icon follows the mode', (tester) async {
      await home(tester);
      final seen = <IconData>{};
      for (final m in GameMode.values) {
        appState.setup(mode: m);
        await tester.pump();
        final icon = find.byKey(ValueKey('modes-icon-${m.name}'));
        expect(icon, findsOneWidget, reason: m.name);
        expect(
          find.descendant(of: find.byTooltip('game modes'), matching: icon),
          findsOneWidget,
        );
        seen.add(tester.widget<Icon>(icon).icon!);
      }
      expect(seen.length, GameMode.values.length);
    });

    testWidgets('play, daily and game modes are the row; the style is not', (
      tester,
    ) async {
      await home(tester);
      final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
      final daily = tester.getRect(find.byKey(const ValueKey('daily-button')));
      final modes = tester.getRect(
        find.descendant(
          of: find.byTooltip('game modes'),
          matching: find.byType(OutlinedButton),
        ),
      );
      final style = tester.getRect(find.byKey(const ValueKey('style-chip')));
      expect(daily.top, play.top);
      expect(modes.top, play.top);
      expect(play.right, lessThan(daily.left));
      expect(daily.right, lessThan(modes.left));
      expect(modes.width, modes.height);
      expect(style.bottom, lessThan(play.top));
    });
  });

  group('the mode wheel', () {
    GameMode mode = GameMode.classic;
    var plays = 0;

    Future<void> wheel(WidgetTester tester, GameMode start) async {
      mode = start;
      plays = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) => ModeWheel(
                    mode: mode,
                    onChanged: (m) => setState(() => mode = m),
                    onPlay: () => plays++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final target = find.byKey(const ValueKey('mode-wheel'));

    testWidgets('shows play, the mode and a chevron on each side', (
      tester,
    ) async {
      await wheel(tester, GameMode.classic);
      expect(find.text('play'), findsOneWidget);
      expect(find.text('classic'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('a long drag left goes to the next mode, and loops', (
      tester,
    ) async {
      await wheel(tester, GameMode.classic);
      await tester.drag(target, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.quartet);
      await tester.drag(target, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.relay);
      await tester.drag(target, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.classic);
      expect(find.text('classic'), findsOneWidget);
      expect(plays, 0);
    });

    testWidgets('a long drag right goes back, and loops the other way', (
      tester,
    ) async {
      await wheel(tester, GameMode.classic);
      await tester.drag(target, const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.relay);
      await tester.drag(target, const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.quartet);
    });

    testWidgets('a fling changes it even when short', (tester) async {
      await wheel(tester, GameMode.quartet);
      await tester.fling(target, const Offset(-60, 0), 2000);
      await tester.pumpAndSettle();
      expect(mode, GameMode.relay);
    });

    testWidgets('a short drag springs back and plays nothing', (tester) async {
      await wheel(tester, GameMode.classic);
      await tester.drag(target, const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(mode, GameMode.classic);
      expect(plays, 0);
      expect(find.text('play'), findsOneWidget);
      expect(find.text('quartet'), findsNothing);
      // back in place
      final center = tester.getCenter(find.text('play')).dx;
      expect(center, closeTo(tester.getCenter(target).dx, 1));
    });

    testWidgets(
      'the content follows the finger, with the next name coming in',
      (tester) async {
        await wheel(tester, GameMode.classic);
        final start = tester.getCenter(find.text('classic')).dx;
        final g = await tester.startGesture(tester.getCenter(target));
        await g.moveBy(const Offset(-30, 0));
        await g.moveBy(const Offset(-60, 0));
        await tester.pump();
        expect(tester.getCenter(find.text('classic')).dx, lessThan(start - 50));
        // dragging left: the next mode (quartet) comes in from the right
        expect(find.text('quartet'), findsOneWidget);
        expect(tester.getCenter(find.text('quartet')).dx, greaterThan(start));
        await g.moveBy(const Offset(120, 0));
        await tester.pump();
        // dragging right of rest: the previous one (relay race) from the left
        expect(find.text('relay race'), findsOneWidget);
        await g.up();
        await tester.pumpAndSettle();
        expect(mode, GameMode.classic);
      },
    );

    testWidgets('a tap still plays', (tester) async {
      await wheel(tester, GameMode.classic);
      await tester.tap(find.widgetWithText(FilledButton, 'play'));
      await tester.pumpAndSettle();
      expect(plays, 1);
      expect(mode, GameMode.classic);
    });

    testWidgets('on home, a swipe changes the app mode, not the page', (
      tester,
    ) async {
      await home(tester);
      await tester.drag(
        find.byKey(const ValueKey('mode-wheel')),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(appState.mode, GameMode.quartet);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byKey(const ValueKey('modes-icon-quartet')), findsOneWidget);
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
