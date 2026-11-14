import 'package:share_plus/share_plus.dart';

import 'app_log.dart';

/// Opens the system share menu (on Android, the share sheet) with [text];
/// false when it could not be opened, so a caller can say so. Nothing is
/// logged but the error's type.
Future<bool> shareText(String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
    return true;
  } catch (e) {
    appLog.w('share', 'could not open the share menu: ${e.runtimeType}');
    return false;
  }
}
