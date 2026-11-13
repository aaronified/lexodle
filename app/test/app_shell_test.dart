import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/app_shell.dart';
import 'package:lexodle/home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/today_page.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomeSwitch()));
    await tester.pump();
  }

  testWidgets('the old home stays until the preview is on', (tester) async {
    appState.newUi = false;
    await show(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('a new player has today and you; the rest come as taught', (
    tester,
  ) async {
    appState.newUi = true;
    addTearDown(() => appState.newUi = false);
    appState.lex.veteran = false;
    appState.stats.played = 1;
    await show(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text('words'), findsNothing);
    expect(find.text('learn'), findsWidgets);
    expect(find.text('learn'), findsWidgets);
    await tester.tap(find.text('you').last);
    await tester.pump();
    expect(find.byType(YouPage), findsOneWidget);
    appState.stats.played = 9;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    appState.notifyListeners();
    await tester.pump();
    expect(find.text('words'), findsWidgets);
    expect(find.text('learn'), findsWidgets);
  });

  testWidgets('a veteran has all four tabs', (tester) async {
    appState.newUi = true;
    addTearDown(() => appState.newUi = false);
    appState.lex.veteran = true;
    await show(tester);
    for (final t in ['today', 'words', 'learn', 'you']) {
      expect(find.text(t), findsWidgets);
    }
  });

  testWidgets('the tab bar casts a soft upward shadow', (tester) async {
    appState.newUi = true;
    addTearDown(() => appState.newUi = false);
    await show(tester);
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('tabs-shadow')),
    );
    final shadows = (box.decoration as BoxDecoration).boxShadow!;
    expect(shadows, hasLength(2));
    expect(shadows.every((s) => s.offset.dy < 0), isTrue);
  });

  testWidgets('every scrollable stretches at its ends, on any platform', (
    tester,
  ) async {
    for (final p in [TargetPlatform.iOS, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = p;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: ListView(children: [for (var i = 0; i < 40; i++) Text('$i')]),
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
      final ctx = tester.element(find.byType(ListView));
      expect(
        const AppScrollBehavior().getScrollPhysics(ctx),
        isA<ClampingScrollPhysics>(),
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('switches have no outline and a visible off knob', (
    tester,
  ) async {
    final t = buildTheme(Brightness.light).switchTheme;
    final c = buildTheme(Brightness.light).colorScheme;
    expect(t.trackOutlineWidth!.resolve({}), 0);
    expect(t.trackColor!.resolve({WidgetState.selected}), c.secondary);
    expect(t.thumbColor!.resolve({WidgetState.selected}), c.onSecondary);
    expect(t.thumbColor!.resolve({}), c.onSurface.withValues(alpha: .6));
  });
}
