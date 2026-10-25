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
    testWidgets('spells out every number of tries and every length', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            length: 5,
            lengths: const [4, 5, 6, 7, 8],
            available: 4994,
            onChanged: (_, _) {},
          ),
        ),
      );
      for (final t in ['8 tries', '6 tries', '4 tries', '3 tries']) {
        expect(find.text(t), findsOneWidget);
      }
      for (final n in [4, 5, 6, 7, 8]) {
        expect(find.text('$n letters'), findsOneWidget);
      }
      expect(
        find.text('normal · 5 letters: 6 tries, 4,994 words of this length'),
        findsOneWidget,
      );
    });

    testWidgets('only the lengths a language has are rows, longest first', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 3,
            length: 5,
            lengths: const [5, 6],
            available: null,
            onChanged: (_, _) {},
          ),
        ),
      );
      expect(find.text('5 letters'), findsOneWidget);
      expect(find.text('6 letters'), findsOneWidget);
      expect(find.text('4 letters'), findsNothing);
      expect(find.text('8 letters'), findsNothing);
      expect(
        tester.getTopLeft(find.text('6 letters')).dy,
        lessThan(tester.getTopLeft(find.text('5 letters')).dy),
        reason: 'the longest, easiest, row is at the top',
      );
      expect(
        find.text('brutal · 5 letters: 3 tries, every word of this length'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a cell chooses that tries and length', (tester) async {
      (int, int)? chosen;
      await tester.pumpWidget(
        host(
          DifficultyMatrix(
            tries: 6,
            length: 5,
            lengths: const [4, 5, 6, 7, 8],
            available: 4994,
            onChanged: (t, n) => chosen = (t, n),
          ),
        ),
      );
      // the hard corner: brutal (3 tries), the shortest word
      await tester.tap(find.bySemanticsLabel('3 tries, 4 letters'));
      expect(chosen, (3, 4));
      await tester.tap(find.bySemanticsLabel('8 tries, 8 letters'));
      expect(chosen, (8, 8));
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
      'drawing words by frequency is on by default, saved, and reloaded',
      () async {
        SharedPreferences.setMockInitialValues({});
        final a = AppState();
        await a.load();
        expect(a.useFrequency, isTrue);
        a.setup(useFrequency: false, tries: 4);
        final b = AppState();
        await b.load();
        expect((b.useFrequency, b.tries), (false, 4));

        SharedPreferences.setMockInitialValues({'useFrequency': true});
        final c = AppState();
        await c.load();
        expect(c.useFrequency, isTrue);
      },
    );

    test('a saved pool from before the word pool went is ignored', () async {
      SharedPreferences.setMockInitialValues({'pool': 1234});
      final a = AppState();
      await a.load();
      expect(a.useFrequency, isTrue);
      expect(a.tries, 6);
    });
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

    testWidgets('every language has a flag, a bundled SVG', (tester) async {
      final langs = (await tester.runAsync(WordBank.languages))!;
      for (final l in langs) {
        expect(l.flag, startsWith('svg:'), reason: l.code);
        expect(
          File('assets/flags/${l.flag.substring(4)}.svg').existsSync(),
          isTrue,
          reason: l.code,
        );
      }
      // the two Englishes and the two Portuguese have a flag each
      expect(langs.firstWhere((l) => l.code == 'en').flag, 'svg:us');
      expect(langs.firstWhere((l) => l.code == 'en-GB').flag, 'svg:gb');
      expect(langs.firstWhere((l) => l.code == 'pt').flag, 'svg:br');
      expect(langs.firstWhere((l) => l.code == 'pt-PT').flag, 'svg:pt');
      expect(langs.firstWhere((l) => l.code == 'ca').flag, 'svg:ca');
      // and no two share one
      expect({for (final l in langs) l.flag}.length, langs.length);
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
