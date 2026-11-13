import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/choose_dailies_sheet.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/my_dailies.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showChooseDailies(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.lang = 'en';
    appState.myDailies = MyDailies();
    appState.stats.played = 10;
    appState.lex.veteran = false;
  });

  testWidgets('a switch adds a daily and drops it again', (tester) async {
    await _open(tester);
    expect(find.text('choose your dailies'), findsOneWidget);
    expect(appState.dailiesOf('en'), [GameMode.classic]);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(appState.dailiesOf('en'), [GameMode.classic, GameMode.quartet]);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(appState.dailiesOf('en'), [GameMode.classic]);
  });

  testWidgets('the last daily cannot be switched off', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('daily-switch-classic')));
    await tester.pumpAndSettle();
    expect(find.text('keep at least one daily'), findsOneWidget);
    expect(appState.dailiesOf('en'), [GameMode.classic]);
  });

  testWidgets('dropping a daily with a streak asks first', (tester) async {
    appState.recordDaily(dailyDate(), dailySolved, mode: GameMode.quartet);
    appState.myDailies = MyDailies()..add('en', GameMode.quartet);
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    expect(find.textContaining('quartet has a 1 day streak'), findsOneWidget);
    expect(find.textContaining('remove it anyway?'), findsOneWidget);
    expect(appState.dailiesOf('en'), contains(GameMode.quartet));

    await tester.tap(find.text('keep it'));
    await tester.pumpAndSettle();
    expect(find.textContaining('remove it anyway?'), findsNothing);
    expect(appState.dailiesOf('en'), contains(GameMode.quartet));

    await tester.tap(find.byKey(const ValueKey('daily-switch-quartet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();
    expect(appState.dailiesOf('en'), [GameMode.classic]);
  });

  testWidgets('a mode not yet open has no switch and says when it opens', (
    tester,
  ) async {
    // quartet opens at four games: at one game played it has three to go
    appState.stats.played = 1;
    await _open(tester);
    expect(find.byKey(const ValueKey('daily-switch-quartet')), findsNothing);
    expect(find.byKey(const ValueKey('daily-switch-classic')), findsOneWidget);
    expect(find.textContaining('opens in 3 more games'), findsOneWidget);
  });
}
