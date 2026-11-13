import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/word_page.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Wiktionary.reset();
    Wiktionary.shared = Wiktionary();
  });

  setUp(() async {
    Wiktionary.reset();
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
    expect(find.textContaining('no entry was kept'), findsNothing);
    expect(find.byKey(const ValueKey('word-retry')), findsNothing);
  });

  testWidgets('a word with no entry says so and shows the note field', (
    tester,
  ) async {
    appState.saveWord('en', 'zyzzy', null, today: '2026-11-12');
    await pumpPage(tester, appState.savedWords.find('en', 'zyzzy')!);
    expect(find.text('zyzzy'), findsOneWidget);
    expect(
      find.text('no entry was kept. add your own notes below.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('word-note')), findsOneWidget);
    expect(find.text('try the lookup again'), findsOneWidget);
  });

  Future<void> tapRetry(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('word-retry')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('try the lookup again keeps the entry and the note', (
    tester,
  ) async {
    appState.saveWord('en', 'about', null, today: '2026-11-12');
    appState.setWordNote('en', 'about', 'my note');
    final entry = appState.savedWords.find('en', 'about')!;
    final html = File('test/fixtures/en-about.html').readAsStringSync();
    Wiktionary.shared = Wiktionary(
      client: MockClient((req) async {
        if (req.url.queryParameters['prop'] == 'sections') {
          return http.Response(
            jsonEncode({
              'parse': {
                'sections': [
                  {'line': 'English', 'toclevel': 1, 'index': '1'},
                ],
              },
            }),
            200,
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'parse': {'text': html},
            }),
          ),
          200,
        );
      }),
    );
    await pumpPage(tester, entry);
    await tapRetry(tester);

    expect(appState.savedWords.find('en', 'about')!.info, isNotNull);
    expect(appState.savedWords.find('en', 'about')!.note, 'my note');
    expect(find.textContaining('no entry was kept'), findsNothing);
    expect(find.byKey(const ValueKey('word-retry')), findsNothing);
  });

  testWidgets('a failing retry leaves the word as it is', (tester) async {
    appState.saveWord('en', 'about', null, today: '2026-11-12');
    Wiktionary.shared = Wiktionary(
      client: MockClient((req) async => http.Response('nope', 500)),
    );
    await pumpPage(tester, appState.savedWords.find('en', 'about')!);
    await tapRetry(tester);

    expect(appState.savedWords.find('en', 'about')!.info, isNull);
    expect(find.text('could not look it up. try again later'), findsOneWidget);
    expect(find.byKey(const ValueKey('word-retry')), findsOneWidget);
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
