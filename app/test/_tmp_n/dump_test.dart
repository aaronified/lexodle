import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:lexodle/wikt/de.dart';
void main() {
  test('dump', () {
    final out = StringBuffer();
    for (final w in ['Stadt','leben','böse']) {
      final i = parseGerman(File('test/fixtures/de-wikt-$w.html').readAsStringSync(), 'u');
      out.writeln('== $w ${jsonEncode(i?.toJson())}');
    }
    File('/tmp/claude-0/-home-user-lexodle/e5c14bb6-7449-561b-b9ad-a577b9f3e899/scratchpad/dump_de.txt').writeAsStringSync(out.toString());
  });
}
