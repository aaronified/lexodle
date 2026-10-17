import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/licences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the licence page lists the font, icons, word lists and dictionaries',
    (tester) async {
      registerLicences();
      final packages = <String>{};
      final texts = <String>[];
      await tester.runAsync(() async {
        await for (final entry in LicenseRegistry.licenses) {
          packages.addAll(entry.packages);
          texts.add(entry.paragraphs.map((p) => p.text).join('\n'));
        }
      });
      expect(
        packages,
        containsAll([
          'JetBrains Mono (font)',
          'Tabler Icons',
          'Word lists (adapted from wordfreq, CC BY-SA 4.0)',
          'Spelling dictionaries used to filter the word lists',
        ]),
      );
      final all = texts.join('\n');
      expect(all, contains('SIL OPEN FONT LICENSE'));
      expect(all, contains('MIT License'));
      expect(all, contains('ShareAlike'));
    },
  );

  test('the word lists carry the licence their source requires', () {
    final text = File('assets/words/LICENSE.md').readAsStringSync();
    expect(text, contains('CC BY-SA 4.0'));
    expect(text, contains('wordfreq'));
    expect(text, contains('Changes made'));
    expect(text, contains('SUBTLEX'));
    expect(text, contains('OpenSubtitles'));
  });

  test('every dictionary used is listed with a licence', () {
    final text = File('assets/words/SOURCES.md').readAsStringSync();
    final rows = text
        .split('\n')
        .where((l) => l.startsWith('| ') && l.contains('(`'));
    expect(rows, isNotEmpty);
    for (final r in rows) {
      final cells = r.split('|').map((c) => c.trim()).toList();
      expect(cells[3], isNotEmpty, reason: r);
    }
  });
}
