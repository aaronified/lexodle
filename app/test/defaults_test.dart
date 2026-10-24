import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new player starts at 6 tries and the third word-pool rung', () {
    final s = AppState();
    expect(s.tries, 6);
    expect(triesLevels.firstWhere((l) => l.$2 == s.tries).$1, 'normal');
    expect(s.pool, 3000);
    expect(poolSizes.indexOf(s.pool), 2, reason: 'the third of four rungs');
    expect(poolLevels[2].$1, 'wide');
  });

  testWidgets('game modes says the default, and the icon buttons match play', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();

    // the difficulty is chosen on the game modes screen, not on home
    expect(find.textContaining('normal · wide'), findsNothing);
    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('normal · wide: 6 tries, answers from the 3,000'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5)); // the scrim closes it
    await tester.pumpAndSettle();

    // the two icon buttons are as tall as play, and square
    final play = tester.getSize(find.widgetWithText(FilledButton, 'play'));
    for (final tip in ['game modes', 'settings']) {
      final size = tester.getSize(
        find.descendant(
          of: find.byTooltip(tip),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(size.height, play.height, reason: tip);
      expect(size.width, size.height, reason: tip);
    }

    // and their icons are drawn, in a colour that shows on the page
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    for (final tip in ['game modes', 'settings']) {
      final icon = find.descendant(
        of: find.byTooltip(tip),
        matching: find.byType(SvgPicture),
      );
      expect(icon, findsOneWidget, reason: tip);
      expect(tester.getSize(icon).width, greaterThan(16), reason: tip);
    }
  });
}
