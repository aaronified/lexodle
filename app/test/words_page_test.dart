import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/app_log.dart';
import 'package:lexodle/collected_word_page.dart';
import 'package:lexodle/collection.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/saved_words.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:lexodle/word_page.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/words_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.savedWords = SavedWords();
    appState.collection = Collection();
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

  Future<void> page(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    await tester.pumpWidget(
      MaterialApp(home: const WordsPage(), onGenerateRoute: onGenerateRoute),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the words tab has no back arrow, even with a route under it', (
    tester,
  ) async {
    await page(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  Finder row(String lang, String word) =>
      find.byKey(ValueKey('word-row-$lang-$word'));

  Finder langNext() => find.byKey(const ValueKey('words-language-next'));

  Finder langPrev() => find.byKey(const ValueKey('words-language-prev'));

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

      // the choice runs all, en, fr: two steps on, then two back
      await tester.tap(langNext());
      await tester.pump();
      await tester.tap(langNext());
      await tester.pump();
      expect(row('fr', 'bonjour'), findsOneWidget);
      expect(row('en', 'alpha'), findsNothing);

      await tester.tap(langPrev());
      await tester.pump();
      await tester.tap(langPrev());
      await tester.pump();
      expect(row('en', 'alpha'), findsOneWidget);
      expect(row('fr', 'bonjour'), findsOneWidget);
    });

    testWidgets('the sort menu switches to a to z', (tester) async {
      appState.saveWord('en', 'charlie', null, today: '2026-11-01');
      appState.saveWord('en', 'alpha', null, today: '2026-11-02');
      appState.saveWord('en', 'bravo', null, today: '2026-11-03');
      await page(tester);
      expect(
        tester.getTopLeft(row('en', 'bravo')).dy,
        lessThan(tester.getTopLeft(row('en', 'alpha')).dy),
      );

      await tester.tap(sort());
      await tester.pumpAndSettle();
      expect(find.text('sort saved'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sort-az')));
      await tester.pumpAndSettle();
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
      final line = appLog
          .tail(200)
          .firstWhere(
            (l) => l.contains(' W words: could not open a saved word'),
          );
      // the log never records words
      expect(line.contains('alpha'), isFalse);
    });
  });

  group('collected', () {
    Finder ctab() => find.byKey(const ValueKey('words-tab-collected'));

    Finder stab() => find.byKey(const ValueKey('words-tab-saved'));

    Finder crow(String lang, String word) =>
        find.byKey(ValueKey('collected-row-$lang-$word'));

    Finder cnext() => find.byKey(const ValueKey('collected-language-next'));

    Finder cprev() => find.byKey(const ValueKey('collected-language-prev'));

    Finder csearch() => find.byKey(const ValueKey('collected-search'));

    // the collected words are a two-column grid: a word comes before another
    // when it is on a row above, or on the same row to the left
    bool before(WidgetTester t, Finder a, Finder b) {
      final pa = t.getTopLeft(a);
      final pb = t.getTopLeft(b);
      return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
    }

    Finder saveBtn(String lang, String word) => find.descendant(
      of: crow(lang, word),
      matching: find.byKey(const ValueKey('save-word')),
    );

    Finder filled(String lang, String word) => find.descendant(
      of: crow(lang, word),
      matching: find.byWidgetPredicate(
        (w) => w is TablerIcon && w.name == 'bookmark-filled',
      ),
    );

    void seed() {
      appState.collection.addWord('en', 'clubs');
      appState.collection.addWord('en', 'tours');
      appState.collection.addWord('fr', 'cloche');
      appState.collection.addPlace('paris');
      appState.refresh();
    }

    // loads the languages first, so the save buttons are drawn at once
    Future<void> openCollected(WidgetTester tester) async {
      await tester.runAsync(() => WordBank.languages());
      await page(tester);
      await tester.tap(ctab());
      await tester.pumpAndSettle();
    }

    testWidgets('the collected tab lists newest first; the saved tab is back', (
      tester,
    ) async {
      seed();
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      await openCollected(tester);
      expect(find.text('collected 4'), findsOneWidget);
      expect(find.textContaining('collected · tap'), findsNothing);
      expect(before(tester, crow('en', 'tours'), crow('en', 'clubs')), isTrue);
      expect(row('en', 'alpha'), findsNothing);

      await tester.tap(stab());
      await tester.pumpAndSettle();
      expect(row('en', 'alpha'), findsOneWidget);
      expect(crow('en', 'tours'), findsNothing);
      expect(find.text('1 saved · tap a word for its entry'), findsOneWidget);
    });

    testWidgets('the language pills switch between en, fr and places', (
      tester,
    ) async {
      seed();
      await openCollected(tester);
      expect(crow('en', 'clubs'), findsOneWidget);
      expect(crow('fr', 'cloche'), findsNothing);

      // the choice runs en, fr, places
      await tester.tap(cnext());
      await tester.pumpAndSettle();
      expect(crow('fr', 'cloche'), findsOneWidget);
      expect(crow('en', 'clubs'), findsNothing);

      await tester.tap(cnext());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collected-place-paris')),
        findsOneWidget,
      );
      expect(crow('fr', 'cloche'), findsNothing);

      await tester.tap(cprev());
      await tester.pumpAndSettle();
      await tester.tap(cprev());
      await tester.pumpAndSettle();
      expect(crow('en', 'clubs'), findsOneWidget);
    });

    testWidgets('the all stop lists the words of every language', (
      tester,
    ) async {
      seed();
      await openCollected(tester);
      // the choice runs all, en, fr, places: the one before en is all
      await tester.tap(cprev());
      await tester.pumpAndSettle();
      expect(crow('en', 'clubs'), findsOneWidget);
      expect(crow('fr', 'cloche'), findsOneWidget);
      expect(find.byKey(const ValueKey('collected-place-paris')), findsNothing);
      expect(find.textContaining('words won ·'), findsOneWidget);
      // the search looks at the word, not at the language code in the key
      await tester.enterText(
        find.byKey(const ValueKey('collected-search')),
        'clo',
      );
      await tester.pumpAndSettle();
      expect(crow('fr', 'cloche'), findsOneWidget);
      expect(crow('en', 'clubs'), findsNothing);
    });

    testWidgets('a long list builds only the rows on screen', (tester) async {
      for (var i = 0; i < 600; i++) {
        appState.collection.addWord('en', 'w${i.toString().padLeft(4, 'a')}');
      }
      appState.refresh();
      await openCollected(tester);
      final built = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('collected-row-'),
      );
      // 600 words, a couple of dozen of them built
      expect(built.evaluate().length, lessThan(60));
      expect(built.evaluate().length, greaterThan(0));
    });

    testWidgets('search narrows the collected rows', (tester) async {
      seed();
      await openCollected(tester);
      await tester.enterText(csearch(), 'LUB');
      await tester.pump();
      expect(crow('en', 'clubs'), findsOneWidget);
      expect(crow('en', 'tours'), findsNothing);

      await tester.enterText(csearch(), 'zzz');
      await tester.pump();
      expect(find.text('no collected word matches.'), findsOneWidget);
    });

    testWidgets('a saved collected word shows the filled bookmark', (
      tester,
    ) async {
      fakeEntry();
      seed();
      appState.saveWord('en', 'clubs', null, today: '2026-11-12');
      await openCollected(tester);
      expect(filled('en', 'clubs'), findsOneWidget);
      expect(filled('en', 'tours'), findsNothing);
    });

    testWidgets('the bookmark saves and removes without opening the word', (
      tester,
    ) async {
      fakeEntry();
      seed();
      await openCollected(tester);

      Future<void> tapAndWait() async {
        await tester.tap(saveBtn('en', 'tours'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tapAndWait();
      expect(appState.isWordSaved('en', 'tours'), isTrue);
      expect(filled('en', 'tours'), findsOneWidget);
      expect(find.byType(CollectedWordPage), findsNothing);

      await tapAndWait();
      expect(appState.isWordSaved('en', 'tours'), isFalse);
      expect(find.byType(CollectedWordPage), findsNothing);
    });

    testWidgets('a tap on a collected word opens its page', (tester) async {
      seed();
      await openCollected(tester);
      await tester.tap(crow('en', 'tours'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectedWordPage), findsOneWidget);
    });

    testWidgets('the collected sort menu lists the oldest first', (
      tester,
    ) async {
      seed();
      await openCollected(tester);
      expect(before(tester, crow('en', 'tours'), crow('en', 'clubs')), isTrue);

      await tester.tap(find.byKey(const ValueKey('collected-sort')));
      await tester.pumpAndSettle();
      expect(find.text('sort collected'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sort-oldest')));
      await tester.pumpAndSettle();
      expect(before(tester, crow('en', 'clubs'), crow('en', 'tours')), isTrue);
    });

    testWidgets('an empty collection shows only its caption', (tester) async {
      await openCollected(tester);
      expect(
        find.text(
          'no words collected yet. every word you win is collected here.',
        ),
        findsOneWidget,
      );
      expect(csearch(), findsNothing);
    });
  });

  group('header and banner', () {
    Finder banner(String list) => find.byKey(ValueKey('words-banner-$list'));
    Finder dismiss() => find.byKey(const ValueKey('words-banner-dismiss'));

    setUp(() => appState.dismissedWordBanners.clear());

    testWidgets('swiping changes the tab', (tester) async {
      appState.collection.addWord('en', 'clubs');
      appState.refresh();
      await page(tester);
      expect(find.text('saved 0'), findsOneWidget);
      expect(find.byKey(const ValueKey('collected-search')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('words-pages')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('collected 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('collected-search')), findsOneWidget);
    });

    testWidgets(
      'the top bar is the language pill and the cog, above the tabs',
      (tester) async {
        await page(tester);
        final pill = tester.getCenter(
          find.byKey(const ValueKey('language-slider')),
        );
        final cog = tester.getCenter(
          find.byKey(const ValueKey('settings-button')),
        );
        final tabs = tester.getCenter(find.text('saved 0'));
        expect((pill.dy - cog.dy).abs(), lessThan(1.5));
        expect(tabs.dy, greaterThan(cog.dy));
      },
    );

    testWidgets('the header tabs switch the lists', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.collection.addWord('en', 'clubs');
      appState.refresh();
      await page(tester);
      expect(row('en', 'alpha'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('words-tab-collected')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collected-search')), findsOneWidget);
      expect(row('en', 'alpha'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('words-tab-saved')));
      await tester.pumpAndSettle();
      expect(row('en', 'alpha'), findsOneWidget);
    });

    testWidgets('the banner shows on both tabs', (tester) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.collection.addWord('en', 'clubs');
      appState.refresh();
      await page(tester);
      expect(banner('saved'), findsOneWidget);
      expect(find.text('1 words saved'), findsOneWidget);
      expect(find.textContaining('next trophy at 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('words-tab-collected')));
      await tester.pumpAndSettle();
      expect(banner('collected'), findsOneWidget);
      expect(find.text('1 words collected'), findsOneWidget);
      expect(find.textContaining('next trophy at 10'), findsOneWidget);
    });

    testWidgets('dismissing hides it; a new target shows it again', (
      tester,
    ) async {
      appState.saveWord('en', 'alpha', null, today: '2026-11-01');
      appState.refresh();
      await page(tester);
      await tester.tap(dismiss());
      await tester.pumpAndSettle();
      expect(banner('saved'), findsNothing);
      expect(appState.dismissedWordBanners, contains('saved:5'));
      // five words saved: the target moves on to 25
      for (final w in ['b', 'c', 'd', 'e']) {
        appState.saveWord('en', w, null, today: '2026-11-01');
      }
      appState.refresh();
      await tester.pumpAndSettle();
      expect(banner('saved'), findsOneWidget);
      expect(find.textContaining('next trophy at 25'), findsOneWidget);
    });
  });
}
