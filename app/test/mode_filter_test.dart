import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/mode_filter.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'choice_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  /// Shows a [ModeFilter] that keeps its own selection, so the arrows and the
  /// swipe move it; every selection is also passed to [onSelect].
  Future<void> show(
    WidgetTester tester, {
    GameMode? selected,
    bool showAll = true,
    List<GameMode> modes = GameMode.values,
    ValueChanged<GameMode?>? onSelect,
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    var now = selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setLocal) => ModeFilter(
              selected: now,
              showAll: showAll,
              modes: modes,
              onSelect: (m) {
                setLocal(() => now = m);
                onSelect?.call(m);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  IconButton arrow(WidgetTester tester, String way) =>
      tester.widget<IconButton>(find.byKey(ValueKey('mode-slider-$way')));

  testWidgets('the slider offers all modes first, then each mode in order', (
    tester,
  ) async {
    await show(tester);
    final labels = ['all modes', for (final m in GameMode.values) m.label];
    expect(choiceCount('mode-slider'), labels.length);
    for (var i = 0; i < labels.length; i++) {
      expect(choiceShows('mode-slider', labels[i]), isTrue, reason: labels[i]);
      if (i < labels.length - 1) {
        await tester.tap(find.byKey(const ValueKey('mode-slider-next')));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('a list of modes is offered in the order given, without all', (
    tester,
  ) async {
    await show(
      tester,
      showAll: false,
      modes: const [GameMode.quartet, GameMode.blind],
    );
    expect(choiceCount('mode-slider'), 2);
    expect(choiceShows('mode-slider', 'all modes'), isFalse);
    expect(choiceShows('mode-slider', 'quartet'), isTrue);
    expect(arrow(tester, 'prev').onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mode-slider-next')));
    await tester.pumpAndSettle();
    expect(choiceShows('mode-slider', 'blind'), isTrue);
    expect(arrow(tester, 'next').onPressed, isNull);
  });

  testWidgets('showAll adds all modes first, as a null value', (tester) async {
    final calls = <GameMode?>[];
    await show(tester, onSelect: calls.add);
    expect(choiceShows('mode-slider', 'all modes'), isTrue);
    expect(arrow(tester, 'prev').onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mode-slider-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-slider-prev')));
    await tester.pumpAndSettle();
    expect(calls, [GameMode.classic, null]);
  });

  testWidgets('next and prev call onSelect with the neighbouring mode', (
    tester,
  ) async {
    final calls = <GameMode?>[];
    await show(tester, selected: GameMode.quartet, onSelect: calls.add);
    expect(choiceShows('mode-slider', 'quartet'), isTrue);
    await tester.tap(find.byKey(const ValueKey('mode-slider-next')));
    await tester.pumpAndSettle();
    expect(choiceShows('mode-slider', 'relay race'), isTrue);
    await tester.tap(find.byKey(const ValueKey('mode-slider-prev')));
    await tester.pumpAndSettle();
    expect(choiceShows('mode-slider', 'quartet'), isTrue);
    expect(calls, [GameMode.relay, GameMode.quartet]);
  });

  testWidgets('the prev arrow is off at the first item, next at the last', (
    tester,
  ) async {
    await show(tester);
    expect(arrow(tester, 'prev').onPressed, isNull);
    expect(arrow(tester, 'next').onPressed, isNotNull);
    await show(tester, selected: GameMode.values.last);
    expect(choiceShows('mode-slider', GameMode.values.last.label), isTrue);
    expect(arrow(tester, 'next').onPressed, isNull);
    expect(arrow(tester, 'prev').onPressed, isNotNull);
  });

  testWidgets('a swipe to the left moves to the next one', (tester) async {
    final calls = <GameMode?>[];
    await show(tester, onSelect: calls.add);
    await tester.fling(
      find.byKey(const ValueKey('mode-slider')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(calls, [GameMode.classic]);
    expect(choiceShows('mode-slider', 'classic'), isTrue);
  });

  testWidgets('the slider shows the selected mode', (tester) async {
    await show(tester, selected: GameMode.blind);
    expect(choiceShows('mode-slider', 'blind'), isTrue);
    expect(choiceShows('mode-slider', 'all modes'), isFalse);
  });

  testWidgets('the playstyle page shows the filter once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(const MaterialApp(home: PlaystylePage()));
    await tester.pump();
    expect(find.byKey(const ValueKey('mode-filter')), findsOneWidget);
    // the six modes that have a playstyle, and all modes
    expect(choiceCount('mode-slider'), 7);
  });
}
