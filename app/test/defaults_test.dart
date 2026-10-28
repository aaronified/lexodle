import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new player starts at 6 tries and draws words by frequency', () {
    final s = AppState();
    expect(s.tries, 6);
    expect(triesLevels.firstWhere((l) => l.$2 == s.tries).$1, 'normal');
    expect(s.useFrequency, isTrue);
  });

  testWidgets(
    'game modes says the default, and the square buttons match play',
    (tester) async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      await appState.load();
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();

      // the difficulty is chosen on the game modes screen, not on home
      expect(find.byKey(const ValueKey('frequency-checkbox')), findsNothing);
      await tester.tap(find.byTooltip('game modes'));
      await tester.pumpAndSettle();
      expect(find.byType(DifficultyMatrix), findsOneWidget);
      final box = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('frequency-checkbox')),
      );
      expect(
        box.value,
        isTrue,
        reason: 'words are drawn by frequency by default',
      );
      await tester.tapAt(const Offset(5, 5)); // the scrim closes it
      await tester.pumpAndSettle();

      // the playstyle and game modes boxes are as tall as play, and square
      final play = tester.getSize(find.widgetWithText(FilledButton, 'play'));
      final boxes = {'playstyle': find.byKey(const ValueKey('style-chip'))};
      for (final e in boxes.entries) {
        final size = tester.getSize(e.value);
        expect(size.height, play.height, reason: e.key);
        expect(size.width, size.height, reason: e.key);
      }

      // and their icons, and the gear's, are drawn, in a colour that shows
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      for (final f in [
        find.descendant(
          of: boxes['playstyle']!,
          matching: find.byType(SvgPicture),
        ),
        find.descendant(
          of: find.byKey(const ValueKey('mode-button')),
          matching: find.byType(SvgPicture),
        ),
        find.descendant(
          of: find.byTooltip('settings'),
          matching: find.byType(SvgPicture),
        ),
      ]) {
        expect(f, findsOneWidget);
        expect(tester.getSize(f).width, greaterThan(16));
      }
    },
  );
}
