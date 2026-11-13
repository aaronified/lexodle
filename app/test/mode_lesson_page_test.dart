import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/first_run/lesson_game.dart';
import 'package:lexodle/first_run/mode_lesson_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/mode_settings_page.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lessonModes = [
  GameMode.quartet,
  GameMode.relay,
  GameMode.lockdown,
  GameMode.blind,
  GameMode.equations,
  GameMode.mastermind,
  GameMode.themed,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', length: 5, tries: 6);
    appState.modesTaught.clear();
  });

  late LessonBank bank;
  var done = 0;

  Future<void> open(WidgetTester t, GameMode mode) async {
    await t.binding.setSurfaceSize(const Size(420, 1100));
    addTearDown(() => t.binding.setSurfaceSize(null));
    bank = (await t.runAsync(() => loadLessonBank(mode)))!;
    done = 0;
    await t.pumpWidget(
      MaterialApp(
        home: ModeLessonPage(mode: mode, onDone: () => done++),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
  }

  Future<void> typeWord(
    WidgetTester t,
    String w, {
    Set<int> skip = const {},
  }) async {
    // the slots a lockdown locked are not typed
    for (var i = 0; i < w.length; i++) {
      if (skip.contains(i)) continue;
      await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: w[i]);
    }
    await t.pump();
  }

  Future<void> enter(WidgetTester t) async {
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
  }

  String coach(WidgetTester t) =>
      (t.widget(find.byKey(const ValueKey('coach'))) as Text).data!;

  /// A scripted play: a mirror of the lesson works out which word to type next.
  String nextWord(LessonGame m, GameMode mode) {
    if (m.made == 0) return bank.engine.pool.first;
    switch (mode) {
      case GameMode.quartet:
        return m.targets[m.solved.indexOf(false)];
      case GameMode.relay:
        if (m.targets.length > m.active) return m.targets[m.active];
        return bank.engine.pool.firstWhere(
          (w) => !m.boards.any((b) => b.any((r) => r.word == w)),
        );
      case GameMode.mastermind:
        return m.candidates.first;
      default:
        return m.targets.first;
    }
  }

  Future<void> playToTheEnd(WidgetTester t, GameMode mode) async {
    final mirror = LessonGame(mode, bank.engine);
    var guard = 0;
    while (!mirror.done && guard++ < 60) {
      final w = nextWord(mirror, mode);
      await typeWord(t, w, skip: mirror.greens.keys.toSet());
      await enter(t);
      mirror.guess(w);
    }
    expect(mirror.done, isTrue);
  }

  for (final mode in _lessonModes) {
    testWidgets('${mode.label}: builds, plays to the end, finishes once', (
      t,
    ) async {
      await open(t, mode);
      expect(find.text('lesson'), findsOneWidget);
      expect(find.byKey(const ValueKey('lesson-close')), findsOneWidget);
      expect(coach(t), isNotEmpty);
      // no tries limit and no guess count anywhere
      expect(find.textContaining('tries'), findsNothing);
      expect(find.textContaining('left'), findsNothing);
      expect(appState.isTaught(mode), isFalse);

      await playToTheEnd(t, mode);
      expect(find.byKey(const ValueKey('lesson-got-it')), findsOneWidget);
      expect(done, 0);
      expect(appState.isTaught(mode), isFalse);

      await t.tap(find.byKey(const ValueKey('lesson-got-it')));
      await t.pump();
      expect(done, 1);
      expect(appState.isTaught(mode), isTrue);

      // the X after finishing does not call it again
      await t.tap(find.byKey(const ValueKey('lesson-close')));
      await t.pump();
      expect(done, 1);
    });
  }

  testWidgets('the X calls onDone once and does not mark the mode', (t) async {
    await open(t, GameMode.quartet);
    await t.tap(find.byKey(const ValueKey('lesson-close')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('lesson-close')));
    await t.pump();
    expect(done, 1);
    expect(appState.isTaught(GameMode.quartet), isFalse);
  });

  testWidgets('"got it" is offered after two guesses, and finishes', (t) async {
    await open(t, GameMode.mastermind);
    expect(find.byKey(const ValueKey('lesson-got-it')), findsNothing);
    final mirror = LessonGame(GameMode.mastermind, bank.engine);
    for (var i = 0; i < 2; i++) {
      final w = nextWord(mirror, GameMode.mastermind);
      await typeWord(t, w);
      await enter(t);
      mirror.guess(w);
    }
    expect(find.byKey(const ValueKey('lesson-got-it')), findsOneWidget);
    expect(
      (t.widget(find.byKey(const ValueKey('lesson-status'))) as Caption).text,
      '${mirror.candidates.length} possible words',
    );
    await t.tap(find.byKey(const ValueKey('lesson-got-it')));
    await t.pump();
    expect(done, 1);
    expect(appState.isTaught(GameMode.mastermind), isTrue);
  });

  testWidgets('lockdown: a bad word costs a heart and says so', (t) async {
    await open(t, GameMode.lockdown);
    expect(coach(t), startsWith('greens lock by themselves'));
    await typeWord(t, 'qqqqq');
    await enter(t);
    expect(coach(t), 'not a word. you lose a heart.');
  });

  testWidgets('equations: a false equation is refused with its reason', (
    t,
  ) async {
    await open(t, GameMode.equations);
    await typeWord(t, '1+1+1=33');
    await enter(t);
    expect(coach(t), 'both sides must be equal');
  });

  testWidgets('blind: the counts show and a tap pencils a colour', (t) async {
    await open(t, GameMode.blind);
    await typeWord(t, bank.engine.pool.first);
    await enter(t);
    expect(find.byKey(const ValueKey('count-0-g')), findsOneWidget);
    expect(coach(t), 'tap a letter to pencil a colour.');
  });

  testWidgets('classic is the first game again', (t) async {
    await open(t, GameMode.classic);
    expect(find.text('practice'), findsOneWidget);
  });

  test('a taught mode is kept and is not taught twice', () async {
    expect(appState.isTaught(GameMode.relay), isFalse);
    appState.markTaught(GameMode.relay);
    appState.markTaught(GameMode.relay);
    expect(appState.isTaught(GameMode.relay), isTrue);
    expect(appState.isTaught(GameMode.blind), isFalse);
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('modesTaught'), ['relay']);
    // it comes back after a restart
    await appState.load();
    expect(appState.isTaught(GameMode.relay), isTrue);
    expect(appState.settingsJson()['modesTaught'], ['relay']);
  });

  testWidgets('the mode settings note shows once', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 1700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    const key = ValueKey('mode-settings-first-note');
    await t.pumpWidget(const MaterialApp(home: ModeSettingsPage()));
    await t.pump();
    expect(find.byKey(key), findsOneWidget);
    expect(
      find.text('these change free play only: the daily never changes'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('mode-settings-note-close')));
    await t.pump();
    expect(find.byKey(key), findsNothing);
    // opened again: never again
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pumpWidget(const MaterialApp(home: ModeSettingsPage()));
    await t.pump();
    expect(find.byKey(key), findsNothing);
  });
}
