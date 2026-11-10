import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/learn_home.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/words_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(
      lang: 'en',
      length: 5,
      tries: 6,
      mode: GameMode.classic,
      draw: Draw.sigmoid,
    );
    appState.ach.clear();
    appState.savedWords = SavedWords();
  });

  Future<void> home(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(const LexodleApp());
    await tester.pumpAndSettle();
  }

  String labelOf(WidgetTester tester, String key) {
    final text = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(text).data!;
  }

  group('home entry buttons', () {
    testWidgets('how to play and my words sit side by side', (tester) async {
      await home(tester);
      final howTo = tester.getCenter(
        find.byKey(const ValueKey('how-to-button')),
      );
      final words = tester.getCenter(
        find.byKey(const ValueKey('words-button')),
      );
      expect((howTo.dy - words.dy).abs(), lessThan(1.0));
      expect(howTo.dx, lessThan(words.dx));
    });

    testWidgets('tapping my words opens the words page', (tester) async {
      await home(tester);
      await tester.tap(find.byKey(const ValueKey('words-button')));
      await tester.pumpAndSettle();
      expect(find.byType(WordsPage), findsOneWidget);
    });

    testWidgets('the label has the count of saved words', (tester) async {
      await home(tester);
      expect(labelOf(tester, 'words-button'), 'my words');

      appState.saveWord('en', 'clubs', null, today: '2026-11-12');
      await tester.pumpAndSettle();
      expect(labelOf(tester, 'words-button'), contains('1'));
    });
  });

  group('learn page entry', () {
    testWidgets('the my words card opens the words page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      appState.setup(lang: 'fr', length: 4);
      final bank = (await tester.runAsync(
        () async => WordBank.load(
          (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: LearnHomePage(bank: bank),
          onGenerateRoute: onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('learn-card-words'));
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(WordsPage), findsOneWidget);
    });
  });
}
