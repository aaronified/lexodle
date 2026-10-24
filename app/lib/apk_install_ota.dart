import 'dart:async';

import 'package:ota_update/ota_update.dart';

import 'apk_install.dart';

/// [ApkInstaller] through ota_update. It downloads into
/// `files/ota_update/<fileName>` in the app's own storage, which needs no
/// storage permission, and opens Android's installer on it through a
/// FileProvider (declared in AndroidManifest.xml).
///
/// ota_update's stream can go quiet without ending: 7.1.0 drops a download the
/// server resets without a status and leaves the stream open. So a download that
/// says nothing for [stall] has failed.
ApkInstaller create() => OtaApkInstaller();

class OtaApkInstaller implements ApkInstaller {
  OtaApkInstaller({this.stall = const Duration(seconds: 60)});

  final Duration stall;
  void Function()? _cancel;

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) {
    final out = StreamController<InstallEvent>();
    StreamSubscription<OtaEvent>? listening;
    Timer? watchdog;
    void end([InstallEvent? last]) {
      if (out.isClosed) return;
      watchdog?.cancel();
      unawaited(listening?.cancel());
      _cancel = null;
      if (last != null) out.add(last);
      unawaited(out.close());
    }

    void watch() {
      watchdog?.cancel();
      watchdog = Timer(stall, () {
        unawaited(_stopPlugin());
        end(const InstallEvent.failed(InstallFailure.download));
      });
    }

    _cancel = () => end(const InstallEvent.failed(InstallFailure.cancelled));
    try {
      final events = OtaUpdate().execute(
        url,
        destinationFilename: fileName,
        sha256checksum: sha256,
      );
      watch();
      listening = events.listen(
        (event) {
          final next = _eventOf(event);
          if (next == null) return;
          if (next.installing || next.failure != null) {
            end(next);
          } else {
            out.add(next);
            watch();
          }
        },
        onError: (Object _) =>
            end(const InstallEvent.failed(InstallFailure.internal)),
        onDone: end,
      );
    } on Exception {
      end(const InstallEvent.failed(InstallFailure.internal));
    }
    return out.stream;
  }

  @override
  Future<void> cancel() async {
    final cancel = _cancel;
    if (cancel == null) return;
    await _stopPlugin();
    cancel();
  }

  Future<void> _stopPlugin() async {
    try {
      await OtaUpdate().cancel();
    } on Exception {
      // nothing to cancel, or no plugin: the stream ends either way
    }
  }

  static InstallEvent? _eventOf(OtaEvent event) => switch (event.status) {
    OtaStatus.DOWNLOADING => InstallEvent.downloading(
      (int.tryParse(event.value ?? '') ?? 0).clamp(0, 100),
    ),
    OtaStatus.INSTALLING => const InstallEvent.installing(),
    OtaStatus.INSTALLATION_DONE => null,
    OtaStatus.PERMISSION_NOT_GRANTED_ERROR => const InstallEvent.failed(
      InstallFailure.notAllowed,
    ),
    OtaStatus.DOWNLOAD_ERROR => const InstallEvent.failed(
      InstallFailure.download,
    ),
    OtaStatus.CHECKSUM_ERROR => const InstallEvent.failed(
      InstallFailure.checksum,
    ),
    // ota_update 7.1.0's Java and Dart list these two in opposite orders, so
    // either may be the other; both mean Android did not start installing
    OtaStatus.ALREADY_RUNNING_ERROR || OtaStatus.INSTALLATION_ERROR =>
      const InstallEvent.failed(InstallFailure.install),
    OtaStatus.INTERNAL_ERROR => const InstallEvent.failed(
      InstallFailure.internal,
    ),
    OtaStatus.CANCELED => const InstallEvent.failed(InstallFailure.cancelled),
  };
}
