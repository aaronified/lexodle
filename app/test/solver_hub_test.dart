import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/blind_solver.dart';
import 'package:lexodle/diy_controls.dart';
import 'package:lexodle/equation_solver.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_solver.dart';
import 'package:lexodle/solver.dart';
import 'package:lexodle/settings_button.dart';
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

  testWidgets('a veteran sees a pill for every mode and one header', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('solver'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(SettingsButton), findsOneWidget);
    expect(find.byKey(const ValueKey('solver-options')), findsOneWidget);
    expect(find.text(caption), findsNothing);
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

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('solver-options')));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet has the language box, two sliders and the note', (
    tester,
  ) async {
    await show(tester);
    await openSheet(tester);
    expect(find.text('solver settings'), findsWidgets);
    expect(find.byKey(const ValueKey('dropdown-language')), findsOneWidget);
    expect(find.byKey(const ValueKey('slider-length')), findsOneWidget);
    expect(find.byKey(const ValueKey('slider-tries')), findsOneWidget);
    expect(find.text(caption), findsOneWidget);
    await done(tester);
  });

  testWidgets('a length chosen in the sheet is for the solver only', (
    tester,
  ) async {
    appState.setup(length: 5);
    await show(tester);
    await openSheet(tester);
    final slider = find.byKey(const ValueKey('slider-length'));
    // 4 to 8: the first stop is 4
    await tester.drag(slider, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('solver-options-close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
    final page = tester.widget<SolverPage>(find.byType(SolverPage));
    expect(page.length, 4);
    expect(appState.length, 5);
    await done(tester);
  });

  testWidgets('geography greys the language box', (tester) async {
    await show(tester);
    await pick(tester, GameMode.themed);
    await openSheet(tester);
    final box = find.byKey(const ValueKey('dropdown-language'));
    expect(box, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: box, matching: find.byType(Opacity)).first,
          )
          .opacity,
      lessThan(1),
    );
    expect(find.byType(DropdownBox), findsOneWidget);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(find.text('solver settings'), findsWidgets);
    await done(tester);
  });
}
