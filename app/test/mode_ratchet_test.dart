import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_wheel.dart';
import 'package:lexodle/modes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<GameMode> reported;

  Future<void> open(WidgetTester tester, GameMode mode) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    await appState.load();
    reported = [];
    var shown = mode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => ModeSwitch(
              mode: shown,
              onChanged: (m) => set(() {
                shown = m;
                reported.add(m);
              }),
              onOpen: () {},
              below: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double width(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('mode-button'))).width;

  testWidgets('a full drag across the button turns three modes', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    await tester.drag(
      find.byKey(const ValueKey('mode-button')),
      Offset(-width(tester), 0),
    );
    await tester.pumpAndSettle();
    expect(reported, [GameMode.lockdown]);
  });

  testWidgets('a drag to the right goes back, a third of it one mode', (
    tester,
  ) async {
    await open(tester, GameMode.relay);
    await tester.drag(
      find.byKey(const ValueKey('mode-button')),
      Offset(width(tester) / 3 + 4, 0),
    );
    await tester.pumpAndSettle();
    expect(reported, [GameMode.quartet]);
  });

  testWidgets('the face follows the finger and the mode changes at a detent', (
    tester,
  ) async {
    await open(tester, GameMode.classic);
    final w = width(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('mode-button'))),
    );
    await g.moveBy(Offset(-w / 3 * .3, 0));
    await tester.pump();
    // inside the first detent: still classic, shifted left
    expect(find.byKey(const ValueKey('mode-name-classic')), findsOneWidget);
    final dx = tester.getCenter(find.byKey(const ValueKey('mode-face'))).dx;
    expect(dx, lessThan(tester.getCenter(find.byType(ModeSwitch)).dx));
    await g.moveBy(Offset(-w / 3 * .8, 0));
    await tester.pump();
    // past half a detent: the next mode takes the face
    expect(find.byKey(const ValueKey('mode-name-quartet')), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(reported, [GameMode.quartet]);
  });

  testWidgets('a short drag settles back and changes nothing', (tester) async {
    await open(tester, GameMode.classic);
    await tester.drag(
      find.byKey(const ValueKey('mode-button')),
      Offset(-width(tester) / 3 * .3, 0),
    );
    await tester.pumpAndSettle();
    expect(reported, isEmpty);
    expect(find.byKey(const ValueKey('mode-name-classic')), findsOneWidget);
  });
}
