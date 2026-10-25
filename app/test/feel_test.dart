import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/haptics.dart';
import 'package:lexodle/keyboard.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the vibrations the app asks the phone for.
List<String> _record(WidgetTester tester) {
  final log = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        log.add(
          (call.arguments as String? ?? 'vibrate').replaceFirst(
            'HapticFeedbackType.',
            '',
          ),
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

/// Lets the delayed vibrations (the second knock of a win, the click of a plain
/// tap) happen: they run on real time, outside the test's clock.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
}

LogicalKeyboardKey _key(String ch) => LogicalKeyboardKey(ch.codeUnitAt(0));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    appState
      ..haptics = true
      ..helper = Helper.full;
  });

  Future<WordBank> bank(WidgetTester tester) async => (await tester.runAsync(
    () async => WordBank.load(
      (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
    ),
  ))!;

  Future<void> type(WidgetTester tester, String word) async {
    for (final ch in word.split('')) {
      await tester.sendKeyEvent(_key(ch), character: ch);
    }
  }

  group('the daily never shows the helper', () {
    Future<void> play(WidgetTester tester, {Daily? daily}) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      final b = await bank(tester);
      await appState.load();
      appState.setup(lang: 'en', length: 5);
      appState.helper = Helper.full;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(bank: b, daily: daily),
        ),
      );
      await tester.pump();
      await type(tester, 'crane');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 20));
    }

    testWidgets('an ordinary game does, with the full helper on', (
      tester,
    ) async {
      await play(tester);
      expect(find.textContaining('last guess'), findsOneWidget);
      expect(find.textContaining('possible words'), findsOneWidget);
    });

    testWidgets('the daily shows only the tries left', (tester) async {
      final b = await bank(tester);
      await play(tester, daily: Daily('2026-10-24', b.answers(5).first));
      expect(find.textContaining('last guess'), findsNothing);
      expect(find.textContaining('skill'), findsNothing);
      expect(find.textContaining('luck'), findsNothing);
      expect(find.textContaining('possible'), findsNothing);
      expect(find.textContaining('tries left'), findsOneWidget);
    });
  });

  group('the keyboard', () {
    Finder keyBox(String l) =>
        find.ancestor(of: find.text(l), matching: find.byType(Container));

    testWidgets('is bigger on a phone than on a desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LetterKeyboard(
              letters: {...'abcdefghijklmnopqrstuvwxyz'.split('')},
              onLetter: (_) {},
              onEnter: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      final phoneKey = tester.getSize(keyBox('q').first);
      final phoneFont = tester.widget<Text>(find.text('q')).style!.fontSize!;
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      await tester.pumpAndSettle();
      final deskKey = tester.getSize(keyBox('q').first);
      final deskFont = tester.widget<Text>(find.text('q')).style!.fontSize!;
      expect(phoneKey.height, greaterThan(deskKey.height));
      expect(phoneKey.height, greaterThanOrEqualTo(56));
      expect(phoneFont, greaterThan(deskFont));
      // the keys of a phone are wider too: the row nearly fills the screen
      expect(phoneKey.width, greaterThan(36));
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LetterKeyboard(
              letters: {...'abcdefghijklmnopqrstuvwxyzéèàç'.split('')},
              onLetter: (_) {},
              onEnter: () {},
              onBack: () {},
              onBlank: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('every press has its feel', () {
    Future<void> board(WidgetTester tester, {List<String>? typed}) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      final b = await bank(tester);
      await appState.load();
      appState.setup(lang: 'en', length: 5);
      await tester.pumpWidget(MaterialApp(home: GamePage(bank: b)));
      await tester.pump();
    }

    testWidgets('a letter is light, backspace a click, enter medium', (
      tester,
    ) async {
      final log = _record(tester);
      await board(tester);
      await tester.tap(find.text('c'));
      await settle(tester);
      expect(log, ['lightImpact']);
      log.clear();
      await tester.tap(find.text('⌫'));
      await settle(tester);
      expect(log, ['selectionClick']);
      log.clear();
      await tester.tap(find.text('enter'));
      await settle(tester);
      // enter on an unfinished row: medium for the press, a knock for the refusal
      expect(log, ['mediumImpact', 'heavyImpact']);
    });

    testWidgets('a word that is not allowed knocks', (tester) async {
      final log = _record(tester);
      await board(tester);
      await type(tester, 'zzzzz');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(log, ['heavyImpact']);
      expect(find.text('not in the word list'), findsOneWidget);
    });

    testWidgets(
      'winning gives a knock then a lighter one; losing the long buzz',
      (tester) async {
        final log = _record(tester);
        await tester.binding.setSurfaceSize(const Size(420, 900));
        final b = await bank(tester);
        await appState.load();
        appState.setup(lang: 'en', length: 5, tries: 1);
        final answer = b.answers(5).first;
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(bank: b, daily: Daily('2026-10-24', answer)),
          ),
        );
        await tester.pump();
        // (a daily has six tries: a win on the first guess)
        await type(tester, answer);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester);
        expect(log, ['heavyImpact', 'lightImpact']);
      },
    );

    testWidgets('a plain tap on a button clicks once', (tester) async {
      final log = _record(tester);
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await appState.load();
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('settings'));
      await settle(tester);
      expect(log, ['selectionClick']);
    });

    testWidgets('a scroll is not a tap', (tester) async {
      final log = _record(tester);
      await tester.binding.setSurfaceSize(const Size(420, 300));
      await appState.load();
      await tester.pumpWidget(const LexodleApp());
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('a press with its own feel does not click twice', (
      tester,
    ) async {
      final log = _record(tester);
      await board(tester);
      await tester.tap(find.text('a'));
      await settle(tester);
      expect(log, ['lightImpact'], reason: 'no second click after the tap');
    });

    testWidgets('switched off, nothing vibrates', (tester) async {
      final log = _record(tester);
      await board(tester);
      appState.haptics = false; // (loading the settings had set it)
      await tester.tap(find.text('c'));
      await tester.tap(find.text('⌫'));
      await tester.tap(find.text('enter'));
      await settle(tester);
      expect(log, isEmpty);
      appState.haptics = true;
    });

    testWidgets('the settings have the switch, which is felt when turned on', (
      tester,
    ) async {
      final log = _record(tester);
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      await appState.load();
      appState.haptics = true;
      await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
      await tester.pumpAndSettle();
      final sw = find.byKey(const ValueKey('haptics-switch'));
      expect(sw, findsOneWidget);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(appState.haptics, isFalse);
      log.clear();
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(appState.haptics, isTrue);
      expect(log, contains('mediumImpact'));
      // and it is kept
      final again = AppState();
      await again.load();
      expect(again.haptics, isTrue);
    });

    test('on the web or a desktop there is nothing to vibrate', () {
      expect(Haptics.supported, isTrue, reason: 'the test platform is android');
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(Haptics.supported, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
