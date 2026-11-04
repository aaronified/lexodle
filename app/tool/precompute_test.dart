// Precomputes the openings of every list the app has, for the app to download
// (and for the web build to read from GitHub). Run by the "precompute"
// workflow, or by hand:
//
//   flutter test tool/precompute_test.dart --timeout none
//
// It uses the app's own scoring (lib/logic.dart) and the word lists in
// assets/, so what it writes is exactly what the app would have worked out and
// kept itself. Settings, by environment variable:
//
//   PRECOMPUTE_OUT      the folder to write (default build/precomputed)
//   PRECOMPUTE_LANGS    language codes, comma separated (default every one);
//                       `equations` and `places` name those two lists
//   PRECOMPUTE_LENGTHS  only these lengths, comma separated (default all)
//
// It writes, per list, length, draw and blind or not:
//   openings/<key>.bin  the gain and risk of every first guess (the app's own
//                       cache format, so the app reads it as it is)
//   trees/<key>.json    the best first guess, and the best second guesses after
//                       each of the 12 likeliest replies to it
//   manifest.json       every file, its size, and what it is for
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis_worker.dart';
import 'package:lexodle/equations.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/opening.dart';
import 'package:lexodle/opening_disk.dart';
import 'package:lexodle/opening_parallel.dart';
import 'package:lexodle/words.dart';

String _name(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('precompute the openings', timeout: Timeout.none, () async {
    final env = Platform.environment;
    final out = Directory(env['PRECOMPUTE_OUT'] ?? 'build/precomputed');
    final only = (env['PRECOMPUTE_LANGS'] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    final lengths = (env['PRECOMPUTE_LENGTHS'] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toSet();
    // the small analyses of the trees run on this thread
    analyseOffMainThread = false;
    final disk = DiskOpenings(
      dir: Directory('${out.path}/openings'),
      cap: 1 << 40,
      keep: 1 << 20,
    );
    Directory('${out.path}/trees').createSync(recursive: true);
    final files = <Map<String, Object?>>[];

    Future<void> one(
      String list,
      WordBank bank,
      int length,
      Draw draw,
      bool blind,
    ) async {
      final words = bank.guessable(length);
      // the app keeps only the big ones; the small are worked out in no time
      if (words.length * words.length < openingCells) return;
      final weights = bank.law(length, draw);
      final key = openingKeyOf(words, words, weights, blind);
      if (files.any((f) => f['key'] == key)) return; // the same analysis
      final land = await analyseGuesses(
        words,
        words,
        k: 5,
        weights: weights,
        blind: blind,
        disk: disk,
        scorer: scoreOnThreads,
      );
      if (land.top.isEmpty) return;
      final best = land.top.first.word;
      final groups = <Map<String, Object?>>[];
      for (final g in openingOutcomes(words, best, weights)) {
        final seconds = await secondGuesses(
          group: g,
          guessable: words,
          weights: weights,
        );
        groups.add({
          'marks': g.marks.map((m) => m.index).join(),
          'words': g.words.length,
          'seconds': [
            for (final r in seconds)
              [r.word, double.parse(r.skill.toStringAsFixed(2))],
          ],
        });
      }
      final tree = File('${out.path}/trees/${_name(key)}.json')
        ..writeAsStringSync(jsonEncode({'first': best, 'groups': groups}));
      final bin = File('${out.path}/openings/${_name(key)}.bin');
      files.add({
        'key': key,
        'list': list,
        'length': length,
        'draw': draw.name,
        'blind': blind,
        'bytes': bin.lengthSync(),
        'treeBytes': tree.lengthSync(),
      });
      // ignore: avoid_print
      print('$list $length ${draw.name}${blind ? ' blind' : ''}: $best');
    }

    final langs = await WordBank.languages();
    final en = langs.firstWhere((l) => l.code == 'en');
    for (final lang in langs) {
      if (only.isNotEmpty && !only.contains(lang.code)) continue;
      final bank = await WordBank.load(lang);
      for (final n in lang.lengths) {
        if (lengths.isNotEmpty && !lengths.contains(n)) continue;
        for (final draw in Draw.values) {
          for (final blind in [false, true]) {
            await one(lang.code, bank, n, draw, blind);
          }
        }
      }
    }
    if (only.isEmpty || only.contains('equations')) {
      final bank = await Equations.load(en);
      for (final n in equationLengths) {
        if (lengths.isNotEmpty && !lengths.contains(n)) continue;
        await one('equations', bank, n, Draw.equal, false);
      }
    }
    if (only.isEmpty || only.contains('places')) {
      final bank = await Geography.load(en);
      for (final n in Geography.counts.keys) {
        if (lengths.isNotEmpty && !lengths.contains(n)) continue;
        for (final draw in [Draw.sigmoid, Draw.equal]) {
          await one('places', bank, n, draw, false);
        }
      }
    }

    final total = files.fold<int>(
      0,
      (t, f) => t + (f['bytes'] as int) + (f['treeBytes'] as int),
    );
    final byList = <String, int>{};
    for (final f in files) {
      byList[f['list'] as String] =
          (byList[f['list'] as String] ?? 0) +
          (f['bytes'] as int) +
          (f['treeBytes'] as int);
    }
    File('${out.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'format': 1,
        'generated': DateTime.now().toUtc().toIso8601String(),
        'bytes': total,
        'lists': byList,
        'files': files,
      }),
    );
    expect(files, isNotEmpty);
  });
}
