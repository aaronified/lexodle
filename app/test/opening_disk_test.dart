import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/opening_disk.dart';
import 'package:lexodle/opening_parallel.dart';

class _Mem implements OpeningDisk {
  final files = <String, Uint8List>{};
  @override
  Uint8List? read(String key) => files[key];
  @override
  void write(String key, Uint8List bytes) => files[key] = bytes;
}

List<String> _words(int n, int seed) {
  final rng = Random(seed);
  return {
    for (var i = 0; i < n * 2; i++)
      String.fromCharCodes(List.generate(5, (_) => 97 + rng.nextInt(26))),
  }.take(n).toList();
}

void main() {
  test('an opening kept on the disk gives the same skill numbers', () async {
    final a = _words(2100, 1), b = _words(2100, 2);
    final disk = _Mem();
    final first = await analyseGuesses(a, a, answer: a[5], disk: disk);
    expect(disk.files, hasLength(1));
    expect(first.partial, isFalse);
    // another position in between, so the first is no longer held in memory
    await analyseGuesses(b, b, disk: disk);
    final again = await analyseGuesses(a, a, answer: a[5], disk: disk);
    expect(again.partial, isTrue);
    expect(again.luckiest, isEmpty);
    expect(again.bestGain, first.bestGain);
    expect(again.bestRisk, first.bestRisk);
    expect(again.top.map((r) => r.word), first.top.map((r) => r.word));
    expect(again.gains.length, first.gains.length);
    for (var i = 0; i < first.gains.length; i++) {
      expect((again.gains[i] - first.gains[i]).abs(), lessThan(0.001));
    }
    // the best guess still ranks first
    expect(again.rankPercent(first.bestGain), 0);
  });

  test('a damaged file is a miss', () async {
    final a = _words(2100, 3);
    final disk = _Mem();
    await analyseGuesses(a, a, disk: disk);
    final key = disk.files.keys.single;
    disk.files[key] = Uint8List(5);
    await analyseGuesses(_words(2100, 4), _words(2100, 4), disk: disk);
    final land = await analyseGuesses(a, a, answer: a[0], disk: disk);
    expect(land.partial, isFalse);
    expect(land.luckiest, isNotEmpty);
  });

  test('the disk keeps to its cap, deleting the oldest first', () {
    final dir = Directory.systemTemp.createTempSync('lexodle-cap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final disk = DiskOpenings(dir: dir, cap: 1000);
    final bytes = Uint8List(600);
    disk.write('one', bytes);
    File('${dir.path}/one.bin').setLastModifiedSync(DateTime(2020));
    disk.write('two', bytes);
    expect(disk.read('one'), isNull);
    expect(disk.read('two'), isNotNull);
    disk.write('three', bytes);
    expect(dir.listSync(), hasLength(1));
  });

  test('scoring on several threads gives what one thread gives', () async {
    final a = _words(2100, 5);
    final law = {for (final x in a) x: 1 + x.codeUnitAt(0)};
    final one = await analyseGuesses(a, a, weights: law, answer: a[9]);
    // another position, so the first is no longer held in memory
    final b = _words(2100, 6);
    await analyseGuesses(b, b, weights: law);
    final same = await analyseGuesses(
      a,
      a,
      weights: law,
      answer: a[9],
      scorer: (e, w, b, words, ans) =>
          scoreOnThreads(e, w, b, words, ans, threads: 3),
    );
    expect(same.partial, isFalse);
    expect(same.gains, one.gains);
    expect(same.bestRisk, one.bestRisk);
    expect(
      same.top.map((r) => (r.word, r.expected)),
      one.top.map((r) => (r.word, r.expected)),
    );
    expect(
      same.luckiest.map((p) => (p.word, p.luck)),
      one.luckiest.map((p) => (p.word, p.luck)),
    );
  });

  test('a few threads, never all the cores', () {
    expect(scoringThreads(), inInclusiveRange(1, 4));
  });
}
