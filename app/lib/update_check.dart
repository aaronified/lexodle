import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The version of this build. Kept in step with `version:` in pubspec.yaml: a
/// test fails when they differ, and the release workflow refuses a tag that
/// does not match the pubspec.
const appVersion = '0.3.1';

/// The repository the releases come from.
const releaseRepo = 'aaronified/lexodle';

/// What the newest release offers: its version, the APK to install and, when
/// GitHub gives one, the SHA-256 of that file.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.apkName,
    this.sha256,
  });

  /// The tag without its "v", such as `0.1.2`.
  final String version;
  final String apkUrl;
  final String apkName;

  /// Lower-case hex, or null for a release without a digest.
  final String? sha256;
}

/// Why a check did not get an answer.
enum CheckFailure {
  /// No network, or no answer in time.
  offline,

  /// GitHub's limit on requests without an account (403 or 429).
  rateLimited,

  /// An answer that could not be read.
  badReply,
}

/// What a check found.
sealed class CheckResult {
  const CheckResult();
}

class UpToDate extends CheckResult {
  const UpToDate();
}

class UpdateAvailable extends CheckResult {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

class CheckFailed extends CheckResult {
  const CheckFailed(this.why);
  final CheckFailure why;
}

/// Splits `v0.1.2` or `0.1.2` into numbers; null when it is not dotted numbers.
List<int>? parseVersion(String text) {
  final t = text.trim().replaceFirst(RegExp('^[vV]'), '');
  if (t.isEmpty) return null;
  final parts = <int>[];
  for (final p in t.split('.')) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    parts.add(n);
  }
  return parts;
}

/// Whether [offered] is a later version than [have], number by number (a
/// missing number counts as 0). A version that cannot be read is not newer.
bool isNewer(String offered, String have) {
  final a = parseVersion(offered), b = parseVersion(have);
  if (a == null || b == null) return false;
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Reads GitHub's "latest release" reply. A release without its APK reads as up
/// to date: there is nothing newer to install yet (the file is uploaded a
/// minute after the release appears), and a download of a missing file would
/// install GitHub's 404 page.
CheckResult readRelease(Object? json, {String have = appVersion}) {
  if (json is! Map) return const CheckFailed(CheckFailure.badReply);
  final tag = json['tag_name'];
  if (tag is! String || parseVersion(tag) == null) {
    return const CheckFailed(CheckFailure.badReply);
  }
  final version = tag.trim().replaceFirst(RegExp('^[vV]'), '');
  if (!isNewer(version, have)) return const UpToDate();
  final assets = json['assets'];
  if (assets is List) {
    for (final a in assets) {
      if (a is! Map) continue;
      final name = a['name'], url = a['browser_download_url'];
      if (name is String &&
          url is String &&
          name.startsWith('lexodle-') &&
          name.endsWith('.apk')) {
        final digest = a['digest'];
        final sha = digest is String && digest.startsWith('sha256:')
            ? digest.substring(7).toLowerCase()
            : null;
        return UpdateAvailable(
          ReleaseInfo(
            version: version,
            apkUrl: url,
            apkName: name,
            sha256: sha != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)
                ? sha
                : null,
          ),
        );
      }
    }
  }
  return const UpToDate();
}

/// Asks where the newest release is. Narrow enough that tests fake it.
abstract interface class ReleaseCheck {
  Future<CheckResult> check();
}

/// GitHub's own answer, with no account: one request to the releases API.
class GitHubReleaseCheck implements ReleaseCheck {
  GitHubReleaseCheck({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<CheckResult> check() async {
    try {
      final r = await _client
          .get(
            Uri.https('api.github.com', '/repos/$releaseRepo/releases/latest'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'lexodle/$appVersion',
            },
          )
          .timeout(timeout);
      if (r.statusCode == 403 || r.statusCode == 429) {
        return const CheckFailed(CheckFailure.rateLimited);
      }
      if (r.statusCode != 200) return const CheckFailed(CheckFailure.badReply);
      return readRelease(jsonDecode(utf8.decode(r.bodyBytes)));
    } on TimeoutException {
      return const CheckFailed(CheckFailure.offline);
    } on FormatException {
      return const CheckFailed(CheckFailure.badReply);
    } on Exception {
      return const CheckFailed(CheckFailure.offline);
    }
  }
}

/// A check with a fixed answer, for tests.
class FixedReleaseCheck implements ReleaseCheck {
  FixedReleaseCheck(this.result);
  CheckResult result;
  int asked = 0;

  @override
  Future<CheckResult> check() async {
    asked++;
    return result;
  }
}
