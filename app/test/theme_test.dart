import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio of [fg] over [bg]; a translucent [fg] is blended first.
double contrast(Color fg, Color bg) {
  final blended = Color.alphaBlend(fg, bg);
  final a = blended.computeLuminance(), b = bg.computeLuminance();
  return (max(a, b) + .05) / (min(a, b) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme contrast', () {
      final c = buildTheme(brightness).colorScheme;

      test('letters on the feedback tiles read clearly', () {
        for (final m in [Mark.correct, Mark.present]) {
          final (fill, fg) = markColors(c, m);
          expect(
            contrast(fg, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$m on ${brightness.name}',
          );
        }
      });

      test(
        'green and yellow tiles stand apart from the page and each other',
        () {
          final green = markColors(c, Mark.correct).$1;
          final yellow = markColors(c, Mark.present).$1;
          expect(contrast(green, c.surface), greaterThanOrEqualTo(3));
          expect(contrast(yellow, c.surface), greaterThanOrEqualTo(2.2));
          // hue apart, so colour-blind-unfriendly pairs are at least far in hue
          final dh =
              (HSLColor.fromColor(green).hue - HSLColor.fromColor(yellow).hue)
                  .abs();
          expect(dh, greaterThan(30));
        },
      );

      test('letters on a wrong tile recede but can still be read', () {
        final (fill, fg) = markColors(c, Mark.absent);
        expect(contrast(fg, fill), greaterThanOrEqualTo(2.5));
        expect(
          contrast(fill, c.surface),
          greaterThan(1.3),
          reason: 'the tile is visible against the page',
        );
      });

      test('body text, captions, links and errors on the page', () {
        expect(contrast(c.onSurface, c.surface), greaterThanOrEqualTo(7));
        expect(
          contrast(c.onSurface.withValues(alpha: dimAlpha), c.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'captions',
        );
        expect(contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.error, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.secondary, c.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  group('the theme setting', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      await appState.load();
      appState.setup(themeMode: ThemeMode.system);
    });

    Brightness shown(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    testWidgets('light and dark override the device, system follows it', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.dark, reason: 'system, device is dark');

      appState.setup(themeMode: ThemeMode.light);
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.light);

      appState.setup(themeMode: ThemeMode.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.dark, reason: 'dark on a light device');

      appState.setup(themeMode: ThemeMode.system);
      await tester.pumpAndSettle();
      expect(
        shown(tester),
        Brightness.light,
        reason: 'system, device is light',
      );
    });

    testWidgets('it is chosen in the settings popup and kept', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2200));
      await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
      await tester.pumpAndSettle();
      expect(find.text('theme'), findsOneWidget);
      expect(find.text('system'), findsOneWidget);
      // step to the next value with the arrow key, as the other choices do
      appState.setup(themeMode: ThemeMode.light);
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('theme'), ThemeMode.light.index);
    });

    test('a saved theme is read back, and a bad value is ignored', () async {
      SharedPreferences.setMockInitialValues({'theme': ThemeMode.dark.index});
      await appState.load();
      expect(appState.themeMode, ThemeMode.dark);
      SharedPreferences.setMockInitialValues({'theme': 9});
      appState.themeMode = ThemeMode.system;
      await appState.load();
      expect(appState.themeMode, ThemeMode.system);
    });
  });
}
