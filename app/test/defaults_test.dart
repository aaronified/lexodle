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

  testWidgets('the home screen says so, and play and the gear match', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('normal · wide: 6 tries, answers from the 3,000'),
      findsOneWidget,
    );

    // the gear is as tall as play and square
    final play = tester.getSize(find.widgetWithText(FilledButton, 'play'));
    final gear = tester.getSize(
      find.descendant(
        of: find.byTooltip('settings'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(gear.height, play.height);
    expect(gear.width, gear.height);

    // and its icon is drawn, in a colour that shows on the page
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    final icon = find.descendant(
      of: find.byTooltip('settings'),
      matching: find.byType(SvgPicture),
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon).width, greaterThan(16));
  });
}
