import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(themeMode: ThemeMode.system, black: false);
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    // a fresh tree each time: the page is const, so it would not rebuild
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: const Scaffold(body: YouPage())));
    await tester.pump();
  }

  Finder row(String id) => find.byKey(ValueKey('you-row-$id'));

  void player({required int played, required bool veteran}) {
    appState.stats.played = played;
    appState.lex.veteran = veteran;
  }

  testWidgets('a veteran sees every row', (tester) async {
    player(played: 500, veteran: true);
    await show(tester);
    for (final id in ['achievements', 'history', 'friends']) {
      expect(row(id), findsOneWidget, reason: id);
    }
    expect(find.text('coming in an upcoming release'), findsOneWidget);
  });

  Future<void> gated(
    WidgetTester tester,
    int played,
    Set<String> expected,
  ) async {
    player(played: played, veteran: false);
    await show(tester);
    for (final id in ['achievements', 'history', 'friends']) {
      expect(
        row(id),
        expected.contains(id) ? findsOneWidget : findsNothing,
        reason: '$id at game $played',
      );
    }
  }

  testWidgets('game 1 sees none of them', (t) => gated(t, 1, {}));
  testWidgets('game 3 adds achievements', (t) => gated(t, 3, {'achievements'}));
  testWidgets(
    'game 5 sees everything',
    (t) => gated(t, 5, {'achievements', 'history', 'friends'}),
  );

  testWidgets('language is always there, the settings rows are gone', (
    tester,
  ) async {
    player(played: 500, veteran: true);
    await show(tester);
    expect(row('language'), findsOneWidget);
    for (final id in [
      'reminders',
      'backup',
      'support',
      'whatsnew',
      'settings',
      'theme',
    ]) {
      expect(row(id), findsNothing, reason: id);
    }
    expect(find.byKey(const ValueKey('theme-dark')), findsNothing);
    player(played: 0, veteran: false);
    await show(tester);
    expect(row('language'), findsOneWidget);
    expect(row('howto'), findsNothing);
    expect(find.byKey(const ValueKey('you-help')), findsNothing);
    expect(row('solver'), findsNothing);
    expect(row('diy'), findsNothing);
  });

  testWidgets('solver and diy come at game 6', (tester) async {
    player(played: 5, veteran: false);
    await show(tester);
    expect(row('solver'), findsNothing);
    player(played: 6, veteran: false);
    await show(tester);
    await tester.pump();
    expect(row('solver'), findsOneWidget);
    expect(row('diy'), findsOneWidget);
  });

  testWidgets('the solver row says which mode it solves', (tester) async {
    player(played: 500, veteran: true);
    String sub() => (tester.widget<Text>(
      find.descendant(of: row('solver'), matching: find.byType(Text)).last,
    )).data!;
    appState.setup(mode: GameMode.quartet);
    await show(tester);
    expect(sub(), 'for quartet');
    // no solver for these modes: the classic one opens
    for (final m in [GameMode.blind, GameMode.equations, GameMode.themed]) {
      appState.setup(mode: m);
      await show(tester);
      expect(sub(), 'for classic', reason: '$m');
    }
    expect(solverModeOf(GameMode.lockdown), GameMode.lockdown);
    expect(solverModeOf(GameMode.equations), GameMode.classic);
  });

  testWidgets('the settings button is on the tab and opens settings', (
    tester,
  ) async {
    player(played: 0, veteran: false);
    final pushed = <String?>[];
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (s) {
          pushed.add(s.name);
          return MaterialPageRoute(
            settings: s,
            builder: (_) => const Scaffold(body: Text('pushed')),
          );
        },
        home: const Scaffold(body: YouPage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(pushed, [Routes.settings]);
  });

  testWidgets('the achievements row shows the lex chip', (tester) async {
    player(played: 500, veteran: true);
    await show(tester);
    expect(
      find.descendant(of: row('achievements'), matching: find.byType(LexChip)),
      findsOneWidget,
    );
  });

  testWidgets('the language row opens the sheet and applies the choice', (
    tester,
  ) async {
    player(played: 500, veteran: true);
    await show(tester);
    await tester.tap(row('language'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-sheet')), findsOneWidget);
    final langs = (await tester.runAsync(WordBank.languages))!;
    final other = langs.firstWhere((l) => l.code != appState.lang);
    await tester.tap(find.byKey(ValueKey('language-${other.code}')));
    await tester.pumpAndSettle();
    expect(appState.lang, other.code);
    expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
  });
}
