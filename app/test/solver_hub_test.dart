import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_solver.dart';
import 'package:lexodle/equation_solver.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_solver.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/solver_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', mode: GameMode.classic);
    appState.lex.veteran = true;
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(const MaterialApp(home: SolverHubPage()));
    // word files are read with real file IO, which fake-async cannot await
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> pick(WidgetTester tester, GameMode m) async {
    final pill = find.byKey(ValueKey('mode-${m.name}'));
    await tester.ensureVisible(pill);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(pill);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
  }

  const caption =
      'answers of your games in progress and of dailies you have not '
      'finished are left out.';

  testWidgets('a veteran sees a pill for every mode and the caption', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('solver'), findsOneWidget);
    expect(find.text(caption), findsOneWidget);
    for (final m in GameMode.loopFor('en')) {
      expect(
        find.byKey(ValueKey('mode-${m.name}')),
        findsOneWidget,
        reason: '$m',
      );
    }
    expect(find.byType(SolverPage), findsOneWidget);
    await done(tester);
  });

  testWidgets('a player with few games sees fewer pills', (tester) async {
    appState.lex.veteran = false;
    appState.stats.played = 1;
    await show(tester);
    expect(find.byKey(const ValueKey('mode-classic')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-equations')), findsNothing);
    expect(find.byKey(const ValueKey('mode-themed')), findsNothing);
    await done(tester);
  });

  testWidgets('it opens on the mode in view', (tester) async {
    appState.setup(mode: GameMode.quartet);
    await show(tester);
    expect(find.byType(MultiSolverPage), findsOneWidget);
    expect(find.byType(SolverPage), findsNothing);
    await done(tester);
  });

  testWidgets('a pill shows the solver of its mode, and keeps the mode', (
    tester,
  ) async {
    await show(tester);
    await pick(tester, GameMode.relay);
    expect(find.byType(MultiSolverPage), findsOneWidget);
    await pick(tester, GameMode.blind);
    expect(find.byType(BlindSolverPage), findsOneWidget);
    await pick(tester, GameMode.equations);
    expect(find.byType(EquationSolverPage), findsOneWidget);
    await pick(tester, GameMode.themed);
    expect(find.byType(SolverPage), findsOneWidget);
    expect(find.byKey(const ValueKey('places-5')), findsWidgets);
    await pick(tester, GameMode.mastermind);
    expect(find.byType(SolverPage), findsOneWidget);
    await pick(tester, GameMode.lockdown);
    expect(find.textContaining('$lockdownTries tries'), findsWidgets);
    expect(appState.mode, GameMode.classic);
    await done(tester);
  });
}
