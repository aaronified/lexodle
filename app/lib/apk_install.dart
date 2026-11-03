import 'dart:async';

import 'apk_install_stub.dart'
    if (dart.library.io) 'apk_install_ota.dart'
    as platform;

/// Why an update did not reach Android's installer.
enum InstallFailure {
  /// Lexodle has not been allowed to install apps ("Install unknown apps").
  notAllowed,

  /// No network, no file at GitHub, or the download stalled.
  download,

  /// The download did not match the checksum GitHub gave.
  checksum,

  /// Android did not start installing it, or another install was running.
  install,

  /// Anything else that went wrong on the phone.
  internal,

  /// Stopped by the player: not a failure to report.
  cancelled,
}

/// One step of an update: how much has downloaded, Android's installer opening,
/// or why it stopped.
class InstallEvent {
  const InstallEvent.downloading(int this.percent)
    : installing = false,
      failure = null;
  const InstallEvent.installing()
    : percent = null,
      installing = true,
      failure = null;
  const InstallEvent.failed(InstallFailure this.failure)
    : percent = null,
      installing = false;

  final int? percent;

  /// Android's installer has been opened on the file. What the player does
  /// there is not reported back.
  final bool installing;
  final InstallFailure? failure;
}

/// Downloads an APK into the app's own storage (no storage permission) and
/// opens Android's installer on it. Narrow enough that tests fake it.
abstract interface class ApkInstaller {
  /// Downloads [url] as [fileName], checks [sha256] if given, and opens the
  /// installer. The stream ends after [InstallEvent.installing] or a failure,
  /// and never throws.
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  });

  /// The size and SHA-256 of the file kept as [fileName] by an earlier
  /// [install], or null when there is none.
  Future<({int size, String? sha256})?> kept(String fileName);

  /// Opens the installer on [fileName], already in the app's own storage from
  /// an earlier [install], with no download: what an update does after the
  /// player closed Android's installer. The stream ends after
  /// [InstallEvent.installing] or a failure, and never throws.
  Stream<InstallEvent> installFile(String fileName);

  /// Stops the download under way; its stream ends with
  /// [InstallFailure.cancelled].
  Future<void> cancel();
}

/// The installer for this platform: ota_update on Android, none elsewhere (the
/// web build, tests), where every install fails.
ApkInstaller platformInstaller() => platform.create();

/// No installer: every install fails.
class NullApkInstaller implements ApkInstaller {
  const NullApkInstaller();

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) => Stream<InstallEvent>.value(
    const InstallEvent.failed(InstallFailure.internal),
  );

  @override
  Future<({int size, String? sha256})?> kept(String fileName) async => null;

  @override
  Stream<InstallEvent> installFile(String fileName) =>
      Stream<InstallEvent>.value(
        const InstallEvent.failed(InstallFailure.internal),
      );

  @override
  Future<void> cancel() async {}
}

/// An installer that reports [events], for tests. With a [gate], an install
/// waits on it after the first event so that a step can be seen; one that is
/// never completed is a download that stalls until [cancel].
class FixedApkInstaller implements ApkInstaller {
  FixedApkInstaller(this.events, {this.gate});

  List<InstallEvent> events;
  Completer<void>? gate;

  /// Every install asked for: its url, file name and checksum.
  final asked = <({String url, String fileName, String? sha256})>[];

  /// What [kept] says, set by a test (a download is kept once [events] end in
  /// the installer opening, with this size and checksum).
  ({int size, String? sha256})? keptFile;

  /// Every file the installer was opened on again, with no download.
  final reopened = <String>[];
  int cancels = 0;
  Completer<void>? _cancelled;

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) async* {
    asked.add((url: url, fileName: fileName, sha256: sha256));
    final cancelled = _cancelled = Completer<void>();
    final wait = gate;
    for (final (i, event) in events.indexed) {
      yield event;
      if (i == 0 && wait != null) {
        await Future.any(<Future<void>>[wait.future, cancelled.future]);
      }
      if (cancelled.isCompleted) {
        yield const InstallEvent.failed(InstallFailure.cancelled);
        return;
      }
    }
  }

  @override
  Future<({int size, String? sha256})?> kept(String fileName) async => keptFile;

  @override
  Stream<InstallEvent> installFile(String fileName) async* {
    reopened.add(fileName);
    yield const InstallEvent.installing();
  }

  @override
  Future<void> cancel() async {
    cancels++;
    final c = _cancelled;
    if (c != null && !c.isCompleted) c.complete();
  }
}
