import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/licences_page.dart';
import 'package:lexodle/logo.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rule = 'guess the word in as many tries as your difficulty allows.';

/// Remembers the name of the screen on top, as the browser's address bar
/// follows it.
class _Names extends NavigatorObserver {
  final stack = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      stack.add(route.settings.name);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previous) =>
      stack.removeLast();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    stack
      ..removeLast()
      ..add(newRoute?.settings.name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'fr', length: 4, tries: 3);
  });

  Future<_Names> open(WidgetTester tester, String? route) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    final names = _Names();
    await tester.pumpWidget(
      LexodleApp(initialRoute: route, observers: [names]),
    );
    await tester.pumpAndSettle();
    return names;
  }

  Finder home() => find.byType(LexodleLogo);

  NavigatorState nav(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  testWidgets('every address opens its screen with home underneath', (
    tester,
  ) async {
    for (final (route, marker) in [
      (Routes.achievements, find.text('achievements')),
      (Routes.howTo, find.text(_rule)),
      (Routes.settings, find.text('settings')),
      (Routes.gameModes, find.text('game modes')),
      (Routes.about, find.byType(LicencesPage)),
    ]) {
      await open(tester, route);
      expect(marker, findsOneWidget, reason: route);
      expect(nav(tester).canPop(), isTrue, reason: '$route has home under it');

      // back, as the browser's back button does
      nav(tester).pop();
      await tester.pumpAndSettle();
      expect(marker, findsNothing, reason: '$route closes');
      expect(home(), findsOneWidget, reason: '$route goes back to home');
      expect(nav(tester).canPop(), isFalse);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the game and the solver open by address and load their words', (
    tester,
  ) async {
    await open(tester, Routes.play);
    // the word file is read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(find.text('3 tries left'), findsOneWidget);
    expect(nav(tester).canPop(), isTrue);
    await tester.pumpWidget(const SizedBox());

    await open(tester, Routes.solver);
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(find.textContaining('my list holds'), findsOneWidget);
    nav(tester).pop();
    await tester.pumpAndSettle();
    expect(home(), findsOneWidget);
  });

  testWidgets('a refresh waits for the saved settings before building', (
    tester,
  ) async {
    // settings not read yet, as on a page opened by address
    appState.loaded = false;
    await open(tester, Routes.play);
    expect(find.text('loading…'), findsOneWidget);
    expect(find.text('3 tries left'), findsNothing);
  });

  testWidgets('unknown addresses and a review without a game show home', (
    tester,
  ) async {
    for (final route in ['/nope', Routes.review, '/play/review?x=1']) {
      await open(tester, route);
      expect(home(), findsOneWidget, reason: route);
      expect(nav(tester).canPop(), isFalse, reason: '$route is just home');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('moving about names each screen, as the address bar needs', (
    tester,
  ) async {
    final names = await open(tester, null);
    expect(names.stack, ['/']);

    await tester.tap(find.byTooltip('settings'));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.settings]);
    // about is inside it
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('licences-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('licences-button')));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.settings, Routes.about]);
    await tester.tapAt(const Offset(5, 5)); // the scrim closes it
    await tester.pumpAndSettle();
    nav(tester).pop(); // and back from settings is home
    await tester.pumpAndSettle();
    expect(names.stack, ['/']);

    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.gameModes]);

    // the solver replaces the popup: back from it is home, not the popup
    await tester.tap(find.text('open the solver'));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.solver]);
    nav(tester).pop();
    await tester.pumpAndSettle();
    expect(names.stack, ['/']);

    // so does play, beside it: back from the game is home too
    await tester.tap(find.byTooltip('game modes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-play')));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.play]);
    nav(tester).pop();
    await tester.pumpAndSettle();
    expect(names.stack, ['/']);

    await tester.tap(find.textContaining('achievements'));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.achievements]);
    nav(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('play'));
    await tester.pumpAndSettle();
    expect(names.stack, ['/', Routes.play]);
  });
}
