import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/word_page.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.savedWords = SavedWords();
  });

  WordInfo clubInfo() {
    final noun = PosBlock('noun')..senses.add(Sense('a group of people'));
    return WordInfo(
      url: 'https://en.wiktionary.org/wiki/club',
      ipa: const ['/klʌb/'],
      blocks: [noun],
    );
  }

  SavedWord saveClub() {
    appState.saveWord('en', 'club', clubInfo(), today: '2026-11-12');
    return appState.savedWords.find('en', 'club')!;
  }

  Future<void> pumpPage(WidgetTester tester, SavedWord entry) async {
    await tester.pumpWidget(MaterialApp(home: WordPage(entry: entry)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the word, its day, the meaning and the pronunciation', (
    tester,
  ) async {
    final entry = saveClub();
    await pumpPage(tester, entry);
    expect(find.text('club'), findsOneWidget);
    expect(find.text('saved 2026-11-12'), findsOneWidget);
    expect(find.textContaining('a group of people'), findsOneWidget);
    expect(find.textContaining('/klʌb/'), findsOneWidget);
    expect(find.text('no entry was kept for this word'), findsNothing);
  });

  testWidgets('a word with no entry says so', (tester) async {
    appState.saveWord('en', 'zyzzy', null, today: '2026-11-12');
    await pumpPage(tester, appState.savedWords.find('en', 'zyzzy')!);
    expect(find.text('zyzzy'), findsOneWidget);
    expect(find.text('no entry was kept for this word'), findsOneWidget);
  });

  testWidgets('typing in the note is kept on the saved word', (tester) async {
    final entry = saveClub();
    await pumpPage(tester, entry);
    await tester.enterText(
      find.byKey(const ValueKey('word-note')),
      'a group of friends',
    );
    await tester.pumpAndSettle();
    expect(entry.note, 'a group of friends');
    expect(appState.savedWords.find('en', 'club')!.note, 'a group of friends');
  });

  testWidgets('keep it hides the confirmation and leaves the word saved', (
    tester,
  ) async {
    final entry = saveClub();
    await pumpPage(tester, entry);
    expect(find.byKey(const ValueKey('word-remove-yes')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('word-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-remove-yes')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-remove-no')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-remove-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-remove-yes')), findsNothing);
    expect(appState.isWordSaved('en', 'club'), isTrue);
  });

  testWidgets('remove it removes the word and leaves the page', (tester) async {
    final entry = saveClub();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-word'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WordPage(entry: entry)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-word')));
    await tester.pumpAndSettle();
    expect(find.byType(WordPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('word-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('word-remove-yes')));
    await tester.pumpAndSettle();
    expect(appState.isWordSaved('en', 'club'), isFalse);
    expect(find.byType(WordPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
