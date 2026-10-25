import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/arrow_scroll.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  /// A mouse that has been moved to [at].
  Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(at);
    await tester.pump();
    return g;
  }

  /// The home page on a short window, so that it scrolls (and the play row is
  /// pinned below it).
  Future<void> home(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 420));
    await appState.load();
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
  }

  // the last button of the page: where it is says how far the page has scrolled
  double top(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('how-to-button'))).dy;

  group('down and up scroll what the mouse is over', () {
    testWidgets('the page moves by a step a press, and back', (tester) async {
      await home(tester);
      await mouseAt(tester, const Offset(210, 200));
      final start = top(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), start - 60);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), start - 120);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(top(tester), start - 60);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(top(tester), start);
    });

    testWidgets('it stops at the top, and at the bottom', (tester) async {
      await home(tester);
      await mouseAt(tester, const Offset(210, 200));
      final start = top(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(top(tester), start, reason: 'already at the top');
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      final end = top(tester);
      expect(end, lessThan(start));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), end, reason: 'nothing further down');
    });

    testWidgets('a key held down keeps scrolling', (tester) async {
      await home(tester);
      await mouseAt(tester, const Offset(210, 200));
      final start = top(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), start - 180, reason: 'a press and two repeats');
    });

    testWidgets('the release of the key does nothing', (tester) async {
      await home(tester);
      await mouseAt(tester, const Offset(210, 200));
      final start = top(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final once = top(tester);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), once);
      expect(once, start - 60);
    });

    testWidgets('with no mouse seen it acts at the middle of the window', (
      tester,
    ) async {
      await home(tester);
      // the window's middle is (400, 300) as the test view sees it: a window
      // tall enough that the pinned play bar (frequency row and play row)
      // starts below it, so the middle is over the scrolling page
      await tester.binding.setSurfaceSize(const Size(420, 520));
      await tester.pumpAndSettle();
      final start = top(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(top(tester), start - 60);
    });

    testWidgets('with Ctrl, Alt or Meta held the keys are left alone', (
      tester,
    ) async {
      await home(tester);
      await mouseAt(tester, const Offset(210, 200));
      final start = top(tester);
      for (final mod in [
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.meta,
      ]) {
        await tester.sendKeyDownEvent(mod);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(mod);
        await tester.pump();
        expect(top(tester), start, reason: '$mod');
      }
    });

    testWidgets('left and right are not touched', (tester) async {
      await home(tester);
      // the keys are left for focus to use (which may scroll the page to the
      // button it lands on): the scroller itself does not take them
      final focus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(ArrowScroll),
              matching: find.byType(Focus),
            )
            .first,
      );
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        final result = focus.onKeyEvent!(
          FocusNode(),
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowRight,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
        );
        expect(result, KeyEventResult.ignored, reason: key.keyLabel);
      }
    });
  });

  group('the pointer decides which one scrolls', () {
    testWidgets(
      'a popup over the page takes the keys when the mouse is on it',
      (tester) async {
        await home(tester);
        await tester.binding.setSurfaceSize(const Size(420, 500));
        await tester.pumpAndSettle();
        final pageTop = top(tester);
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed(Routes.gameModes);
        await tester.pumpAndSettle();
        // the dialog is a scroll view of its own, in the middle of the window
        final dialog = find.byType(Dialog);
        expect(dialog, findsOneWidget);
        final mode = find.text('mode');
        final modeTop = tester.getTopLeft(mode).dy;
        await mouseAt(tester, tester.getCenter(dialog));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(
          tester.getTopLeft(mode).dy,
          lessThan(modeTop),
          reason: 'the dialog',
        );
        // the page behind did not move
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(top(tester), pageTop);
      },
    );

    testWidgets('moving the mouse moves where the keys act', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      await appState.load();
      // two lists side by side: each moves only when the mouse is over it
      final left = ScrollController();
      final right = ScrollController();
      addTearDown(left.dispose);
      addTearDown(right.dispose);
      Widget list(ScrollController c) => Expanded(
        child: ListView(
          controller: c,
          children: [
            for (var i = 0; i < 60; i++)
              SizedBox(height: 50, child: Text('row $i')),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArrowScroll(child: child!),
          home: Scaffold(body: Row(children: [list(left), list(right)])),
        ),
      );
      final g = await mouseAt(tester, const Offset(200, 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(left.offset, 60);
      expect(right.offset, 0);
      await g.moveTo(const Offset(700, 300));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(left.offset, 60);
      expect(right.offset, 120);
    });

    testWidgets('a step can be set', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArrowScroll(step: 25, child: child!),
          home: Scaffold(
            body: ListView(
              controller: c,
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 50, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(c.offset, 25);
    });
  });

  group('what has its own use of the arrows keeps it', () {
    testWidgets('a focused slider takes up and down for itself', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 700));
      var value = 10.0;
      final c = ScrollController();
      final focus = FocusNode();
      addTearDown(c.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArrowScroll(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => ListView(
                controller: c,
                children: [
                  Slider(
                    focusNode: focus,
                    value: value,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    onChanged: (v) => set(() => value = v),
                  ),
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 50, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, isNot(10.0), reason: 'the slider moved');
      expect(c.offset, 0, reason: 'and the page did not');
    });

    testWidgets('a page that handles the key itself keeps it', (tester) async {
      var heard = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArrowScroll(child: child!),
          home: Scaffold(
            body: Focus(
              autofocus: true,
              onKeyEvent: (_, e) {
                if (e is KeyDownEvent &&
                    e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  heard++;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ListView(
                controller: c,
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 50, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(heard, 1);
      expect(c.offset, 0, reason: 'it was used, so it is not also a scroll');
    });
  });

  testWidgets('the whole app scrolls with the keys, on a screen of its own', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 500));
    await appState.load();
    await tester.pumpWidget(const LexodleApp(initialRoute: Routes.howTo));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset(), 0);
    await mouseAt(tester, const Offset(210, 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(offset(), 60);
  });
}
