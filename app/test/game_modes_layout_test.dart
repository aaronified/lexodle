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
      final slider = top(find.byKey(const ValueKey('share-slider')));
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
        lessThan(100),
      ); // the daily note sits between
    },
  );

  testWidgets('game modes: in classic the shared-letters slider is greyed', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    final slider = find.byKey(const ValueKey('share-slider'));
    // it keeps its place under the mode, but one word has nothing to share
    expect(
      tester.getTopLeft(find.text('shared letters')).dy,
      lessThan(tester.getTopLeft(find.text('difficulty')).dy),
    );
    expect(tester.widget<Slider>(slider).onChanged, isNull);
  });
}
