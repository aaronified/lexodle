import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_strip.dart';
import 'package:lexodle/modes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Host extends StatefulWidget {
  const _Host(this.modes, this.log, {this.start});
  final List<GameMode> modes;
  final _Log log;
  final GameMode? start;

  @override
  State<_Host> createState() => _HostState();
}

class _Log {
  final changed = <GameMode>[];
  int taps = 0;
}

class _HostState extends State<_Host> {
  late GameMode selected = widget.start ?? widget.modes.first;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: ModeStrip(
            modes: widget.modes,
            selected: selected,
            onChanged: (m) {
              widget.log.changed.add(m);
              setState(() => selected = m);
            },
            onTap: () => widget.log.taps++,
          ),
        ),
      ),
    ),
  );
}

List<String> _ticks(WidgetTester tester) {
  final log = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') log.add('tick');
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    appState.haptics = true;
  });

  const eight = GameMode.values;
  final three = [GameMode.classic, GameMode.quartet, GameMode.relay];
  final box = find.byKey(const ValueKey('mode-strip-box'));
  final strip = find.byKey(const ValueKey('mode-strip'));

  Future<_Log> show(
    WidgetTester tester,
    List<GameMode> modes, {
    GameMode? start,
  }) async {
    final log = _Log();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_Host(modes, log, start: start));
    await tester.pump();
    return log;
  }

  testWidgets('the rectangle is there with 1, 3 and 8 modes', (tester) async {
    for (final modes in [
      [GameMode.classic],
      three,
      eight,
    ]) {
      await show(tester, modes);
      expect(box, findsOneWidget, reason: '${modes.length} modes');
      expect(tester.getSize(box), const Size(136, 48));
      // at the centre of the strip
      expect(tester.getCenter(box), tester.getCenter(strip));
    }
  });

  testWidgets('the item under the rectangle has the two-line label', (
    tester,
  ) async {
    await show(tester, three);
    expect(find.text('free play'), findsOneWidget);
    expect(find.text(GameMode.classic.label), findsOneWidget);
    // the neighbour is its name only
    expect(find.text(GameMode.quartet.label), findsOneWidget);
    final t = tester.widget<Text>(find.text(GameMode.classic.label));
    expect(t.style!.fontSize, 14);
    expect(t.style!.fontWeight, FontWeight.bold);
    expect(
      tester.widget<Text>(find.text(GameMode.quartet.label)).style!.fontSize,
      13,
    );
  });

  testWidgets('a drag past a detent changes the mode on release, with a tick', (
    tester,
  ) async {
    final ticks = _ticks(tester);
    final log = await show(tester, three);
    await tester.drag(strip, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(log.changed, [GameMode.quartet]);
    expect(ticks, hasLength(1));
    // the item that passed under the rectangle has the label
    expect(find.text('free play'), findsOneWidget);
    expect(
      tester.getCenter(
        find.byKey(ValueKey('mode-strip-${GameMode.quartet.name}')),
      ),
      tester.getCenter(box),
    );
  });

  testWidgets('a long drag crosses several items', (tester) async {
    final log = await show(tester, eight);
    await tester.drag(strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(log.changed, [eight[2]]);
  });

  testWidgets('the label follows the item under the rectangle live', (
    tester,
  ) async {
    await show(tester, three);
    final g = await tester.startGesture(tester.getCenter(strip));
    await g.moveBy(const Offset(-100, 0));
    await tester.pump();
    final t = tester.widget<Text>(find.text(GameMode.quartet.label));
    expect(t.style!.fontSize, 14);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a short drag snaps back', (tester) async {
    final ticks = _ticks(tester);
    final log = await show(tester, three);
    await tester.drag(strip, const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(log.changed, isEmpty);
    expect(ticks, isEmpty);
    expect(
      tester.getCenter(
        find.byKey(ValueKey('mode-strip-${GameMode.classic.name}')),
      ),
      tester.getCenter(box),
    );
  });

  testWidgets('a fast flick moves one item', (tester) async {
    final log = await show(tester, eight);
    await tester.fling(strip, const Offset(-60, 0), 1500);
    await tester.pumpAndSettle();
    expect(log.changed, [eight[1]]);
    await tester.fling(strip, const Offset(60, 0), 1500);
    await tester.pumpAndSettle();
    expect(log.changed, [eight[1], eight[0]]);
  });

  testWidgets('a tap on a neighbour selects it, and does not play', (
    tester,
  ) async {
    final log = await show(tester, three);
    await tester.tap(
      find.byKey(ValueKey('mode-strip-${GameMode.quartet.name}')),
    );
    await tester.pumpAndSettle();
    expect(log.changed, [GameMode.quartet]);
    expect(log.taps, 0);
  });

  testWidgets('a tap on the rectangle calls onTap', (tester) async {
    final log = await show(tester, three);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(log.taps, 1);
    expect(log.changed, isEmpty);
  });

  testWidgets('the edges fade only where there is more to scroll to', (
    tester,
  ) async {
    await show(tester, eight);
    expect(find.byKey(const ValueKey('mode-strip-fade--r')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('mode-strip-${eight[1].name}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mode-strip-fade-lr')), findsOneWidget);
    await show(tester, eight, start: eight.last);
    expect(find.byKey(const ValueKey('mode-strip-fade-l-')), findsOneWidget);
    await show(tester, [GameMode.classic]);
    expect(find.byKey(const ValueKey('mode-strip-fade---')), findsOneWidget);
  });

  testWidgets('one mode: no drag, the rectangle holds it', (tester) async {
    final log = await show(tester, [GameMode.classic]);
    await tester.drag(strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(log.changed, isEmpty);
    expect(find.text('free play'), findsOneWidget);
    expect(find.text(GameMode.classic.label), findsOneWidget);
    await tester.tap(box);
    expect(log.taps, 1);
  });

  testWidgets('reduced motion jumps with no animation', (tester) async {
    final log = _Log();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _Host(three, log),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey('mode-strip-${GameMode.quartet.name}')),
    );
    await tester.pump();
    expect(log.changed, [GameMode.quartet]);
  });

  testWidgets('it reads as a slider, and the rectangle as a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, three);
    expect(
      tester.getSemantics(box),
      matchesSemantics(
        label: 'free play ${GameMode.classic.label}',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    final slider = find.semantics.byLabel('free play mode');
    expect(slider, findsOne);
    final data = slider.evaluate().single.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), true);
    expect(data.hasAction(SemanticsAction.decrease), false);
    tester.semantics.increase(slider);
    await tester.pumpAndSettle();
    expect(find.text('free play'), findsOneWidget);
    expect(
      tester.getCenter(
        find.byKey(ValueKey('mode-strip-${GameMode.quartet.name}')),
      ),
      tester.getCenter(box),
    );
    handle.dispose();
  });
}
