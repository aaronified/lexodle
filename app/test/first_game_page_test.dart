import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/first_run/first_game_engine.dart';
import 'package:lexodle/first_run/first_game_page.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

LogicalKeyboardKey _key(String ch) => switch (ch) {
  'a' => LogicalKeyboardKey.keyA,
  'b' => LogicalKeyboardKey.keyB,
  'c' => LogicalKeyboardKey.keyC,
  'd' => LogicalKeyboardKey.keyD,
  'e' => LogicalKeyboardKey.keyE,
  'f' => LogicalKeyboardKey.keyF,
  'g' => LogicalKeyboardKey.keyG,
  'h' => LogicalKeyboardKey.keyH,
  'i' => LogicalKeyboardKey.keyI,
  'j' => LogicalKeyboardKey.keyJ,
  'k' => LogicalKeyboardKey.keyK,
  'l' => LogicalKeyboardKey.keyL,
  'm' => LogicalKeyboardKey.keyM,
  'n' => LogicalKeyboardKey.keyN,
  'o' => LogicalKeyboardKey.keyO,
  'p' => LogicalKeyboardKey.keyP,
  'q' => LogicalKeyboardKey.keyQ,
  'r' => LogicalKeyboardKey.keyR,
  's' => LogicalKeyboardKey.keyS,
  't' => LogicalKeyboardKey.keyT,
  'u' => LogicalKeyboardKey.keyU,
  'v' => LogicalKeyboardKey.keyV,
  'w' => LogicalKeyboardKey.keyW,
  'x' => LogicalKeyboardKey.keyX,
  'y' => LogicalKeyboardKey.keyY,
  _ => LogicalKeyboardKey.keyZ,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> words;
  late FirstGameEngine engine;

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  Future<void> open(
    WidgetTester t, {
    bool practice = false,
    VoidCallback? onDone,
    VoidCallback? onClose,
  }) async {
    await t.binding.setSurfaceSize(const Size(420, 1000));
    await appState.load();
    appState.setup(lang: 'en', length: 5, tries: 6);
    final bank = (await t.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
    words = [
      for (final w in bank.guessable(5))
        if (RegExp(r'^[a-z]{5}$').hasMatch(w)) w,
    ];
    engine = FirstGameEngine(words);
    await t.pumpWidget(
      MaterialApp(
        home: FirstGamePage(
          practice: practice,
          onDone: onDone ?? () {},
          onClose: onClose ?? () {},
        ),
      ),
    );
    await t.pump();
    await t.pump();
  }

  Future<void> typeWord(WidgetTester t, String w) async {
    for (final ch in w.split('')) {
      await t.sendKeyEvent(_key(ch), character: ch);
    }
    await t.pump();
  }

  Future<void> enter(WidgetTester t) async {
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
  }

  String coach(WidgetTester t) =>
      (t.widget(find.byKey(const ValueKey('coach'))) as Text).data!;

  testWidgets('builds with the title and the first line', (t) async {
    await open(t);
    expect(find.text('your first game'), findsOneWidget);
    expect(find.textContaining('tries'), findsNothing);
    expect(coach(t), 'type any five-letter word, then press enter.');
  });

  testWidgets('practice says practice', (t) async {
    await open(t, practice: true);
    expect(find.text('practice'), findsOneWidget);
    expect(find.text('your first game'), findsNothing);
  });

  testWidgets('a word and enter give colours', (t) async {
    await open(t);
    await typeWord(t, words.first);
    expect(coach(t), 'five letters. press enter.');
    await enter(t);
    expect(find.byKey(const ValueKey('tile-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggestion')), findsOneWidget);
    expect(coach(t), startsWith('you have a green'));
  });

  testWidgets('an invalid word offers the fix', (t) async {
    await open(t);
    String bad = '';
    for (final w in words.take(500)) {
      final s = '${w.substring(0, 4)}q';
      if (!engine.isValid(s) && engine.oneLetterFix(s) != null) {
        bad = s;
        break;
      }
    }
    expect(bad, isNotEmpty);
    await typeWord(t, bad);
    await enter(t);
    expect(coach(t), startsWith('not a word.'));
    expect(coach(t), contains('tap the arrow'));
    expect(find.byKey(const ValueKey('fix-arrow')), findsOneWidget);
  });

  testWidgets('the coach lines come in order, then solving calls onDone once', (
    t,
  ) async {
    var done = 0;
    await open(t, onDone: () => done++);
    final g1 = words.first;
    await typeWord(t, g1);
    await enter(t);
    expect(coach(t), startsWith('you have a green'));

    // the suggested word, as the chip offers it
    final chip = find.descendant(
      of: find.byKey(const ValueKey('suggestion')),
      matching: find.byType(Text),
    );
    final g2 = (t.widget(chip) as Text).data!;
    await t.tap(find.byKey(const ValueKey('suggestion')));
    await t.pump();
    await enter(t);
    expect(coach(t), startsWith('not sure of a letter'));

    // a blank ends that step
    await typeWord(t, 'a');
    await t.tap(find.text('_'));
    await t.pump();
    expect(coach(t), startsWith('double tap a letter to lock it'));

    // lock tile 0: the swipe line follows
    final tile = find.byKey(const ValueKey('tile-2-0'));
    await t.tap(tile);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(tile);
    await t.pump();
    expect(coach(t), startsWith('swipe the row to clear it'));

    // clearing the row moves on to the lamp
    await t.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(coach(t), startsWith('stuck? tap the lamp'));
    expect(find.byType(HintBar), findsOneWidget);

    // solve it: the target is the engine's pick after the second guess
    final c = engine.chooseFirst(g1);
    final target = engine.chooseSecond(
      g2,
      candidates: c.candidates,
      suggested: g2,
      target: c.target,
    );
    // unlock whatever the lock left, clear the row
    await t.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(done, 0);
    await typeWord(t, target);
    await enter(t);
    expect(coach(t), startsWith('solved in'));
    expect(done, 0);
    await t.tap(find.byKey(const ValueKey('first-continue')));
    await t.pump();
    expect(done, 1);
  });

  testWidgets('x calls onClose', (t) async {
    var closed = 0;
    await open(t, onClose: () => closed++);
    await t.tap(find.byKey(const ValueKey('first-close')));
    expect(closed, 1);
  });
}
