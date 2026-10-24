import 'apk_install.dart';

/// The web build installs nothing: there is no APK to open.
ApkInstaller create() => const NullApkInstaller();
