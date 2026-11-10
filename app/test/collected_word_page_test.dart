import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/collected_word_page.dart';
import 'package:lexodle/collection.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/ui.dart';
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

  Future<void> pumpPage(WidgetTester tester) async {
    // the bundled languages are read as real I/O, outside the fake clock
    await tester.runAsync(() => WordBank.languages());
    await tester.pumpWidget(
      const MaterialApp(
        home: CollectedWordPage(ref: CollectedRef('en', 'clubs')),
      ),
    );
    await tester.pump();
  }

  Finder bookmark() => find.byKey(const ValueKey('save-word'));

  // the fake lookup runs as real async work, so wait for it outside the fake clock
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the word, the bookmark and the caption', (tester) async {
    fakeEntry();
    await pumpPage(tester);

    expect(find.text('clubs'), findsOneWidget);
    expect(bookmark(), findsOneWidget);
    expect(
      find.text(
        'collected · the entry is looked up as you read it. tap the bookmark to keep a copy that opens without a connection.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the entry text appears after the lookup', (tester) async {
    fakeEntry();
    await pumpPage(tester);
    await settle(tester);

    expect(find.text('looking up in wiktionary…'), findsNothing);
    expect(find.text('could not reach wiktionary'), findsNothing);
    expect(find.text('no wiktionary entry for this word'), findsNothing);
    expect(find.text('The snake was coiled about his ankle.'), findsOneWidget);
  });

  testWidgets('tapping the bookmark saves the word', (tester) async {
    fakeEntry();
    await pumpPage(tester);
    await settle(tester);
    expect(appState.isWordSaved('en', 'clubs'), isFalse);

    await tester.tap(bookmark());
    await settle(tester);

    expect(appState.isWordSaved('en', 'clubs'), isTrue);
    expect(appState.savedWords.find('en', 'clubs')?.info, isNotNull);
  });

  testWidgets('a failing lookup shows a caption and does not throw', (
    tester,
  ) async {
    failingLookup();
    await pumpPage(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(bookmark(), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Caption &&
            (w.text == 'could not reach wiktionary' ||
                w.text == 'no wiktionary entry for this word'),
      ),
      findsOneWidget,
    );
  });
}
