import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/how_to.dart';
import 'package:lexodle/logo.dart';
import 'package:lexodle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rule = 'guess the word in as many tries as your difficulty allows.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('how to play opens on the first visit only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    expect(appState.seenHowTo, isFalse);

    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsOneWidget); // opened by itself
    expect(find.byType(LexodleLogo), findsNothing); // on top of the home screen

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LexodleLogo), findsOneWidget);
    expect(find.text(_rule), findsNothing);

    // a second visit (a fresh app reading the saved flag) stays on the menu
    await tester.pumpWidget(const SizedBox());
    await appState.load();
    expect(appState.seenHowTo, isTrue);
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsNothing);

    // ...and the footer link opens it on demand
    await tester.tap(find.text('how to play'));
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsOneWidget);
  });

  testWidgets('the three examples are shown with their colours', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HowToPage()));
    await tester.pump();
    expect(
      find.textContaining(
        'in the word and in the correct spot',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('wrong spot', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('not in the word in any spot', findRichText: true),
      findsOneWidget,
    );
  });
}
