import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/wikt/pl.dart';
import 'package:lexodle/wikt/cs.dart';
import 'package:lexodle/wiktionary.dart';

void main() {
  test('dump', () {
    for (final (f, p) in [
      ('cs-wikt-město', parseCzech),
      ('cs-wikt-dělat', parseCzech),
      ('cs-wikt-velký', parseCzech),
    ]) {
      final i = p(File('test/fixtures/$f.html').readAsStringSync(), 'u');
      print('== $f\n${const JsonEncoder.withIndent(' ').convert(i?.toJson())}');
    }
  });
}
