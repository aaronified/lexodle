import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(Widget child, {Brightness b = Brightness.dark}) => MaterialApp(
  theme: buildTheme(b),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('difficulty matrix', () {
    testWidgets('spells out every pool size and every number of tries', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            pool: 1500,
            available: 6000,
            onChanged: (_, _) {},
          ),
        ),
      );
      for (final t in ['8 tries', '6 tries', '4 tries', '3 tries']) {
        expect(find.text(t), findsOneWidget);
      }
      for (final w in [
        '500 words',
        '1,500 words',
        '3,000 words',
        '6,000 words',
      ]) {
        expect(find.text(w), findsOneWidget);
      }
      expect(
        find.textContaining('answers from the 1,500 most common words'),
        findsOneWidget,
      );
    });

    testWidgets('a language with fewer words says so', (tester) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 3,
            pool: 6000,
            available: 2383,
            onChanged: (_, _) {},
          ),
        ),
      );
      // 2,383 words are not 1,000 more than familiar's 1,500 and wide's 3,000
      // is not reachable, so there are two rows, and the last takes every
      // word: no word is left behind. A saved 6,000 shows as that last row.
      expect(find.text('500 words'), findsOneWidget);
      expect(find.text('2,383 words'), findsOneWidget);
      expect(find.text('familiar · all'), findsOneWidget);
      expect(find.text('1,500 words'), findsNothing);
      expect(find.text('3,000 words'), findsNothing);
      expect(find.text('6,000 words'), findsNothing);
      expect(find.text('wide'), findsNothing);
      expect(find.text('obscure'), findsNothing);
      expect(find.bySemanticsLabel('3 tries, 2383 words'), findsOneWidget);
      expect(find.bySemanticsLabel('3 tries, 6000 words'), findsNothing);
      expect(
        find.textContaining('answers from all 2,383 words'),
        findsOneWidget,
      );
    });

    testWidgets('English at five letters gets obscure, as all its words', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            pool: 6000,
            available: 4994,
            onChanged: (_, _) {},
          ),
        ),
      );
      // 4,994 words are 1,000 more than wide's 3,000, so obscure is offered
      // and is every word English has at that length
      for (final t in ['500', '1,500', '3,000', '4,994']) {
        expect(find.text('$t words'), findsOneWidget, reason: t);
      }
      expect(find.text('obscure · all'), findsOneWidget);
      expect(find.text('wide'), findsOneWidget);
      expect(find.text('6,000 words'), findsNothing);
      expect(
        find.textContaining('answers from all 4,994 words'),
        findsOneWidget,
      );
    });

    testWidgets('a language with plenty offers all four rows', (tester) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            pool: 3000,
            available: 6000,
            onChanged: (_, _) {},
          ),
        ),
      );
      for (final t in ['500', '1,500', '3,000', '6,000']) {
        expect(find.text('$t words'), findsOneWidget, reason: t);
      }
      expect(find.text('obscure'), findsOneWidget);
    });

    test('a level needs 1,000 more words than the level below it', () {
      expect(poolsOffered(null), poolSizes);
      expect(poolsOffered(10), [500], reason: 'always the smallest');
      expect(poolsOffered(1499), [500]);
      expect(poolsOffered(1500), [500, 1500]); // exactly 1,000 more than 500
      expect(poolsOffered(2383), [500, 1500]);
      expect(poolsOffered(2499), [500, 1500]);
      expect(poolsOffered(2500), [500, 1500, 3000]); // 1,000 more than 1,500
      expect(poolsOffered(3999), [500, 1500, 3000]);
      expect(poolsOffered(4000), poolSizes); // 1,000 more than 3,000
      expect(poolsOffered(4994), poolSizes);
      expect(poolsOffered(6000), poolSizes);
    });

    test('the last level takes every word, so none is left behind', () {
      // a level that is not the last is its round number
      expect(poolWords(500, 4994), 500);
      expect(poolWords(1500, 4994), 1500);
      expect(poolWords(3000, 4994), 3000);
      // the last one is everything
      expect(poolWords(6000, 4994), 4994);
      expect(poolWords(6000, 6000), 6000);
      expect(poolWords(1500, 2383), 2383, reason: 'familiar is the last');
      expect(poolWords(500, 2383), 500);
      expect(poolWords(3000, 3900), 3900, reason: 'wide is the last');
      expect(
        poolWords(500, 1200),
        1200,
        reason: 'a short list is all one level',
      );
      // a level not offered means the biggest one that is
      expect(poolWords(6000, 2383), 2383);
      expect(poolWords(3000, 2383), 2383);
      expect(poolWords(3000, null), 3000);
    });

    test('the pool a saved choice means follows what the language offers', () {
      expect(effectivePool(6000, 2383), 1500);
      expect(effectivePool(3000, 2383), 1500);
      expect(effectivePool(1500, 2383), 1500);
      expect(effectivePool(500, 2383), 500);
      expect(effectivePool(6000, 6000), 6000);
      expect(effectivePool(6000, 4994), 6000);
      expect(effectivePool(6000, 3999), 3000);
      expect(effectivePool(3000, null), 3000);
      expect(effectivePool(1500, 10), 500);
    });

    testWidgets('tapping a cell chooses that tries and pool', (tester) async {
      (int, int)? chosen;
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            pool: 1500,
            available: 6000,
            onChanged: (t, p) => chosen = (t, p),
          ),
        ),
      );
      // the hard corner: brutal (3 tries), obscure (6,000 words)
      await tester.tap(find.bySemanticsLabel('3 tries, 6000 words'));
      expect(chosen, (3, 6000));
      await tester.tap(find.bySemanticsLabel('8 tries, 500 words'));
      expect(chosen, (8, 500));
    });

    test('the colour runs from the scheme green to the scheme purple', () {
      for (final b in Brightness.values) {
        final c = buildTheme(b).colorScheme;
        expect(
          difficultyColor(c, 0),
          HSLColor.fromColor(c.secondary).toColor(),
        );
        expect(difficultyColor(c, 1), HSLColor.fromColor(c.primary).toColor());
        // the hue only ever increases from green towards purple
        var last = -1.0;
        for (var i = 0; i <= 6; i++) {
          final h = HSLColor.fromColor(difficultyColor(c, i / 6)).hue;
          expect(h, greaterThanOrEqualTo(last));
          last = h;
        }
      }
    });
  });

  group('settings', () {
    test(
      'the pool is saved, and a value that is not an offered size is ignored',
      () async {
        SharedPreferences.setMockInitialValues({});
        final a = AppState();
        await a.load();
        expect(a.pool, defaultPool);
        a.setup(pool: 3000, tries: 4);
        final b = AppState();
        await b.load();
        expect((b.pool, b.tries), (3000, 4));

        SharedPreferences.setMockInitialValues({'pool': 1234});
        final c = AppState();
        await c.load();
        expect(c.pool, defaultPool);
      },
    );
  });

  group('word lists', () {
    testWidgets('every language reports how many words it has at each length', (
      tester,
    ) async {
      final langs = (await tester.runAsync(WordBank.languages))!;
      expect(
        langs,
        hasLength(19),
      ); // 17 languages, English and Portuguese in two spellings each
      expect(langs.map((l) => l.code), isNot(contains('fi')));
      for (final l in langs) {
        expect(l.lengths, isNotEmpty, reason: l.code);
        for (final n in l.lengths) {
          expect(l.counts[n], isNotNull, reason: '${l.code} $n');
          expect(
            l.counts[n],
            inInclusiveRange(400, 6000),
            reason: '${l.code} $n',
          );
        }
      }
    });

    testWidgets('every language has a flag; Catalan\'s is drawn', (
      tester,
    ) async {
      final langs = (await tester.runAsync(WordBank.languages))!;
      for (final l in langs) {
        expect(l.flag, isNotEmpty, reason: l.code);
      }
      final ca = langs.firstWhere((l) => l.code == 'ca');
      expect(ca.flag, 'svg:ca');
      expect(File('assets/flags/ca.svg').existsSync(), isTrue);
      expect(langs.firstWhere((l) => l.code == 'en').flag, '🇺🇸');
      expect(langs.firstWhere((l) => l.code == 'en-GB').flag, '🇬🇧');
    });

    Set<String> words(String code) => {
      for (final l in File('assets/words/$code.txt').readAsLinesSync())
        l.split('\t').first,
    };

    test('American and British English differ in spelling', () {
      final us = words('en'), uk = words('en-GB');
      for (final w in ['color', 'favor', 'center', 'defense']) {
        expect(us, contains(w));
        expect(uk, isNot(contains(w)), reason: w);
      }
      for (final w in ['colour', 'favour', 'centre', 'defence']) {
        expect(uk, contains(w));
        expect(us, isNot(contains(w)), reason: w);
      }
      expect(us.intersection(uk).length, greaterThan(15000)); // mostly shared
    });

    test('Brazilian and European Portuguese differ in spelling', () {
      final br = words('pt'), pt = words('pt-PT');
      expect(br, contains('prêmio'));
      expect(br, isNot(contains('prémio')));
      expect(pt, contains('prémio'));
      expect(pt, isNot(contains('prêmio')));
    });

    test('the Portuguese lists carry no names, and keep the real words', () {
      // names the dictionary alone lets through, in lowercase
      const names = [
        'paulo',
        'maria',
        'pedro',
        'jorge',
        'lisboa',
        'israel',
        'miguel',
        'adam',
        'nico',
        'lena',
        'rafa',
      ];
      for (final code in ['pt', 'pt-PT']) {
        final w = words(code);
        for (final name in names) {
          expect(w, isNot(contains(name)), reason: '$code: $name');
        }
        for (final word in ['casa', 'falar', 'tempo', 'cidade', 'amigo']) {
          expect(w, contains(word), reason: '$code: $word');
        }
      }
    });

    test('names and fragments are filtered out, common words are in', () {
      final en = {
        for (final l in File('assets/words/en.txt').readAsLinesSync())
          l.split('\t').first,
      };
      for (final w in ['their', 'every', 'house', 'crane', 'along']) {
        expect(en, contains(w));
      }
      for (final w in ['david', 'james', 'texas', 'paris', 'jesus', 'april']) {
        expect(en, isNot(contains(w)), reason: w);
      }
    });

    test('lists are sorted by weight within each length', () {
      for (final code in ['en', 'fr', 'de']) {
        final last = <int, int>{};
        for (final line in File('assets/words/$code.txt').readAsLinesSync()) {
          final parts = line.split('\t');
          final n = parts[0].length;
          final weight = int.parse(parts[1]);
          if (last.containsKey(n)) {
            expect(
              weight,
              lessThanOrEqualTo(last[n]!),
              reason: '$code ${parts[0]}',
            );
          }
          last[n] = weight;
        }
      }
    });
  });

  test(
    'no colour is hard-coded: everything comes from the Material You scheme',
    () {
      final hardCoded = RegExp(r'Color\(\s*0x|Colors\.(?!transparent)');
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            for (final (i, line) in f.readAsLinesSync().indexed)
              if (hardCoded.hasMatch(line) && !line.trimLeft().startsWith('//'))
                '${f.path}:${i + 1}: ${line.trim()}',
      ];
      expect(offenders, isEmpty);
    },
  );
}
