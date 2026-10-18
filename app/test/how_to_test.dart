import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/how_to.dart';
import 'package:lexodle/logo.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/words.dart';
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

  testWidgets('the first-visit screen starts a default UK english game', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    // somebody else's choices must not leak into the default game
    appState.setup(
      lang: 'fr',
      length: 7,
      tries: 3,
      pool: 500,
      mode: GameMode.quartet,
    );
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsOneWidget); // onboarding, opened by itself
    expect(find.text('start playing'), findsOneWidget);

    await tester.tap(find.text('start playing'));
    await tester.pumpAndSettle();
    // the word file is read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(appState.lang, 'en-GB');
    expect(appState.length, 5);
    expect(appState.tries, 6);
    expect(appState.pool, defaultPool);
    expect(appState.mode, GameMode.classic);
    expect(find.text('6 tries left'), findsOneWidget);
    expect(find.textContaining('english (uk)'), findsOneWidget);
    expect(find.text(_rule), findsNothing, reason: 'the page is replaced');

    // back from the game is the menu, not the how-to page again
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LexodleLogo), findsOneWidget);
    expect(find.text(_rule), findsNothing);
  });

  testWidgets('opened later, it is a reference page with no start button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('how to play'));
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsOneWidget);
    expect(find.text('start playing'), findsNothing);

    // nor does opening it by address
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const LexodleApp(initialRoute: '/how-to'));
    await tester.pumpAndSettle();
    expect(find.text(_rule), findsOneWidget);
    expect(find.text('start playing'), findsNothing);
  });
}
