import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/first_run/mode_lesson_page.dart';
import 'package:lexodle/ladder.dart';
import 'package:lexodle/learn_home.dart';
import 'package:lexodle/learn_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appState.learnLog = LearnLog();
    appState.achOf('').clear();
    appState.lex.veteran = true;
    appState.stats.played = 0;
    appState.setup(mode: GameMode.classic);
  });

  String today() => DateTime.now().toIso8601String().substring(0, 10);

  LearnEvent event(
    LearnKind kind, {
    String language = 'fr',
    int length = 4,
    int questions = 10,
    int right = 7,
    double skill = 80,
    String? date,
  }) => LearnEvent(
    kind: kind,
    language: language,
    length: length,
    date: date ?? today(),
    questions: questions,
    right: right,
    avgSkill: skill,
  );

  Future<List<String>> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    appState.setup(lang: 'fr', length: 4);
    final bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      ),
    ))!;
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LearnHomePage(bank: bank),
        onGenerateRoute: (s) {
          opened.add(s.name!);
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(appBar: AppBar(), body: const Text('x')),
          );
        },
      ),
    );
    await tester.pump();
    return opened;
  }

  String text(WidgetTester tester, String key) =>
      textOf(tester.widget<Text>(find.byKey(ValueKey(key))))!;

  testWidgets('at one game learn shows only the classic how to play', (
    tester,
  ) async {
    appState.lex.veteran = false;
    appState.stats.played = 1;
    await open(tester);
    expect(
      find.byKey(const ValueKey('learn-card-how-to-play')),
      findsOneWidget,
    );
    expect(find.text('how to play classic'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-modes')), findsNothing);
    for (final k in ['free', 'choose', 'closing', 'sequence']) {
      expect(find.byKey(ValueKey('learn-card-$k')), findsNothing);
    }
    for (final k in ['guide', 'opening', 'styles', 'words']) {
      expect(find.byKey(ValueKey('learn-card-$k')), findsNothing);
    }
  });

  testWidgets('a second open mode adds its pill and row', (tester) async {
    appState.lex.veteran = false;
    appState.stats.played = 4;
    await open(tester);
    expect(find.byKey(const ValueKey('learn-modes')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-free')), findsNothing);
    appState.setup(mode: GameMode.quartet);
    await tester.pump();
    expect(find.text('how to play quartet'), findsOneWidget);
    expect(find.text('how to play classic'), findsNothing);
  });

  testWidgets('at 24 games the full page shows', (tester) async {
    appState.lex.veteran = false;
    appState.stats.played = 24;
    await open(tester);
    expect(find.byKey(const ValueKey('learn-card-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-card-free')), findsOneWidget);
  });

  testWidgets('a new player sees three activities, none tried', (tester) async {
    await open(tester);
    for (final k in ['free', 'choose', 'closing', 'sequence']) {
      expect(find.byKey(ValueKey('learn-card-$k')), findsOneWidget);
      expect(text(tester, 'learn-progress-$k'), 'not tried yet at this length');
      expect(find.byKey(ValueKey('learn-trend-$k')), findsNothing);
    }
    expect(find.byKey(const ValueKey('learn-streak')), findsNothing);
  });

  testWidgets('each card says how its last round went, with a trend', (
    tester,
  ) async {
    appState.learnLog = LearnLog([
      event(LearnKind.choose, right: 4, skill: 50),
      event(LearnKind.choose, right: 9, skill: 90),
      // another language and another length are not counted
      event(LearnKind.choose, language: 'de', right: 1, skill: 10),
      event(LearnKind.choose, length: 5, right: 2, skill: 20),
      event(LearnKind.free, questions: 3, right: 2, skill: 95),
    ]);
    await open(tester);
    expect(
      text(tester, 'learn-progress-choose'),
      'last round: 9 of 10 right · skill 90',
    );
    expect(text(tester, 'learn-trend-choose'), sparkline([50, 90]));
    expect(
      text(tester, 'learn-progress-free'),
      'last word: 2 of 3 guesses the best · skill 95',
    );
    expect(
      text(tester, 'learn-progress-closing'),
      'not tried yet at this length',
    );
  });

  testWidgets('the streak is shown once there is one', (tester) async {
    appState.learnLog = LearnLog([event(LearnKind.free)]);
    await open(tester);
    expect(text(tester, 'learn-streak'), '1 day in a row');
  });

  testWidgets('a card opens its activity', (tester) async {
    final opened = await open(tester);
    await tester.tap(find.byKey(const ValueKey('learn-card-free')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnFree);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-card-choose')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnChoose);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-card-closing')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnClosing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('learn-card-sequence')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-card-sequence')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnSequence);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-card-opening')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnOpening);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-card-styles')));
    await tester.pumpAndSettle();
    expect(opened.last, Routes.learnStyles);
  });

  testWidgets('the how to play row opens the lesson of the mode', (
    tester,
  ) async {
    await open(tester);
    appState.setup(mode: GameMode.quartet);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('learn-card-how-to-play')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ModeLessonPage), findsOneWidget);
    appState.setup(mode: GameMode.classic);
  });

  testWidgets('it follows the log: a round recorded updates the card', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('learn-trend-closing')), findsNothing);
    appState.recordLearn(event(LearnKind.closing, questions: 10, right: 10));
    await tester.pump();
    expect(
      text(tester, 'learn-progress-closing'),
      'last round: 10 of 10 right · skill 80',
    );
    expect(find.byKey(const ValueKey('learn-streak')), findsOneWidget);
  });

  testWidgets('mode pills: the open modes, a tap changes the mode', (
    tester,
  ) async {
    await open(tester);
    appState.setup(mode: GameMode.classic);
    await tester.pump();
    expect(find.byKey(const ValueKey('learn-modes')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-all')), findsNothing);
    final open_ = openModes(
      appState.stats.played,
      veteran: appState.lex.veteran,
    ).where((m) => GameMode.loopFor(appState.lang).contains(m));
    for (final m in GameMode.values) {
      expect(
        find.byKey(ValueKey('mode-${m.name}')),
        open_.contains(m) ? findsOneWidget : findsNothing,
      );
    }
    final other = open_.firstWhere(
      (m) => m != GameMode.classic,
      orElse: () => GameMode.classic,
    );
    if (other != GameMode.classic) {
      await tester.tap(find.byKey(ValueKey('mode-${other.name}')));
      await tester.pump();
      expect(appState.mode, other);
      appState.setup(mode: GameMode.classic);
    }
  });
}
