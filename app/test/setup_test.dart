import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/difficulty.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
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
      'the word draw is the curve by default, saved, and reloaded',
      () async {
        SharedPreferences.setMockInitialValues({});
        final a = AppState();
        await a.load();
        expect(a.draw, Draw.sigmoid);
        a.setup(draw: Draw.equal, tries: 4, hearts: 3);
        final b = AppState();
        await b.load();
        expect((b.draw, b.tries, b.hearts), (Draw.equal, 4, 3));

        // the old on / off switch keeps what the player chose
        SharedPreferences.setMockInitialValues({'useFrequency': true});
        final c = AppState();
        await c.load();
        expect(c.draw, Draw.frequency);
        SharedPreferences.setMockInitialValues({'useFrequency': false});
        final d = AppState();
        await d.load();
        expect(d.draw, Draw.equal);
      },
    );

    test('a saved pool from before the word pool went is ignored', () async {
      SharedPreferences.setMockInitialValues({'pool': 1234});
      final a = AppState();
      await a.load();
      expect(a.draw, Draw.sigmoid);
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
        hasLength(17),
      ); // English and Portuguese are one language each, spellings merged
      expect(langs.map((l) => l.code), isNot(contains('fi')));
      expect(langs.map((l) => l.code), isNot(contains('en-GB')));
      expect(langs.map((l) => l.code), isNot(contains('pt-PT')));
      for (final l in langs) {
        expect(l.lengths, isNotEmpty, reason: l.code);
        for (final n in l.lengths) {
          expect(l.counts[n], isNotNull, reason: '${l.code} $n');
          expect(
            l.counts[n],
            inInclusiveRange(400, 30000),
            reason: '${l.code} $n',
          );
        }
      }
    });

    testWidgets('every language has a flag, a bundled SVG', (tester) async {
      final langs = (await tester.runAsync(WordBank.languages))!;
      for (final l in langs) {
        expect(l.flag, startsWith('svg:'), reason: l.code);
        for (final name in l.flag.substring(4).split('+')) {
          expect(
            File('assets/flags/$name.svg').existsSync(),
            isTrue,
            reason: '${l.code}: $name',
          );
        }
      }
      // English and Portuguese carry the flags of both variants
      expect(langs.firstWhere((l) => l.code == 'en').flag, 'svg:gb+us');
      expect(langs.firstWhere((l) => l.code == 'pt').flag, 'svg:br+pt');
      expect(langs.firstWhere((l) => l.code == 'ca').flag, 'svg:ca');
      // and no two share one
      expect({for (final l in langs) l.flag}.length, langs.length);
    });

    /// word -> weight, as the file has it
    Map<String, int> weights(String code) => {
      for (final line in File('assets/words/$code.txt').readAsLinesSync())
        line.split('\t').first: int.parse(line.split('\t')[1]),
    };

    test('the variants are merged, so no list is left for one of them', () {
      for (final code in ['en-GB', 'pt-PT']) {
        expect(
          File('assets/words/$code.txt').existsSync(),
          isFalse,
          reason: code,
        );
      }
    });

    test('English holds American and British spellings, merged', () {
      final en = weights('en');
      for (final w in [
        'color',
        'colour',
        'favor',
        'favour',
        'center',
        'centre',
        'meter',
        'metre',
      ]) {
        expect(en, contains(w));
      }
      expect('color'.length, 5);
      expect('colour'.length, 6);
      // a word is kept if either dictionary accepts it, so the spelling of
      // only one is no reason to lose it
      expect(en.length, greaterThan(25000));
    });

    test('a word only one variant accepts has half the weight of a shared one', () {
      final en = weights('en');
      // raw wordfreq weight (int(10 ** zipf)) of the words, which no dictionary
      // changes: `color` and `metre` are accepted by one variant of two, so
      // they weigh half of it; `about` and `their` by both, so all of it
      const raw = {'color': 81284, 'metre': 5754, 'about': 2511886};
      expect(en['about'], raw['about'], reason: 'shared: the full weight');
      expect(en['their'], 2137962, reason: 'shared: the full weight');
      expect(en['color'], inInclusiveRange(40641, 40643));
      expect(
        en['color']!,
        closeTo(raw['color']! / 2, 1),
        reason: 'half of the raw weight',
      );
      expect(en['metre']!, closeTo(raw['metre']! / 2, 1));
      // the shared word is not halved
      expect(en['about']!, greaterThan(en['color']! * 50));
    });

    test('Portuguese holds Brazilian and European spellings, merged', () {
      final pt = weights('pt');
      expect(pt, contains('prêmio')); // Brazil
      expect(pt, contains('prémio')); // Portugal
      expect(pt, contains('ônibus')); // Brazil only
      // a shared word keeps its full weight, one used by a single variant has
      // half of its raw weight (prêmio 104712, prémio 22908, wordfreq)
      expect(pt['casa'], 977237);
      expect(pt['tempo'], 1047128);
      expect(pt['prêmio']!, closeTo(104712 / 2, 1));
      expect(pt['prémio']!, closeTo(22908 / 2, 1));
      expect(pt['casa']!, greaterThan(pt['prêmio']!));
    });

    test('the Portuguese list carries no names, and keeps the real words', () {
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
      final w = weights('pt');
      for (final name in names) {
        expect(w, isNot(contains(name)), reason: name);
      }
      for (final word in ['casa', 'falar', 'tempo', 'cidade', 'amigo']) {
        expect(w, contains(word), reason: word);
      }
    });

    test('the counts in the language table match the lists', () {
      final table = jsonDecode(
        File('assets/words/languages.json').readAsStringSync(),
      ) as List;
      for (final m in table.cast<Map<String, dynamic>>()) {
        final code = m['code'] as String;
        final byLength = <int, int>{};
        for (final w in weights(code).keys) {
          byLength[w.length] = (byLength[w.length] ?? 0) + 1;
        }
        final counts = (m['counts'] as Map).cast<String, int>();
        for (final n in (m['lengths'] as List).cast<int>()) {
          expect(byLength[n], counts['$n'], reason: '$code $n');
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
      // two places fix a colour by design: the one colour of each measure
      // (skill blue, luck yellow, daring green; ui.dart) and the black theme
      // (main.dart)
      final fixedByDesign = RegExp(r'(ui|main)\.dart$');
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            for (final (i, line) in f.readAsLinesSync().indexed)
              if (hardCoded.hasMatch(line) &&
                  !line.trimLeft().startsWith('//') &&
                  !(fixedByDesign.hasMatch(f.path) &&
                      !line.contains('Colors.')))
                '${f.path}:${i + 1}: ${line.trim()}',
      ];
      expect(offenders, isEmpty);
    },
  );
}
