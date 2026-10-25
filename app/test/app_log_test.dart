import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/app_log.dart';
import 'package:lexodle/auto_backup.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backup_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackupFiles files;
  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    files = FakeBackupFiles();
    AutoBackup.files = files;
  });
  tearDown(() => AutoBackup.files = const PlatformBackupFiles());

  group('the log', () {
    test('lines carry a time, a level and a tag', () {
      final log = AppLog(files: files);
      log.i('app', 'hello');
      log.w('store', 'odd');
      log.e('save', 'failed');
      expect(log.length, 3);
      final lines = log.session.trim().split('\n');
      expect(lines[0], matches(r'^\d{4}-\d\d-\d\dT[\d:.]+ I app: hello$'));
      expect(lines[1], contains(' W store: odd'));
      expect(lines[2], contains(' E save: failed'));
    });

    test('a run is written to the app storage', () async {
      final log = AppLog(files: files);
      await log.start(version: '9.9.9');
      log.i('x', 'one');
      await log.flush();
      final text = utf8.decode(files.logs[AppLog.currentFile]!);
      expect(text, contains('start, version 9.9.9'));
      expect(text, contains('x: one'));
    });

    test('the next start moves the last run into the history', () async {
      final first = AppLog(files: files);
      await first.start(version: '1.0.0');
      first.i('x', 'from the first run');
      await first.flush();

      final second = AppLog(files: files);
      await second.start(version: '2.0.0');
      expect(second.session, isNot(contains('first run')));
      expect(second.all, contains('from the first run'));
      expect(second.all, contains('start, version 2.0.0'));
      expect(
        utf8.decode(files.logs[AppLog.historyFile]!),
        contains('from the first run'),
      );
    });

    test('the history keeps only the newest part, whole lines', () async {
      final big =
          '${List.generate(20000, (i) => 'old line number $i').join('\n')}\n';
      files.logs[AppLog.historyFile] = Uint8List.fromList(utf8.encode(big));
      final log = AppLog(files: files);
      await log.start(version: '1');
      final kept = utf8.decode(files.logs[AppLog.historyFile]!);
      expect(kept.length, lessThanOrEqualTo(AppLog.historyCap));
      expect(kept, contains('old line number 19999'));
      expect(kept, isNot(contains('old line number 0\n')));
      expect(
        kept.startsWith('old line number'),
        isTrue,
        reason: 'a whole line first',
      );
    });

    test('one run keeps the newest lines and says how many were left out', () {
      final log = AppLog(files: files);
      for (var i = 0; i < AppLog.maxLines + 10; i++) {
        log.i('x', 'line $i');
      }
      expect(log.length, AppLog.maxLines);
      expect(log.session, contains('10 earlier lines of this run left out'));
      expect(log.session, isNot(contains('x: line 0\n')));
      expect(log.session, contains('line ${AppLog.maxLines + 9}'));
    });

    test(
      'an export is a text file in downloads, this run or everything',
      () async {
        final first = AppLog(files: files);
        await first.start(version: '1');
        first.i('x', 'old');
        await first.flush();
        final log = AppLog(files: files);
        await log.start(version: '2');
        log.i('x', 'new');

        final run = await log.export(now: DateTime(2026, 10, 25, 13, 5));
        expect(run, 'lexodle-log-run-2026-10-25T1305.txt');
        expect(files.downloadMimes[run], 'text/plain');
        final runText = utf8.decode(files.downloads[run]!);
        expect(runText, contains('x: new'));
        expect(runText, isNot(contains('x: old')));

        final all = await log.export(
          everything: true,
          now: DateTime(2026, 10, 25, 13, 5),
        );
        expect(all, 'lexodle-log-all-2026-10-25T1305.txt');
        expect(utf8.decode(files.downloads[all]!), contains('x: old'));
      },
    );

    test('a log that cannot be written does not throw', () async {
      files.logFails = true;
      final log = AppLog(files: files);
      await log.start(version: '1');
      log.e('x', 'still fine');
      await log.flush();
      expect(log.session, contains('still fine'));
    });

    test('an export that cannot be saved says so in the log', () async {
      files.downloadsFails = true;
      final log = AppLog(files: files);
      expect(await log.export(), isNull);
      expect(log.session, contains('could not export the log'));
    });
  });

  group('what the app records', () {
    test('a save that works is not counted as a failure', () async {
      final s = AppState();
      await s.load();
      s.setHaptics(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(s.saveFailures, 0);
    });

    test('with no store at all, a save is counted and logged', () async {
      final s = AppState(); // never loaded: there is no store to save to
      s.setHaptics(false);
      expect(s.saveFailures, 1);
      expect(
        appLog.session,
        contains('was not saved: storage is not available'),
      );
    });

    test('the load says what it found', () async {
      final s = AppState();
      await s.load();
      expect(appLog.session, contains('load ends:'));
      expect(appLog.session, contains('rows skipped'));
    });

    test('a backup run is logged', () async {
      final s = AppState();
      await s.load();
      await AutoBackup.run(s, downloads: true, label: 'manual');
      expect(appLog.session, contains('manual backup'));
    });
  });

  group('in the settings', () {
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 3200));
      await appState.load();
      await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('the log section shows its size and exports to downloads', (
      tester,
    ) async {
      await open(tester);
      final summary = find.byKey(const ValueKey('log-summary'));
      await tester.ensureVisible(summary);
      expect(summary, findsOneWidget);
      final btn = find.byKey(const ValueKey('log-export-run'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(
        files.downloads.keys.where((k) => k.startsWith('lexodle-log-run')),
        hasLength(1),
      );
      expect(
        find.textContaining('saved to downloads: lexodle-log-run'),
        findsOneWidget,
      );
    });

    testWidgets('export everything, and the view of this run', (tester) async {
      await open(tester);
      final all = find.byKey(const ValueKey('log-export-all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(
        files.downloads.keys.where((k) => k.startsWith('lexodle-log-all')),
        hasLength(1),
      );

      final view = find.byKey(const ValueKey('log-view'));
      await tester.ensureVisible(view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('log-text')), findsOneWidget);
    });

    testWidgets('where downloads cannot be written it says so', (tester) async {
      files.downloadsSupported = false;
      await open(tester);
      final btn = find.byKey(const ValueKey('log-export-run'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.textContaining('could not save the log'), findsOneWidget);
    });
  });
}
