import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'apk_install.dart';
import 'main.dart';
import 'ui.dart';
import 'update_check.dart';

/// Whether this build can update itself: an installed Android app (the web page
/// is always the latest, and nothing else installs an APK).
bool get updatesSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// How long since the last automatic check before another may run.
const autoCheckEvery = Duration(hours: 24);

/// When the player has switched on automatic checks, looks for a newer version
/// as the app opens, at most once a day. What it finds is kept, so the settings
/// say so without asking again.
Future<void> checkForUpdateAtLaunch({
  ReleaseCheck? check,
  bool? supported,
  DateTime? now,
}) async {
  if (!(supported ?? updatesSupported) || !appState.autoUpdateCheck) return;
  final last = appState.lastUpdateCheck;
  if (last != null &&
      (now ?? DateTime.now()).difference(last) < autoCheckEvery) {
    return;
  }
  final r = await (check ?? GitHubReleaseCheck()).check();
  switch (r) {
    case UpdateAvailable(release: final found):
      appState.noteUpdateCheck(latest: found.version);
    case UpToDate():
      appState.noteUpdateCheck(latest: null);
    case CheckFailed():
      break; // not counted: the next launch tries again
  }
}

/// Where an update stands.
enum UpdateStep { idle, checking, upToDate, available, downloading, installing }

/// Checks GitHub for a newer release, and downloads and installs it. Pure
/// enough to test: the check and the installer are given.
class UpdateController extends ChangeNotifier {
  UpdateController({ReleaseCheck? check, ApkInstaller? installer})
    : _check = check ?? GitHubReleaseCheck(),
      _installer = installer ?? platformInstaller();

  final ReleaseCheck _check;
  final ApkInstaller _installer;

  UpdateStep step = UpdateStep.idle;
  ReleaseInfo? release;
  CheckFailure? checkFailure;
  InstallFailure? installFailure;

  /// How much of the download is done, 0 to 100.
  int percent = 0;

  StreamSubscription<InstallEvent>? _installing;

  /// Looks for a newer version. A check that reached GitHub is remembered (so
  /// an automatic one waits a day); one that could not is not.
  Future<void> checkNow() async {
    if (step == UpdateStep.checking ||
        step == UpdateStep.downloading ||
        step == UpdateStep.installing) {
      return;
    }
    step = UpdateStep.checking;
    checkFailure = null;
    installFailure = null;
    notifyListeners();
    final r = await _check.check();
    switch (r) {
      case UpdateAvailable(release: final found):
        release = found;
        step = UpdateStep.available;
        appState.noteUpdateCheck(latest: found.version);
      case UpToDate():
        release = null;
        step = UpdateStep.upToDate;
        appState.noteUpdateCheck(latest: null);
      case CheckFailed(why: final why):
        checkFailure = why;
        step = release == null ? UpdateStep.idle : UpdateStep.available;
        // only a check that got an answer counts (a failed one is tried again)
        if (why == CheckFailure.badReply || why == CheckFailure.rateLimited) {
          appState.noteUpdateCheck(latest: release?.version);
        }
    }
    notifyListeners();
  }

  /// Checks again (for the newest version and its checksum), then downloads.
  Future<void> update() async {
    if (step == UpdateStep.downloading || step == UpdateStep.installing) return;
    await checkNow();
    final r = release;
    if (step != UpdateStep.available || r == null) return;
    step = UpdateStep.downloading;
    percent = 0;
    installFailure = null;
    notifyListeners();
    final done = Completer<void>();
    _installing = _installer
        .install(r.apkUrl, fileName: r.apkName, sha256: r.sha256)
        .listen(
          (e) {
            if (e.failure != null) {
              installFailure = e.failure == InstallFailure.cancelled
                  ? null
                  : e.failure;
              step = UpdateStep.available;
            } else if (e.installing) {
              step = UpdateStep.installing;
            } else {
              percent = e.percent ?? percent;
            }
            notifyListeners();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
    _installing = null;
  }

  Future<void> cancel() async {
    if (step != UpdateStep.downloading) return;
    await _installer.cancel();
  }

  @override
  void dispose() {
    unawaited(_installing?.cancel());
    super.dispose();
  }
}

String _checkMessage(CheckFailure f) => switch (f) {
  CheckFailure.offline => 'could not reach GitHub. check the connection',
  CheckFailure.rateLimited => 'GitHub is limiting requests. try again later',
  CheckFailure.badReply => 'GitHub gave an answer that could not be read',
};

String _installMessage(InstallFailure f) => switch (f) {
  InstallFailure.notAllowed =>
    'Android has not allowed lexodle to install apps. turn on '
        '"Install unknown apps" for it, then try again',
  InstallFailure.download => 'the download failed. try again',
  InstallFailure.checksum =>
    'the download did not match its checksum, so it was not installed',
  InstallFailure.install => 'Android could not start the install',
  InstallFailure.internal => 'something went wrong on the phone',
  InstallFailure.cancelled => '',
};

/// The update row of the settings: the version, a button to check, and when a
/// newer one is found, a button to download and install it. A switch makes the
/// app check by itself, once a day at most; it is off until chosen, since each
/// check is a request to GitHub.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key, this.controller});

  /// Given by a test; the app makes its own.
  final UpdateController? controller;

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  late final UpdateController _c = widget.controller ?? UpdateController();

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([_c, appState]),
      builder: (context, _) {
        final r = _c.release;
        final newer =
            r?.version ??
            (isNewer(appState.latestRelease ?? '', appVersion)
                ? appState.latestRelease
                : null);
        final busy =
            _c.step == UpdateStep.checking ||
            _c.step == UpdateStep.downloading ||
            _c.step == UpdateStep.installing;
        final message = _c.installFailure != null
            ? _installMessage(_c.installFailure!)
            : _c.checkFailure != null
            ? _checkMessage(_c.checkFailure!)
            : switch (_c.step) {
                UpdateStep.checking => 'checking…',
                UpdateStep.upToDate => 'lexodle is up to date',
                UpdateStep.downloading => 'downloading… ${_c.percent}%',
                UpdateStep.installing =>
                  'Android is installing it. confirm there',
                _ when newer != null => 'version $newer is available',
                _ => '',
              };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('version $appVersion', key: const ValueKey('app-version')),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                key: const ValueKey('update-message'),
                style: _c.installFailure != null || _c.checkFailure != null
                    ? TextStyle(color: c.error, fontSize: 12)
                    : dim,
              ),
            ],
            if (_c.step == UpdateStep.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _c.percent / 100),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _c.step == UpdateStep.downloading
                      ? OutlinedButton(
                          key: const ValueKey('update-cancel'),
                          onPressed: _c.cancel,
                          child: const Text('cancel'),
                        )
                      : OutlinedButton(
                          key: const ValueKey('update-check'),
                          onPressed: busy ? null : _c.checkNow,
                          child: const Text('check for updates'),
                        ),
                ),
                if (newer != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('update-install'),
                      onPressed: busy ? null : _c.update,
                      child: Text(
                        _c.installFailure != null ? 'try again' : 'update',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const ValueKey('update-auto'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('check automatically'),
              subtitle: Text(
                'once a day, when the app opens. off by default: each check '
                'is a request to GitHub',
                style: dim.copyWith(fontSize: 11),
              ),
              value: appState.autoUpdateCheck,
              onChanged: appState.setAutoUpdateCheck,
            ),
          ],
        );
      },
    );
  }
}
