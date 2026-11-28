import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the handle of a picker sheet pulls it away', (tester) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPickerSheet<int>(
              context,
              title: 'pick',
              items: const [
                ChoiceItem(value: 1, label: 'one'),
                ChoiceItem(value: 2, label: 'two'),
              ],
              selected: 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('pick'), findsOneWidget);
    // the drag handle sits at the top edge of the sheet
    await tester.dragFrom(
      tester.getRect(find.byType(BottomSheet)).topCenter + const Offset(0, 20),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(find.text('pick'), findsNothing);
  });
}
