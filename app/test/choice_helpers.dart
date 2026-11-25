import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the slider [id] shows the item [label] now.
bool choiceShows(String id, String label) => find
    .descendant(of: find.byKey(ValueKey(id)), matching: find.text(label))
    .evaluate()
    .isNotEmpty;

/// Moves the ChoiceSlider named [id] to the item labelled [label]: forward until
/// it shows, then back if it was behind. Fails the test if it never shows.
Future<void> pickChoice(WidgetTester tester, String id, String label) async {
  Future<void> walk(String way) async {
    for (var i = 0; i < 40 && !choiceShows(id, label); i++) {
      final button = find.byKey(ValueKey('$id-$way'));
      if (button.evaluate().isEmpty) return;
      if (tester.widget<IconButton>(button).onPressed == null) return;
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
  }

  await walk('next');
  await walk('prev');
  expect(choiceShows(id, label), isTrue, reason: '$id never showed $label');
}

/// The labels the slider [id] can show are not listed in the tree, but its dots
/// are: how many things it offers.
int choiceCount(String id) => find
    .descendant(
      of: find.byKey(ValueKey('$id-dots')),
      matching: find.byType(Container),
    )
    .evaluate()
    .length;
