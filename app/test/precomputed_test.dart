import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/analysis_worker_stub.dart' as web;
import 'package:lexodle/equations.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/opening_disk.dart';
import 'package:lexodle/precomputed.dart';
import 'package:lexodle/precomputed_local.dart';
import 'package:lexodle/precomputed_section.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    forgetPrecomputed();
  });
  tearDown(() {
    precomputedClient = () => MockClient((_) async => http.Response('', 404));
  });

  /// The equations of 7, and the kept analysis the workflow would publish.
  Future<(List<String>, Map<String, int>?, String, Uint8List)> published(
    Directory tmp,
  ) async {
    final en = (await WordBank.languages()).firstWhere((l) => l.code == 'en');
    final bank = await Equations.load(en);
    final words = bank.guessable(7);
    final weights = bank.law(7, Draw.equal);
    final key = openingKeyOf(words, words, weights, false);
    final disk = DiskOpenings(dir: tmp, cap: 1 << 40, keep: 1 << 20);
    await analyseGuesses(words, words, k: 5, weights: weights, disk: disk);
    final bytes = File('${tmp.path}/${openingFileName(key)}.bin')
        .readAsBytesSync();
    return (words, weights, key, bytes);
  }

  final manifestText = jsonEncode({
    'format': 1,
    'generated': '2026-11-04T00:00:00Z',
    'files': [
      {
        'key': '6371/6371/true/1',
        'list': 'equations',
        'length': 7,
        'draw': 'equal',
        'blind': false,
        'bytes': 25492,
        'treeBytes': 1196,
      },
      {
        'key': '9000/9000/true/2',
        'list': 'en',
        'length': 5,
        'draw': 'equal',
        'blind': false,
        'bytes': 3000000,
        'treeBytes': 2000,
      },
    ],
  });

  test('the manifest says what there is and how big it is', () {
    final m = PrecomputedManifest.parse(manifestText)!;
    expect(m.lists, {'equations': 26688, 'en': 3002000});
    expect(m.bytes, 3028688);
    expect(m.of('en').single.name, '9000_9000_true_2');
    expect(PrecomputedManifest.parse('not json'), isNull);
    expect(PrecomputedManifest.parse('{"format":2,"files":[]}'), isNull);
    expect(sizeText(26688), '27 KB');
    expect(sizeText(1002000), '979 KB');
    expect(sizeText(3002000), '2.9 MB');
    expect(sizeText(21 * 1024 * 1024), '21 MB');
  });

  test('the web fetches the published opening, and works without it', () async {
    final tmp = Directory.systemTemp.createTempSync('lex-pre');
    final (words, weights, key, bytes) = await published(tmp);
    final asked = <String>[];
    precomputedClient = () => MockClient((r) async {
      asked.add(r.url.path);
      return r.url.path.endsWith('${openingFileName(key)}.bin')
          ? http.Response.bytes(bytes, 200)
          : http.Response('', 404);
    });
    final fetched = await web.analyse(
      words,
      words,
      5,
      weights,
      null,
      false,
      true,
    );
    expect(asked, [
      '/aaronified/lexodle/precomputed/openings/${openingFileName(key)}.bin',
    ]);
    // what was kept gives the same best guess as working it out
    precomputedClient = () => MockClient((_) async => http.Response('', 404));
    forgetPrecomputed();
    final worked = await web.analyse(
      words,
      words,
      5,
      weights,
      null,
      false,
      true,
    );
    expect(fetched.top.first.word, worked.top.first.word);
    expect(fetched.top.first.skill, closeTo(worked.top.first.skill, 0.01));
    tmp.deleteSync(recursive: true);
  });

  test('a download is kept, listed, and read as a kept opening', () async {
    final tmp = Directory.systemTemp.createTempSync('lex-pre');
    final saved = PrecomputedLocal.dir;
    PrecomputedLocal.dir = Directory('${tmp.path}/local');
    addTearDown(() => PrecomputedLocal.dir = saved);
    precomputedClient = () => MockClient((r) async {
      if (r.url.path.contains('/openings/')) {
        return http.Response.bytes([1, 2, 3, 4], 200);
      }
      if (r.url.path.contains('/trees/')) {
        return http.Response('{"first":"x","groups":[]}', 200);
      }
      return http.Response('', 404);
    });
    final m = PrecomputedManifest.parse(manifestText)!;
    final progress = <double>[];
    final ok = await PrecomputedLocal.download(m, [
      'equations',
    ], onProgress: progress.add);
    expect(ok, isTrue);
    expect(progress.last, 1);
    expect(PrecomputedLocal.downloaded(), {
      'equations': '2026-11-04T00:00:00Z',
    });
    expect(PrecomputedLocal.size(), greaterThan(4));
    // the analysis finds it where it would have kept its own
    final disk = DiskOpenings(dir: Directory('${tmp.path}/cache'));
    expect(disk.read('6371/6371/true/1'), [1, 2, 3, 4]);
    expect(PrecomputedLocal.readTree('6371_6371_true_1'), contains('"first"'));
    // a file that did not come: the list is not marked as downloaded
    precomputedClient = () => MockClient((_) async => http.Response('', 404));
    forgetPrecomputed();
    final again = await PrecomputedLocal.download(m, ['en']);
    expect(again, isFalse);
    expect(PrecomputedLocal.downloaded().containsKey('en'), isFalse);
    PrecomputedLocal.remove();
    expect(PrecomputedLocal.size(), 0);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('the settings section shows the size, then downloads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
    final tmp = Directory.systemTemp.createTempSync('lex-pre');
    final saved = PrecomputedLocal.dir;
    PrecomputedLocal.dir = Directory('${tmp.path}/local');
    addTearDown(() => PrecomputedLocal.dir = saved);
    precomputedClient = () => MockClient((r) async {
      if (r.url.path.endsWith('manifest.json')) {
        return http.Response(manifestText, 200);
      }
      return http.Response.bytes([1, 2, 3], 200);
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrecomputedSection())),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    // told the size before anything is downloaded
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('precomputed-mine')),
        matching: find.text('english · download 2.9 MB'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('download 27 KB'), findsOneWidget);
    expect(find.byKey(const ValueKey('precomputed-remove')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('precomputed-equations')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('precomputed-note')), findsOneWidget);
    expect(find.textContaining('downloaded'), findsWidgets);
    expect(find.byKey(const ValueKey('precomputed-remove')), findsOneWidget);
    PrecomputedLocal.remove();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('with nothing published it says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await appState.load();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrecomputedSection())),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('precomputed-none')), findsOneWidget);
  });
}
