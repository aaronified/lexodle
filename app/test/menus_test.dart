import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/licences_page.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/settings_page.dart';
import 'package:lexodle/ui.dart' show Caption;
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
      expect(find.byKey(const ValueKey('language-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-streak')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'play'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-button')), findsOneWidget);
    });

    testWidgets('the language opens a two-column popup of every language', (
      tester,
    ) async {
      await home(tester);
      expect(find.byKey(const ValueKey('language-grid')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('language-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-grid')), findsOneWidget);
      final langs = (await tester.runAsync(WordBank.languages))!;
      for (final l in langs) {
        expect(
          find.byKey(ValueKey('language-option-${l.code}')),
          findsOneWidget,
          reason: l.code,
        );
      }
      // two columns: the first two share a row, the third starts the next
      final first = tester.getTopLeft(
        find.byKey(ValueKey('language-option-${langs[0].code}')),
      );
      final second = tester.getTopLeft(
        find.byKey(ValueKey('language-option-${langs[1].code}')),
      );
      final third = tester.getTopLeft(
        find.byKey(ValueKey('language-option-${langs[2].code}')),
      );
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(third.dy, greaterThan(first.dy));
      expect(third.dx, first.dx);
    });

    testWidgets('choosing a language sets it and closes the popup', (
      tester,
    ) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('language-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-option-fr')));
      await tester.pumpAndSettle();
      expect(appState.lang, 'fr');
      expect(find.byKey(const ValueKey('language-grid')), findsNothing);
      expect(find.byKey(const ValueKey('language-name')), findsOneWidget);
    });

    testWidgets('the back button closes the popup and keeps the language', (
      tester,
    ) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('language-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-grid')), findsOneWidget);
      // the phone's back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-grid')), findsNothing);
      expect(appState.lang, 'en');
      // and the home screen is still there, not left
      expect(find.byKey(const ValueKey('language-button')), findsOneWidget);
    });

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
        // a page of its own; the about text is not on it, it is on the
        // licences page the button opens
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(const ValueKey('about-text')), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('licences-button')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('licences-button')));
        await tester.pumpAndSettle();
        expect(find.byType(LicencesPage), findsOneWidget);
        expect(find.byType(AboutDialog), findsNothing);
        expect(find.byKey(const ValueKey('about-text')), findsOneWidget);
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
      'holds mode, shared letters, difficulty, frequency, helper and the buttons, in order',
      (tester) async {
        await open(tester);
        double y(Finder f) => tester.getTopLeft(f).dy;
        final order = [
          y(find.text('mode')),
          y(find.text('shared letters')),
          y(find.text('difficulty')),
          y(find.byKey(const ValueKey('draw-stepper'))),
          y(find.text('helper')),
          y(find.byKey(const ValueKey('settings-play'))),
          y(find.text('open the solver')),
          y(find.byKey(const ValueKey('settings-learn'))),
        ];
        expect([...order]..sort(), order, reason: 'top to bottom');
        expect(find.byType(DifficultyMatrix), findsOneWidget);
        expect(find.byKey(const ValueKey('draw-stepper')), findsOneWidget);
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

    testWidgets('the word draw swiper goes through its three draws', (
      tester,
    ) async {
      await open(tester);
      final stepper = find.byKey(const ValueKey('draw-stepper'));
      await tester.ensureVisible(stepper);
      Finder chevron(String tip) =>
          find.descendant(of: stepper, matching: find.byTooltip(tip));
      expect(appState.draw, Draw.sigmoid);
      expect(find.byKey(const ValueKey('frequency-checkbox')), findsNothing);
      await tester.tap(chevron('next'));
      await tester.pumpAndSettle();
      expect(appState.draw, Draw.equal);
      await tester.tap(chevron('next'));
      await tester.pumpAndSettle();
      expect(appState.draw, Draw.frequency);
      await tester.tap(chevron('previous'));
      await tester.pumpAndSettle();
      expect(appState.draw, Draw.equal);
    });

    testWidgets('a drag on the swiper follows the finger', (tester) async {
      await open(tester);
      final stepper = find.byKey(const ValueKey('draw-stepper'));
      await tester.ensureVisible(stepper);
      final viewport = find.descendant(
        of: stepper,
        matching: find.byKey(const ValueKey('step-viewport')),
      );
      final g = await tester.startGesture(tester.getCenter(viewport));
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
      // the next draw is already coming in beside the one on show
      expect(
        find.descendant(
          of: stepper,
          matching: find.byKey(const ValueKey('step-incoming')),
        ),
        findsOneWidget,
      );
      await g.up();
      await tester.pumpAndSettle();
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

    testWidgets('the prose on the page is short, and the about text is not '
        'on it', (tester) async {
      // as on an Android phone, so the updates section is there too
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await home(tester, const Size(420, 3600));
      await tester.tap(find.byTooltip('settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-text')), findsNothing);
      expect(find.text('updates'), findsOneWidget, reason: 'built, not lazy');
      expect(find.byKey(const ValueKey('donate-pay')), findsOneWidget);
      // not prose: the buttons, the captions, the live status lines and the
      // values (the version, the UPI id)
      const notProse = {
        'app-version',
        'update-message',
        'update-backup-note',
        'backup-note',
        'backup-summary',
        'backup-auto-name',
        'log-summary',
        'log-note',
        'donate-note',
        'donate-id',
      };
      final long = <String>[];
      var seen = 0;
      for (final e
          in find
              .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final w = e.widget as Text;
        final text = w.data ?? w.textSpan?.toPlainText() ?? '';
        final key = w.key;
        if (key is ValueKey && notProse.contains(key.value)) continue;
        var skip = false;
        e.visitAncestorElements((a) {
          if (a.widget is ButtonStyleButton ||
              a.widget is Caption ||
              a.widget is AppBar) {
            skip = true;
            return false;
          }
          return true;
        });
        if (skip) continue;
        seen++;
        if (text.length > 70) long.add('${text.length}: $text');
      }
      expect(seen, greaterThan(8), reason: 'the prose lines were found');
      // (reset inside the test: the framework checks it before teardowns)
      debugDefaultTargetPlatformOverride = null;
      expect(long, isEmpty, reason: 'prose of 70 characters at most');
    });
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
      expect(find.byKey(const ValueKey('mode-name-relay')), findsOneWidget);
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
