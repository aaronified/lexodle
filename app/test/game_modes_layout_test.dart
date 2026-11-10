import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  Future<void> open(WidgetTester tester, GameMode mode) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await appState.load();
    appState.setup(lang: 'fr', length: 4, mode: mode, share: 10);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();
  }

  testWidgets('game modes: the close cross is centred in a 48 px button', (
    tester,
  ) async {
    await open(tester, GameMode.quartet);
    final button = find.byKey(const ValueKey('modes-close'));
    final icon = find.descendant(
      of: button,
      matching: find.byIcon(Icons.close),
    );
    expect(button, findsOneWidget);
    final b = tester.getRect(button);
    final i = tester.getRect(icon);
    expect(b.width, greaterThanOrEqualTo(48));
    expect(b.height, greaterThanOrEqualTo(48));
    expect((i.center.dx - b.center.dx).abs(), lessThan(0.5));
    expect((i.center.dy - b.center.dy).abs(), lessThan(0.5));
  });

  testWidgets(
    'game modes: the cross is as far from the top as from the right',
    (tester) async {
      await open(tester, GameMode.quartet);
      final dialog = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      final icon = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('modes-close')),
          matching: find.byIcon(Icons.close),
        ),
      );
      final fromRight = dialog.right - icon.right;
      final fromTop = icon.top - dialog.top;
      expect((fromRight - fromTop).abs(), lessThan(0.5));
    },
  );

  testWidgets(
    'game modes: shared letters sit right under the mode, then the rest',
    (tester) async {
      await open(tester, GameMode.quartet);
      double top(Finder f) {
        expect(f, findsOneWidget);
        return tester.getTopLeft(f).dy;
      }

      final mode = top(find.text('mode'));
      final shared = top(find.text('shared letters'));
      final slider = top(find.byKey(const ValueKey('share-stepper')));
      final difficulty = top(find.text('difficulty'));
      final frequency = top(find.byKey(const ValueKey('draw-stepper')));
      final helper = top(find.text('helper'));
      final play = top(find.byKey(const ValueKey('settings-play')));
      final learn = top(find.byKey(const ValueKey('settings-learn')));
      expect(mode, lessThan(shared));
      expect(shared, lessThan(slider));
      expect(slider, lessThan(difficulty));
      expect(difficulty, lessThan(frequency));
      expect(frequency, lessThan(helper));
      expect(helper, lessThan(play));
      expect(play, lessThan(learn));

      // nothing sits between the mode choice and the shared-letters caption
      final modeChoice = tester.getBottomLeft(
        find
            .byWidgetPredicate(
              (w) => w.runtimeType.toString().startsWith('StepperChoice'),
            )
            .first,
      );
      expect(
        shared - modeChoice.dy,
        lessThan(140),
      ); // the daily note and the more-modes line sit between
    },
  );

  testWidgets('game modes: in classic there is no shared-letters setting', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    expect(find.text('shared letters'), findsNothing);
    expect(find.byKey(const ValueKey('share-stepper')), findsNothing);
  });

  testWidgets(
    'game modes: geography (themed) has a swiper for the draw, no theme choice',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await appState.load();
      appState.setup(lang: 'en', length: 5, mode: GameMode.themed);
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('game modes'));
      await tester.pumpAndSettle();
      // the word draw swiper takes the places' values; no answers chips
      expect(find.byKey(const ValueKey('draw-stepper-themed')), findsOneWidget);
      expect(find.text('well known'), findsWidgets);
      expect(find.text('answers'), findsNothing);
      expect(find.text('shared letters'), findsNothing);
      // the themes are hidden for now: geography is the only one, and it plays
      expect(find.byKey(const ValueKey('theme-stepper')), findsNothing);
      expect(find.byKey(const ValueKey('mythology-stepper')), findsNothing);
      expect(find.text('upcoming feature'), findsNothing);
      expect(find.text('geography'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('settings-play')))
            .onPressed,
        isNotNull,
      );
    },
  );
}
