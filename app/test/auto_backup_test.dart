import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/auto_backup.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/update_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backup_files.dart';

GameResult _won() => const GameResult(
  lang: 'en',
  length: 5,
  tries: 6,
  pool: 3000,
  used: 3,
  won: true,
  skills: [90, 90, 90],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackupFiles files;
  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    files = FakeBackupFiles();
    AutoBackup.files = files;
  });
  tearDown(() => AutoBackup.files = const PlatformBackupFiles());

  group('the name', () {
    test('says what it is for, the version and the minute', () {
      expect(
        AutoBackup.nameFor('update', DateTime(2026, 10, 25, 9, 5)),
        'lexodle-backup-update-v$appVersion-2026-10-25-0905.json',
      );
    });
  });

  group('a run', () {
    test('saves the same backup the settings would download', () async {
      final s = AppState();
      await s.load();
      s.recordGame(_won());
      final r = await AutoBackup.run(s, downloads: true);
      expect(r.internal && r.downloads, isTrue);
      expect(r.any, isTrue);
      expect(r.where, 'app memory and downloads');
      final b = parseBackup(utf8.decode(files.internal[r.name]!));
      expect(b.stats.played, 1);
      expect(files.downloads[r.name], files.internal[r.name]);
    });

    test('keeps only the newest five in the app', () async {
      final s = AppState();
      await s.load();
      for (var i = 0; i < 8; i++) {
        await AutoBackup.run(
          s,
          downloads: false,
          now: DateTime(2026, 10, 25, 9, i),
        );
      }
      final kept = await files.listInternal();
      expect(kept, hasLength(AutoBackup.keep));
      expect(kept.first, contains('0907'), reason: 'newest first');
      expect(files.deleted, hasLength(3));
    });

    test('the latest one reads back', () async {
      final s = AppState();
      await s.load();
      expect(await AutoBackup.latest(), isNull);
      s.recordGame(_won());
      final r = await AutoBackup.run(s, downloads: false);
      final latest = await AutoBackup.latest();
      expect(latest!.name, r.name);
      expect(parseBackup(latest.text).stats.played, 1);
    });

    test('with nothing working it says so and throws nothing', () async {
      files.internalFails = true;
      files.downloadsFails = true;
      final s = AppState();
      await s.load();
      final r = await AutoBackup.run(s, downloads: true);
      expect(r.any, isFalse);
    });
  });

  group('the first start of a new version', () {
    test('keeps a copy of what it found, once', () async {
      final s = AppState();
      await s.load();
      s.recordGame(_won());
      s.lastRunVersion = '0.0.1';
      await AutoBackup.afterUpgrade(s);
      expect(files.internal.keys.single, contains('after-update'));
      expect(files.downloads, isEmpty, reason: 'the app only');
      expect(s.lastRunVersion, appVersion);
      await AutoBackup.afterUpgrade(s);
      expect(
        files.internal,
        hasLength(1),
        reason: 'not again on the same version',
      );
    });

    test('a first install, with nothing yet, keeps nothing', () async {
      final s = AppState();
      await s.load();
      await AutoBackup.afterUpgrade(s);
      expect(files.internal, isEmpty);
      expect(s.lastRunVersion, appVersion, reason: 'but it is noted');
    });

    test('the version is remembered between runs', () async {
      final s = AppState();
      await s.load();
      s.noteRunVersion('9.9.9');
      final again = AppState();
      await again.load();
      expect(again.lastRunVersion, '9.9.9');
    });
  });

  group('in the settings', () {
    Future<AppState> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2200));
      await appState.load();
      await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
      await tester.pumpAndSettle();
      return appState;
    }

    testWidgets('a button saves a backup to downloads at once', (tester) async {
      await open(tester);
      final btn = find.byKey(const ValueKey('backup-downloads'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(files.downloads, hasLength(1));
      expect(files.downloads.keys.single, contains('manual'));
      expect(find.textContaining('saved to downloads'), findsOneWidget);
    });

    testWidgets(
      'where downloads cannot be written it says so, and keeps a copy',
      (tester) async {
        files.downloadsSupported = false;
        await open(tester);
        final btn = find.byKey(const ValueKey('backup-downloads'));
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await tester.pumpAndSettle();
        expect(files.downloads, isEmpty);
        expect(files.internal, hasLength(1));
        expect(
          find.textContaining('could not save to downloads'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the latest automatic backup is named and can be restored', (
      tester,
    ) async {
      // a backup of a player with one game, made earlier
      final before = AppState();
      await before.load();
      before.recordGame(_won());
      await AutoBackup.run(before, downloads: false, label: 'update');

      await open(tester);
      // what is here now is a different, empty progress
      appState.stats = Stats();
      appState.history.games.clear();
      final name = find.byKey(const ValueKey('backup-auto-name'));
      await tester.ensureVisible(name);
      expect(name, findsOneWidget);
      final restore = find.byKey(const ValueKey('backup-restore-auto'));
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backup-summary')), findsOneWidget);
      final confirm = find.byKey(const ValueKey('backup-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(appState.stats.played, 1);
    });

    testWidgets('no automatic backup yet, no restore button', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('backup-restore-auto')), findsNothing);
    });
  });
}
