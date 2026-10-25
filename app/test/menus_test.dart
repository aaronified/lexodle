import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/stepper_choice.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', length: 5, tries: 6);
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
      'has the playstyle and game modes as square buttons on the play row',
      (tester) async {
        await home(tester);
        final style = tester.getRect(find.byKey(const ValueKey('style-chip')));
        final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
        final daily = tester.getRect(
          find.byKey(const ValueKey('daily-button')),
        );
        final modes = tester.getRect(
          find.descendant(
            of: find.byTooltip('game modes'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(style.width, style.height);
        expect(modes.size, style.size);
        // one row, in this order: playstyle, play, daily, game modes
        expect(style.top, play.top);
        expect(daily.top, play.top);
        expect(modes.top, play.top);
        expect(style.right, lessThan(play.left));
        expect(play.right, lessThan(daily.left));
        expect(daily.right, lessThan(modes.left));
      },
    );

    testWidgets(
      'settings is the gear at the top, where the i used to be, with about inside',
      (tester) async {
        await home(tester);
        // no about button on home, and no gear on the play row
        expect(find.byTooltip('about'), findsNothing);
        expect(find.text('about'), findsNothing);
        final gear = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'settings',
        );
        expect(gear, findsOneWidget);
        final size = tester.getSize(gear);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        // at the top, level with the title
        expect(
          tester.getCenter(gear).dy,
          closeTo(tester.getCenter(find.text('lexodle')).dy, 8),
        );
        expect(find.bySemanticsLabel('settings'), findsWidgets);
        await tester.tap(gear);
        await tester.pumpAndSettle();
        // a page of its own, with about in it
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(const ValueKey('about-text')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('licences-button')),
        );
        await tester.tap(find.byKey(const ValueKey('licences-button')));
        await tester.pumpAndSettle();
        expect(find.byType(AboutDialog), findsOneWidget);
      },
    );

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
      'holds mode, difficulty, shared letters, helper and the buttons, in order',
      (tester) async {
        await open(tester);
        double y(Finder f) => tester.getTopLeft(f).dy;
        final order = [
          y(find.text('mode')),
          y(find.text('difficulty')),
          y(find.text('shared letters')),
          y(find.text('helper')),
          y(find.byKey(const ValueKey('settings-play'))),
          y(find.text('open the solver')),
          y(find.byKey(const ValueKey('settings-learn'))),
        ];
        expect([...order]..sort(), order, reason: 'top to bottom');
        expect(find.byType(DifficultyMatrix), findsOneWidget);
        expect(
          find.byKey(const ValueKey('frequency-checkbox')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'choosing a length in the matrix changes the length play uses',
      (tester) async {
        await open(tester);
        await tester.tap(find.bySemanticsLabel('6 tries, 6 letters'));
        await tester.pumpAndSettle();
        expect(appState.length, 6);
        expect(appState.tries, 6);
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
      },
    );

    testWidgets(
      'the frequency checkbox turns drawing by frequency off and on',
      (tester) async {
        await open(tester);
        expect(appState.useFrequency, isTrue);
        await tester.tap(find.byKey(const ValueKey('frequency-checkbox')));
        await tester.pumpAndSettle();
        expect(appState.useFrequency, isFalse);
        await tester.tap(find.byKey(const ValueKey('frequency-checkbox')));
        await tester.pumpAndSettle();
        expect(appState.useFrequency, isTrue);
      },
    );
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

  group('the play row', () {
    Finder pinned() => find.byKey(const ValueKey('pinned-play'));
    Finder inPage() => find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.widgetWithText(FilledButton, 'play'),
    );

    testWidgets('sticks to the bottom on a phone, tall or short', (
      tester,
    ) async {
      for (final h in [480.0, 1700.0]) {
        await home(tester, Size(420, h));
        expect(pinned(), findsOneWidget, reason: 'height $h');
        expect(inPage(), findsNothing, reason: 'height $h');
        expect(tester.getRect(pinned()).bottom, closeTo(h, 1), reason: '$h');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('floats on a desktop, as the last row of the page', (
      tester,
    ) async {
      await home(tester, const Size(1000, 900));
      expect(pinned(), findsNothing);
      expect(inPage(), findsOneWidget);
      final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
      final howTo = tester.getRect(find.byKey(const ValueKey('how-to-button')));
      expect(play.top, greaterThan(howTo.bottom), reason: 'below everything');
    });

    testWidgets('is the last row on a phone too', (tester) async {
      await home(tester, const Size(420, 900));
      final play = tester.getRect(find.widgetWithText(FilledButton, 'play'));
      final howTo = tester.getRect(find.byKey(const ValueKey('how-to-button')));
      expect(play.top, greaterThan(howTo.bottom));
    });

    testWidgets('fits a narrow phone with a long mode name', (tester) async {
      appState.setup(mode: GameMode.relay);
      await home(tester, const Size(320, 480));
      expect(pinned(), findsOneWidget);
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(pinned());
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(320));
      expect(find.text('play · relay race'), findsOneWidget);
      appState.setup(mode: GameMode.classic);
    });

    testWidgets('moves into the page when the window grows to a desktop', (
      tester,
    ) async {
      await home(tester, const Size(420, 700));
      expect(pinned(), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      await tester.pumpAndSettle();
      expect(pinned(), findsNothing);
      expect(inPage(), findsOneWidget);
    });
  });
}
