import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/shortcuts_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, {VoidCallback? onTap}) =>
      tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ShortcutsOverlay(child: child!),
          home: Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('under'),
                onPressed: onTap,
                child: const Text('under'),
              ),
            ),
          ),
        ),
      );

  final pane = find.byKey(const ValueKey('shortcuts-pane'));

  testWidgets('holding alt shows the pane after 0.1 s, releasing hides it', (
    tester,
  ) async {
    await open(tester);
    expect(pane, findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 60));
    expect(pane, findsNothing, reason: 'not yet');
    await tester.pump(const Duration(milliseconds: 60));
    expect(pane, findsOneWidget);
    expect(find.text('shift + backspace'), findsOneWidget);
    expect(find.text('double tap the guesses'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(pane, findsNothing);
  });

  testWidgets('a tap of alt shorter than 0.1 s shows nothing', (tester) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 200));
    expect(pane, findsNothing);
  });

  testWidgets('the pane is frosted and lets touches through', (tester) async {
    var taps = 0;
    await open(tester, onTap: () => taps++);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(BackdropFilter), findsOneWidget);
    final box = tester.widget<Container>(pane);
    expect((box.color!.a), lessThan(1), reason: 'semi transparent');
    await tester.tap(find.byKey(const ValueKey('under')), warnIfMissed: false);
    expect(taps, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  });

  test('every shortcut has its keys and what they do', () {
    for (final (heading, rows) in shortcutGroups) {
      expect(heading, isNotEmpty);
      for (final (keys, what) in rows) {
        expect(keys, isNotEmpty);
        expect(what, isNotEmpty);
      }
    }
  });
}
