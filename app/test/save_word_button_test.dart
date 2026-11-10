import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/app_log.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/save_word_button.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.savedWords = SavedWords();
    Wiktionary.reset();
  });

  tearDown(() {
    Wiktionary.reset();
    Wiktionary.shared = Wiktionary();
  });

  // a fake Wiktionary: one English section, with the about fixture as its text

  void fakeEntry() {
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
  }

  void failingLookup() {
    Wiktionary.shared = Wiktionary(
      client: MockClient((req) async => http.Response('nope', 500)),
    );
  }

  Future<Language> english(WidgetTester tester) async {
    final langs = await tester.runAsync(() => WordBank.languages());
    return langs!.firstWhere((l) => l.code == 'en');
  }

  Future<void> pumpButton(WidgetTester tester, Language lang) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveWordButton(word: 'clubs', language: lang),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapAndWait(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('save-word')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder button() => find.byKey(const ValueKey('save-word'));

  testWidgets('tap saves the word with its entry', (tester) async {
    fakeEntry();
    final lang = await english(tester);
    await pumpButton(tester, lang);
    expect(appState.isWordSaved('en', 'clubs'), isFalse);

    await tapAndWait(tester);

    expect(appState.isWordSaved('en', 'clubs'), isTrue);
    expect(appState.savedWords.find('en', 'clubs')?.info, isNotNull);
    expect(find.text('saved to my words'), findsOneWidget);
  });

  testWidgets('tap again removes the word', (tester) async {
    fakeEntry();
    final lang = await english(tester);
    await pumpButton(tester, lang);
    await tapAndWait(tester);
    expect(appState.isWordSaved('en', 'clubs'), isTrue);

    await tapAndWait(tester);

    expect(appState.isWordSaved('en', 'clubs'), isFalse);
    expect(find.text('removed from my words'), findsOneWidget);
  });

  testWidgets('a failing lookup still saves the word, with no entry', (
    tester,
  ) async {
    failingLookup();
    final lang = await english(tester);
    await pumpButton(tester, lang);

    await tapAndWait(tester);

    expect(appState.isWordSaved('en', 'clubs'), isTrue);
    expect(appState.savedWords.find('en', 'clubs')?.info, isNull);
    expect(
      appLog.tail(200).where((l) => l.contains(' W saveword: ')),
      isNotEmpty,
      reason: 'the failed lookup is logged',
    );
  });

  testWidgets('the tooltip says what a tap will do', (tester) async {
    fakeEntry();
    final lang = await english(tester);
    await pumpButton(tester, lang);
    expect(tester.widget<IconButton>(button()).tooltip, 'save to my words');

    await tapAndWait(tester);
    expect(tester.widget<IconButton>(button()).tooltip, 'remove from my words');

    await tapAndWait(tester);
    expect(tester.widget<IconButton>(button()).tooltip, 'save to my words');
  });
}
