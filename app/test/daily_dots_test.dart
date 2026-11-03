import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_wheel.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/logic.dart' show Mark;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // the loop in English: classic quartet relay lockdown blind equations
  // mastermind themed
  group('which chevrons get a dot', () {
    ({bool prev, bool next}) dots(GameMode from, Set<GameMode> p) =>
        ModeSwitch.dotsFor(from, p);

    test('nothing pending, no dots', () {
      expect(dots(GameMode.classic, {}), (prev: false, next: false));
    });

    test('the mode in view does not count', () {
      expect(dots(GameMode.classic, {GameMode.classic}), (
        prev: false,
        next: false,
      ));
    });

    test('a pending daily one step on is on the next side', () {
      expect(dots(GameMode.classic, {GameMode.quartet}), (
        prev: false,
        next: true,
      ));
    });

    test('one step back round the loop is on the previous side', () {
      // themed is just before classic
      expect(dots(GameMode.classic, {GameMode.equations}), (
        prev: true,
        next: false,
      ), reason: 'equations is 3 back, 5 on');
    });

    test('many pending give two dots at most, one a side', () {
      final all = {
        for (final m in GameMode.values)
          if (m.hasDaily) m,
      };
      expect(dots(GameMode.relay, all), (prev: true, next: true));
      expect(dots(GameMode.relay, {GameMode.lockdown, GameMode.blind}), (
        prev: false,
        next: true,
      ), reason: 'both are nearest going on');
    });

    test('as far both ways counts as the next side', () {
      // classic and blind are 4 apart in a loop of eight
      expect(dots(GameMode.classic, {GameMode.blind}), (
        prev: false,
        next: true,
      ));
    });
  });

  group('on the mode button', () {
    Future<void> open(WidgetTester tester, Set<GameMode> pending) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModeSwitch(
                mode: GameMode.classic,
                pending: pending,
                onChanged: (_) {},
                onOpen: () {},
                below: const SizedBox(),
              ),
            ),
          ),
        );

    testWidgets('a yellow dot above the chevron on the near side', (
      tester,
    ) async {
      await open(tester, {GameMode.quartet, GameMode.equations});
      expect(find.byKey(const ValueKey('daily-dot-next')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-dot-prev')), findsOneWidget);
      final next = tester.getCenter(
        find.byKey(const ValueKey('daily-dot-next')),
      );
      final chev = tester.getCenter(find.byKey(const ValueKey('mode-next')));
      expect(next.dx, closeTo(chev.dx, 1));
      expect(next.dy, lessThan(chev.dy), reason: 'above the chevron');
      final c = Theme.of(tester.element(find.byType(ModeSwitch))).colorScheme;
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('daily-dot-next')),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        markColors(c, Mark.present).$1,
      );
    });

    testWidgets('none pending, no dots', (tester) async {
      await open(tester, {});
      expect(find.byKey(const ValueKey('daily-dot-next')), findsNothing);
      expect(find.byKey(const ValueKey('daily-dot-prev')), findsNothing);
    });
  });
}
