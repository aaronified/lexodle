import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/donate.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/settings_page.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(themeMode: ThemeMode.system, black: false);
  });

  Future<void> show(WidgetTester tester, {VoidCallback? onReplay}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: YouPage(onReplayFirstGame: onReplay ?? () {})),
      ),
    );
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
    for (final id in ['achievements', 'reminders', 'history', 'friends']) {
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
    for (final id in ['achievements', 'reminders', 'history', 'friends']) {
      expect(
        row(id),
        expected.contains(id) ? findsOneWidget : findsNothing,
        reason: '$id at game $played',
      );
    }
    expect(find.text('theme'), findsOneWidget);
  }

  testWidgets(
    'game 1 sees achievements and lex',
    (t) => gated(t, 1, {'achievements'}),
  );
  testWidgets(
    'game 2 adds reminders',
    (t) => gated(t, 2, {'achievements', 'reminders'}),
  );
  testWidgets(
    'game 3 adds backup',
    (t) => gated(t, 3, {'reminders', 'achievements'}),
  );
  testWidgets(
    'game 5 sees everything',
    (t) => gated(t, 5, {'reminders', 'achievements', 'history', 'friends'}),
  );

  testWidgets('the theme choice calls setup, and black needs dark', (
    tester,
  ) async {
    player(played: 500, veteran: true);
    await show(tester);
    Switch sw() => tester.widget<Switch>(find.byType(Switch));
    expect(sw().onChanged, isNull);
    await tester.tap(find.text('dark'));
    await tester.pumpAndSettle();
    expect(appState.themeMode, ThemeMode.dark);
    expect(sw().onChanged, isNotNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(appState.blackTheme, isTrue);
    await tester.tap(find.text('light'));
    await tester.pumpAndSettle();
    expect(appState.themeMode, ThemeMode.light);
    expect(appState.blackTheme, isFalse);
  });

  testWidgets('language and how to play are always there', (
    tester,
  ) async {
    player(played: 0, veteran: false);
    await show(tester);
    for (final id in ['language', 'howto']) {
      expect(row(id), findsOneWidget, reason: id);
    }
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

  testWidgets('how to play and settings push their routes', (tester) async {
    player(played: 500, veteran: true);
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
        home: Scaffold(body: YouPage(onReplayFirstGame: () {})),
      ),
    );
    await tester.pump();
    await tester.tap(row('howto'));
    await tester.pumpAndSettle();
    expect(pushed, [Routes.howTo]);
  });

  Future<RouteSettings> pushedBy(WidgetTester tester, String id) async {
    player(played: 500, veteran: true);
    RouteSettings? got;
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (s) {
          got = s;
          return onGenerateRoute(s);
        },
        home: Scaffold(body: YouPage(onReplayFirstGame: () {})),
      ),
    );
    await tester.pump();
    await tester.tap(row(id));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return got!;
  }

  testWidgets('the support row opens only the support section', (t) async {
    final s = await pushedBy(t, 'support');
    expect(s.name, Routes.settings);
    expect(s.arguments, SettingsPart.support);
    expect(find.byType(DonateSection), findsOneWidget);
    expect(find.text('touch'), findsNothing);
    expect(find.text('about'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('the backup row opens only the backup section', (t) async {
    final s = await pushedBy(t, 'backup');
    expect(s.name, Routes.settings);
    expect(s.arguments, SettingsPart.backup);
    expect(find.byKey(const ValueKey('backup-download')), findsOneWidget);
    expect(find.byType(DonateSection), findsNothing);
    expect(find.text('touch'), findsNothing);
    expect(find.text('about'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('the achievements row shows the lex chip', (tester) async {
    player(played: 500, veteran: true);
    await show(tester);
    expect(
      find.descendant(of: row('achievements'), matching: find.byType(LexChip)),
      findsOneWidget,
    );
  });

  testWidgets('the help button calls back', (tester) async {
    player(played: 500, veteran: true);
    var n = 0;
    await show(tester, onReplay: () => n++);
    await tester.tap(find.byKey(const ValueKey('you-help')));
    expect(n, 1);
  });
}
