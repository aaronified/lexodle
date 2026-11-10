import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/app_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/word_page.dart';
import 'package:lexodle/words_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.savedWords = SavedWords();
  });

  Future<void> page(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    await tester.pumpWidget(
      MaterialApp(home: const WordsPage(), onGenerateRoute: onGenerateRoute),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String lang, String word) =>
      find.byKey(ValueKey('word-row-$lang-$word'));

  Finder lang(String code) => find.byKey(ValueKey('words-lang-$code'));

  Finder search() => find.byKey(const ValueKey('words-search'));

  Finder sort() => find.byKey(const ValueKey('words-sort'));

  group('my words', () {
    testWidgets('rows appear newest first', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.saveWord('en', 'bravo', null, today: '2026-11-02');
      appState.saveWord('en', 'charlie', null, today: '2026-11-03');
      await page(tester);
      expect(find.text('3 saved · tap a word for its entry'), findsOneWidget);
      final y = [
        for (final w in ['charlie', 'bravo', 'alpha'])
          tester.getTopLeft(row('en', w)).dy,
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
    });

    testWidgets('a long note is one ellipsised line', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.setWordNote('en', 'alpha', 'n' * 200);
      await page(tester);
      final note = tester.widget<Text>(
        find.byKey(const ValueKey('word-note-en-alpha')),
      );
      expect(note.data, '✎ ${'n' * 200}');
      expect(note.maxLines, 1);
      expect(note.overflow, TextOverflow.ellipsis);
    });

    testWidgets('search narrows rows by word and by note', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.saveWord('en', 'bravo', null, today: '2026-11-02');
      appState.setWordNote('en', 'alpha', 'zebra marker');
      await page(tester);

      await tester.enterText(search(), 'bravo');
      await tester.pump();
      expect(row('en', 'bravo'), findsOneWidget);
      expect(row('en', 'alpha'), findsNothing);

      await tester.enterText(search(), 'ZEBRA');
      await tester.pump();
      expect(row('en', 'alpha'), findsOneWidget);
      expect(row('en', 'bravo'), findsNothing);

      await tester.enterText(search(), 'nothing like this');
      await tester.pump();
      expect(find.text('no saved word matches.'), findsOneWidget);
    });

    testWidgets('the language pill filters', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.saveWord('fr', 'bonjour', null, today: '2026-11-02');
      await page(tester);
      expect(row('en', 'alpha'), findsOneWidget);
      expect(row('fr', 'bonjour'), findsOneWidget);

      await tester.tap(lang('fr'));
      await tester.pump();
      expect(row('fr', 'bonjour'), findsOneWidget);
      expect(row('en', 'alpha'), findsNothing);

      await tester.tap(lang('all'));
      await tester.pump();
      expect(row('en', 'alpha'), findsOneWidget);
      expect(row('fr', 'bonjour'), findsOneWidget);
    });

    testWidgets('the sort pill switches to a to z', (tester) async {
      appState.saveWord('en', 'charlie', null, today: '2026-11-01');
      appState.saveWord('en', 'alpha', null, today: '2026-11-02');
      appState.saveWord('en', 'bravo', null, today: '2026-11-03');
      await page(tester);
      expect(find.text('newest first'), findsOneWidget);
      expect(
        tester.getTopLeft(row('en', 'bravo')).dy,
        lessThan(tester.getTopLeft(row('en', 'alpha')).dy),
      );

      await tester.tap(sort());
      await tester.pump();
      expect(find.text('a to z'), findsOneWidget);
      final y = [
        for (final w in ['alpha', 'bravo', 'charlie'])
          tester.getTopLeft(row('en', w)).dy,
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
    });

    testWidgets('the empty state shows only its caption', (tester) async {
      await page(tester);
      expect(
        find.text(
          'no words saved yet. tap the bookmark on the end screen of a game.',
        ),
        findsOneWidget,
      );
      expect(search(), findsNothing);
      expect(sort(), findsNothing);
    });

    testWidgets('a tap on a row opens the word', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      await page(tester);
      await tester.tap(row('en', 'alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(WordPage), findsOneWidget);
    });

    testWidgets('a failed navigation is logged, not thrown', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      await tester.pumpWidget(
        MaterialApp(
          home: const WordsPage(),
          onGenerateRoute: (settings) {
            if (settings.name == Routes.word) throw StateError('no route');
            return onGenerateRoute(settings);
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(row('en', 'alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(WordsPage), findsOneWidget);
      expect(
        appLog
            .tail(200)
            .any((l) => l.contains(' W words: could not open en alpha')),
        isTrue,
      );
    });
  });
}
