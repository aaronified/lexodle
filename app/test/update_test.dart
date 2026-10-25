import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/apk_install.dart';
import 'package:lexodle/auto_backup.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/update_check.dart';
import 'package:lexodle/update_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backup_files.dart';

Map<String, dynamic> release(
  String tag, {
  bool apk = true,
  String? digest,
  String name = 'lexodle-v9.9.9.apk',
}) => {
  'tag_name': tag,
  'assets': [
    if (apk)
      {
        'name': name,
        'browser_download_url': 'https://example.test/$name',
        'digest': ?digest,
      },
  ],
};

const _sha = 'ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // the one app state is shared by every test of the file
    appState
      ..autoUpdateCheck = false
      ..lastUpdateCheck = null
      ..latestRelease = null;
  });

  group('versions', () {
    test('are dotted numbers, with or without a v', () {
      expect(parseVersion('v0.1.2'), [0, 1, 2]);
      expect(parseVersion('1.10'), [1, 10]);
      expect(parseVersion('v'), isNull);
      expect(parseVersion('1.x'), isNull);
      expect(parseVersion('-1.0'), isNull);
    });

    test('compare number by number, a missing number counting as 0', () {
      expect(isNewer('0.1.2', '0.1.1'), isTrue);
      expect(isNewer('0.2.0', '0.1.9'), isTrue);
      expect(isNewer('0.10.0', '0.9.0'), isTrue, reason: 'not as text');
      expect(isNewer('1.0', '0.9.9'), isTrue);
      expect(isNewer('0.1.1', '0.1.1'), isFalse);
      expect(isNewer('1.0', '1.0.0'), isFalse);
      expect(isNewer('0.1.0', '0.1.1'), isFalse);
      expect(isNewer('nonsense', '0.1.1'), isFalse);
    });

    test('the version of the build is the one in pubspec.yaml', () {
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      expect(line, contains(appVersion));
    });
  });

  group('reading the latest release', () {
    test('a newer one with its APK is offered, with the checksum', () {
      final r = readRelease(
        release('v9.9.9', digest: 'sha256:${_sha.toUpperCase()}'),
      );
      expect(r, isA<UpdateAvailable>());
      final info = (r as UpdateAvailable).release;
      expect(info.version, '9.9.9');
      expect(info.apkUrl, 'https://example.test/lexodle-v9.9.9.apk');
      expect(info.sha256, _sha);
    });

    test('a digest that is not a SHA-256 is not passed on', () {
      for (final d in ['md5:abc', 'sha256:xyz', 'sha256:${_sha}00']) {
        final r = readRelease(release('v9.9.9', digest: d));
        expect((r as UpdateAvailable).release.sha256, isNull, reason: d);
      }
      final none = readRelease(release('v9.9.9')) as UpdateAvailable;
      expect(none.release.sha256, isNull);
    });

    test('the same or an older version is up to date', () {
      expect(readRelease(release('v$appVersion')), isA<UpToDate>());
      expect(readRelease(release('v0.0.1')), isA<UpToDate>());
    });

    test('a newer release without its APK reads as up to date', () {
      expect(readRelease(release('v9.9.9', apk: false)), isA<UpToDate>());
      expect(
        readRelease(release('v9.9.9', name: 'notes.txt')),
        isA<UpToDate>(),
      );
    });

    test('a reply that cannot be read is a bad reply', () {
      for (final j in [
        null,
        5,
        <String, dynamic>{},
        {'tag_name': 7},
        {'tag_name': 'soon'},
      ]) {
        final r = readRelease(j);
        expect(r, isA<CheckFailed>(), reason: '$j');
        expect((r as CheckFailed).why, CheckFailure.badReply);
      }
    });
  });

  group('asking GitHub', () {
    Future<CheckResult> ask(http.Response Function(http.Request) answer) =>
        GitHubReleaseCheck(client: MockClient((r) async => answer(r))).check();

    test('asks the latest release of this repository, as lexodle', () async {
      http.Request? seen;
      final r = await ask((req) {
        seen = req;
        return http.Response(jsonEncode(release('v9.9.9')), 200);
      });
      expect(r, isA<UpdateAvailable>());
      expect(
        seen!.url.toString(),
        'https://api.github.com/repos/aaronified/lexodle/releases/latest',
      );
      expect(seen!.headers['User-Agent'], 'lexodle/$appVersion');
    });

    test('403 and 429 are the rate limit, other errors a bad reply', () async {
      for (final code in [403, 429]) {
        final r = await ask((_) => http.Response('', code));
        expect((r as CheckFailed).why, CheckFailure.rateLimited);
      }
      final bad = await ask((_) => http.Response('', 500));
      expect((bad as CheckFailed).why, CheckFailure.badReply);
      final junk = await ask((_) => http.Response('not json', 200));
      expect((junk as CheckFailed).why, CheckFailure.badReply);
    });

    test('no network is offline', () async {
      final r = await GitHubReleaseCheck(
        client: MockClient((_) async => throw const SocketException('no')),
      ).check();
      expect((r as CheckFailed).why, CheckFailure.offline);
    });
  });

  group('the controller', () {
    final info = const ReleaseInfo(
      version: '9.9.9',
      apkUrl: 'https://example.test/lexodle-v9.9.9.apk',
      apkName: 'lexodle-v9.9.9.apk',
      sha256: _sha,
    );

    test('finds an update, then downloads and installs it', () async {
      await appState.load();
      final installer = FixedApkInstaller(const [
        InstallEvent.downloading(10),
        InstallEvent.downloading(80),
        InstallEvent.installing(),
      ]);
      final c = UpdateController(
        check: FixedReleaseCheck(UpdateAvailable(info)),
        installer: installer,
      );
      await c.checkNow();
      expect(c.step, UpdateStep.available);
      expect(appState.latestRelease, '9.9.9');
      await c.update();
      expect(c.step, UpdateStep.installing);
      expect(installer.asked.single.url, info.apkUrl);
      expect(installer.asked.single.fileName, 'lexodle-v9.9.9.apk');
      expect(installer.asked.single.sha256, _sha, reason: 'checked');
    });

    test(
      'an update checks again first, for the newest and its checksum',
      () async {
        await appState.load();
        final check = FixedReleaseCheck(UpdateAvailable(info));
        final c = UpdateController(
          check: check,
          installer: FixedApkInstaller(const [InstallEvent.installing()]),
        );
        await c.update();
        expect(check.asked, 1);
      },
    );

    test('nothing newer means nothing is downloaded', () async {
      await appState.load();
      final installer = FixedApkInstaller(const [InstallEvent.installing()]);
      final c = UpdateController(
        check: FixedReleaseCheck(const UpToDate()),
        installer: installer,
      );
      await c.update();
      expect(c.step, UpdateStep.upToDate);
      expect(installer.asked, isEmpty);
      expect(appState.latestRelease, isNull);
    });

    test('a failed install says why, and can be tried again', () async {
      await appState.load();
      final installer = FixedApkInstaller(const [
        InstallEvent.downloading(5),
        InstallEvent.failed(InstallFailure.checksum),
      ]);
      final c = UpdateController(
        check: FixedReleaseCheck(UpdateAvailable(info)),
        installer: installer,
      );
      await c.update();
      expect(c.step, UpdateStep.available);
      expect(c.installFailure, InstallFailure.checksum);
      installer.events = const [InstallEvent.installing()];
      await c.update();
      expect(c.installFailure, isNull);
      expect(c.step, UpdateStep.installing);
    });

    test('cancelling a download is not a failure', () async {
      await appState.load();
      final gate = Completer();
      final installer = FixedApkInstaller(const [
        InstallEvent.downloading(30),
        InstallEvent.installing(),
      ], gate: gate);
      final c = UpdateController(
        check: FixedReleaseCheck(UpdateAvailable(info)),
        installer: installer,
      );
      final running = c.update();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.step, UpdateStep.downloading);
      expect(c.percent, 30);
      await c.cancel();
      await running;
      expect(c.step, UpdateStep.available);
      expect(c.installFailure, isNull);
      expect(installer.cancels, 1);
    });

    test('a check that could not reach GitHub is not remembered', () async {
      await appState.load();
      final before = appState.lastUpdateCheck;
      final c = UpdateController(
        check: FixedReleaseCheck(const CheckFailed(CheckFailure.offline)),
        installer: const NullApkInstaller(),
      );
      await c.checkNow();
      expect(c.checkFailure, CheckFailure.offline);
      expect(appState.lastUpdateCheck, before);
    });
  });

  group('checking by itself', () {
    final found = UpdateAvailable(
      const ReleaseInfo(
        version: '9.9.9',
        apkUrl: 'u',
        apkName: 'lexodle-v9.9.9.apk',
      ),
    );

    test('is off until chosen', () async {
      await appState.load();
      expect(appState.autoUpdateCheck, isFalse);
      final check = FixedReleaseCheck(found);
      await checkForUpdateAtLaunch(check: check, supported: true);
      expect(check.asked, 0);
    });

    test(
      'once on, checks at most once a day, and remembers what it found',
      () async {
        await appState.load();
        appState.setAutoUpdateCheck(true);
        final check = FixedReleaseCheck(found);
        await checkForUpdateAtLaunch(check: check, supported: true);
        expect(check.asked, 1);
        expect(appState.latestRelease, '9.9.9');
        await checkForUpdateAtLaunch(check: check, supported: true);
        expect(check.asked, 1, reason: 'under a day later');
        await checkForUpdateAtLaunch(
          check: check,
          supported: true,
          now: DateTime.now().add(const Duration(hours: 25)),
        );
        expect(check.asked, 2);
      },
    );

    test('a failed check does not count, so the next launch tries', () async {
      await appState.load();
      appState.setAutoUpdateCheck(true);
      final check = FixedReleaseCheck(const CheckFailed(CheckFailure.offline));
      await checkForUpdateAtLaunch(check: check, supported: true);
      await checkForUpdateAtLaunch(check: check, supported: true);
      expect(check.asked, 2);
    });

    test('does nothing where nothing can be installed', () async {
      await appState.load();
      appState.setAutoUpdateCheck(true);
      final check = FixedReleaseCheck(found);
      await checkForUpdateAtLaunch(check: check, supported: false);
      expect(check.asked, 0);
    });

    test('the switch and the last answer are kept', () async {
      await appState.load();
      appState.setAutoUpdateCheck(true);
      appState.noteUpdateCheck(latest: '9.9.9');
      final again = AppState();
      await again.load();
      expect(again.autoUpdateCheck, isTrue);
      expect(again.latestRelease, '9.9.9');
      expect(again.lastUpdateCheck, isNotNull);
    });
  });

  group('the settings row', () {
    Future<void> show(WidgetTester tester, UpdateController c) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await appState.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: UpdateSection(controller: c)),
          ),
        ),
      );
    }

    final info = const ReleaseInfo(
      version: '9.9.9',
      apkUrl: 'u',
      apkName: 'lexodle-v9.9.9.apk',
    );

    testWidgets('says the version; check says up to date; no update button', (
      tester,
    ) async {
      final c = UpdateController(
        check: FixedReleaseCheck(const UpToDate()),
        installer: const NullApkInstaller(),
      );
      await show(tester, c);
      expect(find.text('version $appVersion'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-install')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text('lexodle is up to date'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-install')), findsNothing);
    });

    testWidgets('a newer version shows its number and an update button', (
      tester,
    ) async {
      final installer = FixedApkInstaller(const [InstallEvent.installing()]);
      final c = UpdateController(
        check: FixedReleaseCheck(UpdateAvailable(info)),
        installer: installer,
      );
      await show(tester, c);
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text('version 9.9.9 is available'), findsOneWidget);
      AutoBackup.files = FakeBackupFiles();
      addTearDown(() => AutoBackup.files = const PlatformBackupFiles());
      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pumpAndSettle();
      expect(installer.asked, hasLength(1));
      expect(find.textContaining('Android is installing'), findsOneWidget);
    });

    testWidgets('an offline check says so', (tester) async {
      final c = UpdateController(
        check: FixedReleaseCheck(const CheckFailed(CheckFailure.offline)),
        installer: const NullApkInstaller(),
      );
      await show(tester, c);
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('could not reach GitHub'), findsOneWidget);
    });

    testWidgets('the switch turns automatic checking on', (tester) async {
      final c = UpdateController(
        check: FixedReleaseCheck(const UpToDate()),
        installer: const NullApkInstaller(),
      );
      await show(tester, c);
      expect(appState.autoUpdateCheck, isFalse);
      await tester.tap(find.byKey(const ValueKey('update-auto')));
      await tester.pump();
      expect(appState.autoUpdateCheck, isTrue);
    });

    group('the backup made by itself before it installs', () {
      late FakeBackupFiles files;
      setUp(() {
        files = FakeBackupFiles();
        AutoBackup.files = files;
        appState.downloadsBackup = true;
      });
      tearDown(() => AutoBackup.files = const PlatformBackupFiles());

      Future<FixedApkInstaller> ready(WidgetTester tester) async {
        final installer = FixedApkInstaller(const [InstallEvent.installing()]);
        final c = UpdateController(
          check: FixedReleaseCheck(UpdateAvailable(info)),
          installer: installer,
        );
        await show(tester, c);
        await tester.tap(find.byKey(const ValueKey('update-check')));
        await tester.pump();
        await tester.pump();
        return installer;
      }

      Future<void> update(WidgetTester tester) async {
        await tester.tap(find.byKey(const ValueKey('update-install')));
        await tester.pumpAndSettle();
      }

      testWidgets('saves to the app and to downloads, then installs', (
        tester,
      ) async {
        final installer = await ready(tester);
        await update(tester);
        expect(files.internal, hasLength(1));
        expect(files.downloads, hasLength(1));
        expect(files.downloads.keys.single, files.internal.keys.single);
        expect(
          files.internal.keys.single,
          startsWith('lexodle-backup-update-v'),
        );
        expect(installer.asked, hasLength(1));
        expect(
          find.textContaining('backup saved to app memory and downloads'),
          findsOneWidget,
        );
      });

      testWidgets('with downloads switched off it saves to the app only', (
        tester,
      ) async {
        final installer = await ready(tester);
        appState.downloadsBackup =
            false; // (opening the page loaded the settings)
        await update(tester);
        expect(files.internal, hasLength(1));
        expect(files.downloads, isEmpty);
        expect(installer.asked, hasLength(1));
        expect(
          find.textContaining('backup saved to app memory:'),
          findsOneWidget,
        );
      });

      testWidgets('the copy is a backup that reads back', (tester) async {
        await ready(tester);
        await update(tester);
        final b = parseBackup(utf8.decode(files.internal.values.single));
        expect(b.settings, isNotEmpty);
      });

      testWidgets('one place failing does not stop the other or the update', (
        tester,
      ) async {
        files.downloadsFails = true;
        final installer = await ready(tester);
        await update(tester);
        expect(files.internal, hasLength(1));
        expect(installer.asked, hasLength(1));
        expect(
          find.textContaining('backup saved to app memory:'),
          findsOneWidget,
        );
      });

      testWidgets('downloads not possible on this phone is not an error', (
        tester,
      ) async {
        files.downloadsSupported = false;
        final installer = await ready(tester);
        await update(tester);
        expect(installer.asked, hasLength(1));
        expect(find.textContaining('app memory:'), findsOneWidget);
      });

      testWidgets('no backup at all stops it, and a second press goes ahead', (
        tester,
      ) async {
        files.internalFails = true;
        files.downloadsFails = true;
        final installer = await ready(tester);
        await update(tester);
        expect(installer.asked, isEmpty, reason: 'nothing installed yet');
        expect(find.textContaining('no backup saved'), findsOneWidget);
        await update(tester);
        expect(installer.asked, hasLength(1), reason: 'the player went ahead');
      });

      testWidgets('the settings have the downloads switch, and it is kept', (
        tester,
      ) async {
        await ready(tester);
        final sw = find.byKey(const ValueKey('update-downloads-backup'));
        expect(sw, findsOneWidget);
        await tester.tap(sw);
        await tester.pump();
        expect(appState.downloadsBackup, isFalse);
        final again = AppState();
        await again.load();
        expect(again.downloadsBackup, isFalse);
      });
    });
  });
}
