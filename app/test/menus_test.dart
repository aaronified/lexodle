import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/stepper_choice.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', length: 5, tries: 6, pool: 3000);
  });

  Future<void> home(
    WidgetTester tester, [
    Size size = const Size(420, 1700),
  ]) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
  }

  group('home', () {
    testWidgets('no longer has the letters or the difficulty', (tester) async {
      await home(tester);
      expect(find.byType(StepperChoice<int>), findsNothing);
      expect(find.byType(DifficultyMatrix), findsNothing);
      expect(find.text('5 letters'), findsNothing);
    });

    testWidgets('keeps the language, the streak, play and daily', (
      tester,
    ) async {
      await home(tester);
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-streak')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'play'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-button')), findsOneWidget);
    });

    testWidgets(
      'has game modes and settings as two square buttons side by side',
      (tester) async {
        await home(tester);
        final modes = tester.getRect(
          find.descendant(
            of: find.byTooltip('game modes'),
            matching: find.byType(OutlinedButton),
          ),
        );
        final settings = tester.getRect(
          find.descendant(
            of: find.byTooltip('settings'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(modes.width, modes.height);
        expect(settings.size, modes.size);
        expect(modes.top, settings.top, reason: 'on one row');
        expect(modes.right, lessThan(settings.left), reason: 'side by side');
      },
    );

    testWidgets('about is an i button, at least 48 dp, that opens about', (
      tester,
    ) async {
      await home(tester);
      final about = find.byTooltip('about');
      expect(about, findsOneWidget);
      expect(find.text('about'), findsNothing, reason: 'no text link');
      final size = tester.getSize(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'about'),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('about'), findsWidgets);
      await tester.tap(about);
      await tester.pumpAndSettle();
      expect(find.byType(AboutDialog), findsOneWidget);
    });

    testWidgets(
      'has achievements and how to play as full buttons with a count',
      (tester) async {
        await home(tester);
        final play = tester.getSize(find.widgetWithText(FilledButton, 'play'));
        final achievements = find.byKey(const ValueKey('achievements-button'));
        final howTo = find.byKey(const ValueKey('how-to-button'));
        for (final b in [achievements, howTo]) {
          expect(tester.widget(b), isA<OutlinedButton>());
          expect(
            tester.getSize(b).height,
            play.height,
            reason: 'as tall as play',
          );
        }
        // full width: as wide as the page's content, which holds play and the rest
        final content = tester.getSize(
          find.byKey(const ValueKey('daily-streak')),
        );
        expect(tester.getSize(achievements).width, content.width);
        expect(tester.getSize(howTo).width, content.width);
        // the unlocked and total count stays
        expect(
          find.descendant(
            of: achievements,
            matching: find.textContaining('achievements  0/'),
          ),
          findsOneWidget,
        );
        await tester.tap(achievements);
        await tester.pumpAndSettle();
        expect(find.text('achievements'), findsWidgets);
      },
    );
  });

  group('game modes', () {
    Future<void> open(WidgetTester tester) async {
      await home(tester);
      await tester.tap(find.byTooltip('game modes'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'holds mode, letters, difficulty, shared letters, helper and the buttons, in order',
      (tester) async {
        await open(tester);
        double y(Finder f) => tester.getTopLeft(f).dy;
        final order = [
          y(find.text('mode')),
          y(find.text('letters')),
          y(find.text('difficulty')),
          y(find.text('shared letters')),
          y(find.text('helper')),
          y(find.byKey(const ValueKey('settings-play'))),
          y(find.text('open the solver')),
          y(find.byKey(const ValueKey('settings-learn'))),
        ];
        expect([...order]..sort(), order, reason: 'top to bottom');
        expect(find.byType(DifficultyMatrix), findsOneWidget);
        expect(find.byType(StepperChoice<int>), findsOneWidget);
      },
    );

    testWidgets('changing the letters there changes the length play uses', (
      tester,
    ) async {
      await open(tester);
      final letters = find.byType(StepperChoice<int>);
      await tester.tap(
        find.descendant(
          of: letters,
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pumpAndSettle();
      expect(appState.length, 6);
      expect(find.text('6 letters'), findsOneWidget);
      // play from here, as a player does, and the game takes six letters
      // (the word list is read with real file IO, so it is read first)
      await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('settings-play')));
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('need 6 letters'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets(
      'keeps only theme, backup, and support (updates only on Android)',
      (tester) async {
        await home(tester);
        await tester.tap(find.byTooltip('settings'));
        await tester.pumpAndSettle();
        expect(find.text('theme'), findsOneWidget);
        expect(find.text('backup'), findsOneWidget);
        expect(find.text('support lexodle'), findsOneWidget);
        // what moved to game modes is not here
        for (final gone in [
          'mode',
          'letters',
          'difficulty',
          'helper',
          'shared letters',
        ]) {
          expect(find.text(gone), findsNothing, reason: gone);
        }
        expect(find.text('open the solver'), findsNothing);
        expect(find.byKey(const ValueKey('settings-play')), findsNothing);
      },
    );
  });

  group('the play row is pinned only when the page does not fit', () {
    Finder pinned() => find.byKey(const ValueKey('pinned-play'));
    Finder inPage() => find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.widgetWithText(FilledButton, 'play'),
    );

    testWidgets('a tall screen keeps it in the page', (tester) async {
      await home(tester, const Size(420, 1700));
      expect(pinned(), findsNothing);
      expect(inPage(), findsOneWidget);
    });

    testWidgets(
      'a short screen pins it to the bottom, off the scrolling page',
      (tester) async {
        await home(tester, const Size(420, 480));
        expect(pinned(), findsOneWidget);
        expect(inPage(), findsNothing);
        final bar = tester.getRect(pinned());
        expect(bar.bottom, closeTo(480, 1));
        // and both play and daily are there, tappable
        expect(
          find.descendant(
            of: pinned(),
            matching: find.widgetWithText(FilledButton, 'play'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: pinned(),
            matching: find.byKey(const ValueKey('daily-button')),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a narrow, short screen pins it without overflowing', (
      tester,
    ) async {
      await home(tester, const Size(320, 480));
      expect(pinned(), findsOneWidget);
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(pinned());
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(320));
    });

    testWidgets('growing the window puts it back in the page', (tester) async {
      await home(tester, const Size(420, 480));
      expect(pinned(), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await tester.pumpAndSettle();
      expect(pinned(), findsNothing);
      expect(inPage(), findsOneWidget);
    });
  });
}
