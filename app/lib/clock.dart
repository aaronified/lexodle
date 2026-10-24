import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// The time the daily goes by. The device's own clock can be wrong or set to
/// another day to get that day's word or to keep a streak, so the app asks the
/// server it is hosted on what time it is, and goes by that: the `Date` header
/// of one request, with half the round trip allowed for. Nothing else is sent or
/// kept, and no other service is involved.
///
/// After that answer the time moves on by a monotonic stopwatch, which the
/// player cannot change, not by the device's clock; so setting the clock
/// forward or back after the app has checked does nothing. When the server
/// cannot be reached the device's clock is used, quietly: the daily must still
/// play offline. Changing what the app saved on the device is another matter,
/// and nothing here stops that.
class TrustedClock {
  const TrustedClock._();

  /// What the device says. Used to time a request, and as the time only
  /// until the server has answered; tests replace it.
  static DateTime Function() deviceNow = DateTime.now;

  static final _watch = Stopwatch()..start();

  /// A reading of a clock that only runs forward and cannot be set; tests
  /// replace it.
  static Duration Function() monotonic = () => _watch.elapsed;

  /// The server's time (UTC) at the moment of the last answer, and the
  /// monotonic reading then.
  static DateTime? _anchor;
  static Duration _anchorAt = Duration.zero;

  /// Whether the server has answered: the time is then its, not the device's.
  static bool get verified => _anchor != null;

  /// The time now: the server's, carried on by the stopwatch, or the device's
  /// own before the server has answered.
  static DateTime now() {
    final a = _anchor;
    return a == null ? deviceNow() : a.add(monotonic() - _anchorAt);
  }

  /// How far the device clock is from the server's now (positive when the
  /// device is behind), or zero before the server has answered.
  static Duration get offset =>
      _anchor == null ? Duration.zero : now().difference(deviceNow().toUtc());

  /// Where the site is hosted, for an app that is not itself running in a
  /// browser on it (a web build asks its own origin, which needs no allowance
  /// to read the header).
  static const hostUrl = 'https://aaronified.github.io/lexodle/';

  /// Makes the client a [sync] uses; tests put a fake one here.
  static http.Client Function() clientFactory = http.Client.new;

  /// Whether the last answer is recent enough not to ask again.
  static bool isFresh([Duration within = const Duration(minutes: 10)]) =>
      _anchor != null && monotonic() - _anchorAt < within;

  /// Asks the server the time; true when it answered. A failure of any kind
  /// leaves the last answer (or the device clock) in use.
  static Future<bool> sync({
    http.Client? client,
    Uri? url,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final c = client ?? clientFactory();
    try {
      final bust = deviceNow().millisecondsSinceEpoch;
      final target =
          url ??
          (kIsWeb
              ? Uri.base.replace(query: 't=$bust', fragment: '')
              : Uri.parse('$hostUrl?t=$bust'));
      final sentAt = monotonic();
      // a new address each time and no-cache, so a cache cannot answer with an
      // old Date
      final res = await c
          .head(target, headers: const {'cache-control': 'no-cache'})
          .timeout(timeout);
      final receivedAt = monotonic();
      final date = parseHttpDate(res.headers['date']);
      if (date == null) return false;
      // the server stamped it about halfway through the round trip, and a Date
      // is cut to whole seconds, so half a second is added back
      final half = (receivedAt - sentAt) ~/ 2;
      _anchor = date.add(const Duration(milliseconds: 500) + half);
      _anchorAt = receivedAt;
      return true;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Back to the device clock (for tests).
  static void reset() {
    _anchor = null;
    _anchorAt = Duration.zero;
    deviceNow = DateTime.now;
    monotonic = () => _watch.elapsed;
    clientFactory = http.Client.new;
  }
}

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

/// A date from an HTTP `Date` header (`Sat, 24 Oct 2026 12:00:00 GMT`), in UTC,
/// or null when it is not that.
DateTime? parseHttpDate(String? text) {
  if (text == null) return null;
  final m = RegExp(
    r'^[A-Za-z]{3}, (\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(text.trim());
  if (m == null) return null;
  final month = _months[m[2]];
  if (month == null) return null;
  final day = int.parse(m[1]!);
  final hour = int.parse(m[4]!), minute = int.parse(m[5]!);
  final second = int.parse(m[6]!);
  if (day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60) {
    return null;
  }
  return DateTime.utc(
    int.parse(m[3]!),
    month,
    day,
    hour,
    minute,
    second > 59 ? 59 : second,
  );
}
