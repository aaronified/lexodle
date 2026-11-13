import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/edge_fade.dart';
import 'package:lexodle/mode_filter.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  Future<void> show(
    WidgetTester tester,
    double width, {
    GameMode? selected,
    bool showAll = true,
    ValueChanged<GameMode?>? onSelect,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeFilter(
            selected: selected,
            showAll: showAll,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  EdgeFadeState fade(WidgetTester t) => t.state(find.byType(EdgeFade));

  testWidgets('one scrolling row, faded only where there is more', (
    tester,
  ) async {
    await show(tester, 320);
    expect(find.byType(Wrap), findsNothing);
    final scroll = find.byKey(const ValueKey('mode-filter-scroll'));
    expect(
      tester.widget<SingleChildScrollView>(scroll).scrollDirection,
      Axis.horizontal,
    );
    // one line: every chip at the same height, at least 36
    final top = tester.getTopLeft(find.byKey(const ValueKey('mode-all'))).dy;
    for (final m in GameMode.values) {
      final k = find.byKey(ValueKey('mode-${m.name}'));
      expect(tester.getTopLeft(k).dy, top);
      expect(tester.getSize(k).height, greaterThanOrEqualTo(36));
    }
    expect(fade(tester).fadeLeft, isFalse);
    expect(fade(tester).fadeRight, isTrue);
    await tester.drag(scroll, const Offset(-2000, 0));
    await tester.pump();
    expect(fade(tester).fadeLeft, isTrue);
    expect(fade(tester).fadeRight, isFalse);
  });

  testWidgets('no fade when it fits', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeFilter(
            selected: null,
            modes: const [GameMode.classic],
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(fade(tester).fadeLeft, isFalse);
    expect(fade(tester).fadeRight, isFalse);
  });

  testWidgets('showAll false hides all; a tap selects the mode', (
    tester,
  ) async {
    GameMode? got;
    await show(tester, 320, showAll: false, onSelect: (m) => got = m);
    expect(find.byKey(const ValueKey('mode-all')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mode-classic')));
    expect(got, GameMode.classic);
  });

  testWidgets('a selected chip off screen is scrolled into view', (
    tester,
  ) async {
    await show(tester, 320, selected: GameMode.values.last);
    await tester.pump(const Duration(milliseconds: 400));
    final r = tester.getRect(
      find.byKey(ValueKey('mode-${GameMode.values.last.name}')),
    );
    expect(r.right, lessThanOrEqualTo(320));
    expect(fade(tester).fadeLeft, isTrue);
  });

  testWidgets('the playstyle page shows the filter once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(const MaterialApp(home: PlaystylePage()));
    await tester.pump();
    expect(find.byKey(const ValueKey('mode-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-all')), findsOneWidget);
  });
}
