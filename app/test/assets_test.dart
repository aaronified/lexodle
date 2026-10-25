import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/licences.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';

import 'support/fonts.dart';

/// What the app draws it draws from files it carries: no emoji font (which a
/// device may lack, Windows draws no flags, and a web page fetches from a font
/// server), no CDN, no other site.
/// The flags (a pair of regional indicators) and the rest of the emoji planes.
final _flag = RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true);
final _emoji = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);
final _anyEmoji = RegExp(
  r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}]',
  unicode: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // read in the real zone: a font loaded under a test's fake time never arrives
  setUpAll(loadAppFonts);

  final langs = [
    for (final m in jsonDecode(
      File('assets/words/languages.json').readAsStringSync(),
    ) as List)
      (m as Map).cast<String, dynamic>(),
  ];

  /// The files a flag name draws: `fr` is one, `gb+us` is two.
  List<String> parts(Map<String, dynamic> m) =>
      (m['flag'] as String).substring(4).split('+');

  group('the flags', () {
    test('every language has one, and it is a file in the assets', () {
      expect(langs.length, 17);
      for (final m in langs) {
        final flag = m['flag'] as String;
        expect(flag, startsWith('svg:'), reason: '${m['code']}: not an emoji');
        expect(parts(m).length, lessThanOrEqualTo(2), reason: flag);
        for (final name in parts(m)) {
          final file = File('assets/flags/$name.svg');
          expect(file.existsSync(), isTrue, reason: '${m['code']}: $flag');
          expect(file.readAsStringSync(), contains('<svg'));
        }
      }
    });

    test('English and Portuguese show their two flags', () {
      final flags = {for (final m in langs) m['code']: m['flag']};
      expect(flags['en'], 'svg:gb+us');
      expect(flags['pt'], 'svg:br+pt');
      expect(flags.containsKey('en-GB'), isFalse);
      expect(flags.containsKey('pt-PT'), isFalse);
    });

    test('there is no emoji left in the language table', () {
      final text = File('assets/words/languages.json').readAsStringSync();
      // regional indicators, the pairs of which are flags, and the emoji planes
      expect(_flag.hasMatch(text), isFalse);
      expect(_emoji.hasMatch(text), isFalse);
    });

    test('the table the word lists are built from says the same', () {
      final py = File('tools/build_words.py').readAsStringSync();
      for (final m in langs) {
        expect(
          py,
          contains('"${m['code']}", '),
          reason: 'a row for ${m['code']}',
        );
        expect(py, contains('"${m['flag']}")'), reason: '${m['code']}');
      }
      expect(_flag.hasMatch(py), isFalse);
    });

    test('the flags are small, so the app is not made heavy by them', () {
      var total = 0;
      for (final f in Directory('assets/flags').listSync().whereType<File>()) {
        if (!f.path.endsWith('.svg')) continue;
        total += f.lengthSync();
        expect(f.lengthSync(), lessThan(4096), reason: f.path);
      }
      expect(total, lessThan(20000));
    });

    test('each is cropped to the flag, so they sit alike in a badge', () {
      for (final m in langs) {
        for (final name in parts(m)) {
          final svg = File('assets/flags/$name.svg').readAsStringSync();
          if (name == 'ca') continue; // drawn for the project, already 3:2
          expect(svg, contains('viewBox="0 5 36 26"'), reason: name);
        }
      }
    });

    test('and the graphics are credited, with their licence', () {
      final notice = File('assets/flags/NOTICE.txt').readAsStringSync();
      expect(notice, contains('Twemoji'));
      expect(notice, contains('CC BY 4.0'));
      expect(notice, contains('github.com/jdecked/twemoji'));
      expect(
        File('assets/flags/LICENSE-twemoji-graphics.txt').readAsStringSync(),
        contains('Attribution 4.0 International'),
      );
    });

    testWidgets('every one draws as an image, at the sizes the app uses', (
      tester,
    ) async {
      for (final size in [14.0, 16.0, 20.0, 28.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Wrap(
                children: [
                  for (final m in langs)
                    FlagBadge(m['flag'] as String, size: size),
                ],
              ),
            ),
          ),
        );
        // SVG assets are read with real file IO, which fake-async cannot await
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await tester.pump();
        // a merged language draws two flags, each cropped to half of its width
        final drawn = langs.fold<int>(0, (n, m) => n + parts(m).length);
        expect(find.byType(SvgPicture), findsNWidgets(drawn));
        expect(find.byType(Text), findsNothing, reason: 'no emoji text');
        expect(tester.takeException(), isNull, reason: 'at $size');
      }
    });

    testWidgets('the picker and the game title carry no emoji either', (
      tester,
    ) async {
      // every place a flag is shown goes through FlagBadge with the table's
      // value, so a table without emoji is a screen without them
      final texts = [
        for (final f in Directory(
          'lib',
        ).listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart'))
            if (_anyEmoji.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(texts, isEmpty, reason: 'emoji in the sources: $texts');
    });
  });

  group('licences', () {
    testWidgets('the flags are among the licences the app shows', (
      tester,
    ) async {
      registerLicences();
      final entries = await tester.runAsync(
        () => LicenseRegistry.licenses.toList(),
      );
      final flat = [
        for (final e in entries!) ...[
          e.packages.join(' '),
          e.paragraphs.map((p) => p.text).join('\n'),
        ],
      ].join('\n');
      expect(flat, contains('Flags (Twemoji graphics, CC BY 4.0)'));
      expect(flat, contains('Attribution 4.0 International'));
      expect(flat, contains('github.com/jdecked/twemoji'));
      // and the rest are still there
      expect(flat, contains('JetBrains Mono'));
      expect(flat, contains('Tabler Icons'));
    });
  });

  group('nothing the page draws with is fetched from another site', () {
    test('the web page asks no other site for a script, style or font', () {
      final html = File('web/index.html').readAsStringSync();
      final externals = RegExp(
        r'''(?:src|href)\s*=\s*["']https?://[^"']*["']''',
      ).allMatches(html).map((m) => m.group(0)).toList();
      expect(externals, isEmpty, reason: '$externals');
      expect(html, isNot(contains('fonts.googleapis.com')));
      expect(html, isNot(contains('fonts.gstatic.com')));
      expect(html, isNot(contains('@import')));
      expect(
        RegExp(
          r'url\(\s*["'
          "'"
          r']?https?://',
        ).hasMatch(html),
        isFalse,
      );
    });

    test('the deploy builds with CanvasKit served from the app, not a CDN', () {
      final yml = File('../.github/workflows/pages.yml').readAsStringSync();
      expect(yml, contains('flutter build web'));
      expect(yml, contains('--no-web-resources-cdn'));
    });

    test('the app declares the fonts, icons and flags it draws with', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dir in ['assets/icons/', 'assets/flags/', 'assets/words/']) {
        expect(pubspec, contains('- $dir'), reason: dir);
        expect(Directory(dir).existsSync(), isTrue, reason: dir);
      }
      expect(pubspec, contains('family: JetBrainsMono'));
      final faces = RegExp(r'asset:\s*(\S+)').allMatches(pubspec).toList();
      expect(faces.length, greaterThanOrEqualTo(2));
      for (final m in faces) {
        expect(File(m.group(1)!).existsSync(), isTrue, reason: m.group(1));
      }
      expect(RegExp(r'uses-material-design:\s*true').hasMatch(pubspec), isTrue);
    });

    test('the only things the app source fetches are definitions and the time', () {
      // every address the code can ask: Wiktionary for the meaning of the
      // answer, and the hosting site for the time
      final hosts = <String>{};
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final m in RegExp(
          r'https?://([a-zA-Z0-9.-]+)',
        ).allMatches(f.readAsStringSync())) {
          hosts.add(m.group(1)!);
        }
      }
      // (en.wiktionary.org and its siblings; the licences and credits that name
      // a project are text, not addresses the app asks; github.com is the wiki,
      // which the player's browser opens from a "learn more" link, never the
      // app: see wiki_links.dart)
      final fetched = hosts.where(
        (h) =>
            !h.endsWith('wiktionary.org') &&
            h != 'aaronified.github.io' &&
            h != 'github.com',
      );
      expect(fetched, isEmpty, reason: 'unexpected hosts: $fetched');
    });
  });

  test('the glyph check is there to run, and says how', () {
    final py = File('tools/check_glyphs.py').readAsStringSync();
    expect(py, contains('JetBrainsMono-Regular.ttf'));
    expect(py, contains('JetBrainsMono-Bold.ttf'));
    expect(py, contains('assets/words/*.txt'));
    expect(py, contains('lib/**/*.dart'));
  });

  test('the fonts a test is given are in the repository', () {
    for (final f in [
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Bold.ttf',
      'assets/fonts/OFL.txt',
      'test/fonts/MaterialIcons-Regular.otf',
      'test/fonts/LICENSE-materialicons.txt',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
      expect(File(f).lengthSync(), greaterThan(0), reason: f);
    }
    expect(kIsWeb, isFalse);
  });

  test('the word lists are the words of the languages in the table', () {
    for (final m in langs) {
      expect(File('assets/words/${m['code']}.txt').existsSync(), isTrue);
    }
    expect(WordBank, isNotNull);
  });
}
