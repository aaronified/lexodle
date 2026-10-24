import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/clock.dart';
import 'package:lexodle/daily.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mons = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// An HTTP Date header for [t], the way a server writes it.
String httpDate(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_days[u.weekday - 1]}, ${two(u.day)} ${_mons[u.month - 1]} '
      '${u.year} ${two(u.hour)}:${two(u.minute)}:${two(u.second)} GMT';
}

MockClient serverSaying(DateTime t) => MockClient(
  (_) async => http.Response('', 200, headers: {'date': httpDate(t)}),
);

void main() {
  /// The monotonic clock a test moves by hand.
  var mono = Duration.zero;

  setUp(() {
    mono = Duration.zero;
    TrustedClock.monotonic = () => mono;
    dailyClock = TrustedClock.now;
  });

  tearDown(() {
    TrustedClock.reset();
    dailyClock = TrustedClock.now;
  });

  group('reading a Date header', () {
    test('a server date is read in UTC', () {
      expect(
        parseHttpDate('Sat, 24 Oct 2026 12:00:00 GMT'),
        DateTime.utc(2026, 10, 24, 12),
      );
      expect(
        parseHttpDate('Thu, 1 Jan 2026 00:00:01 GMT'),
        DateTime.utc(2026, 1, 1, 0, 0, 1),
      );
      expect(
        parseHttpDate(' Sun, 31 Dec 2028 23:59:59 GMT '),
        DateTime.utc(2028, 12, 31, 23, 59, 59),
      );
    });

    test('a leap second is the last second of the minute', () {
      expect(
        parseHttpDate('Sat, 31 Dec 2016 23:59:60 GMT'),
        DateTime.utc(2016, 12, 31, 23, 59, 59),
      );
    });

    test('anything else is not a date', () {
      for (final bad in [
        null,
        '',
        'yesterday',
        'Sat, 24 Octo 2026 12:00:00 GMT',
        'Sat, 24 Xxx 2026 12:00:00 GMT',
        'Sat, 24 Oct 2026 12:00:00 PST',
        'Sat, 24 Oct 2026 25:00:00 GMT',
        'Sat, 32 Oct 2026 12:00:00 GMT',
        '2026-10-24T12:00:00Z',
      ]) {
        expect(parseHttpDate(bad), isNull, reason: '$bad');
      }
    });
  });

  group('asking the server', () {
    test('the time becomes the server\'s, not the device\'s', () async {
      final device = DateTime(2026, 10, 24, 10, 0, 0);
      TrustedClock.deviceNow = () => device;
      // the server says it is two hours later than the device thinks
      final server = device.add(const Duration(hours: 2));
      expect(TrustedClock.verified, isFalse);
      expect(TrustedClock.now(), device, reason: 'the device until it answers');
      expect(await TrustedClock.sync(client: serverSaying(server)), isTrue);
      expect(TrustedClock.verified, isTrue);
      // to within the second a Date is cut to
      final diff = TrustedClock.now().difference(server.toUtc());
      expect(diff.inMilliseconds, inInclusiveRange(0, 1000));
      expect(
        (TrustedClock.offset - const Duration(hours: 2)).inMilliseconds,
        inInclusiveRange(0, 1000),
      );
    });

    test('half the round trip is allowed for', () async {
      final device = DateTime(2026, 10, 24, 10);
      TrustedClock.deviceNow = () => device;
      final server = DateTime.utc(2026, 10, 24, 5);
      final client = MockClient((_) async {
        mono += const Duration(seconds: 2); // the reply took two seconds
        return http.Response('', 200, headers: {'date': httpDate(server)});
      });
      await TrustedClock.sync(client: client);
      // it was stamped about a second in, and the app is a second past that
      // now: 5:00:00 + half a second (the cut) + one second to get here
      expect(
        TrustedClock.now().difference(server).inMilliseconds,
        inInclusiveRange(1500, 1500),
      );
    });

    test('a device clock set to another day cannot move the daily', () async {
      // the device says November, the server October 24th
      TrustedClock.deviceNow = () => DateTime(2026, 11, 20, 9, 0);
      expect(dailyDate(), '2026-11-20', reason: 'before the server answers');
      await TrustedClock.sync(client: serverSaying(DateTime(2026, 10, 24, 9)));
      expect(dailyDate(), '2026-10-24');
    });

    test('and setting it after the server has answered does nothing', () async {
      TrustedClock.deviceNow = () => DateTime(2026, 10, 24, 9, 0);
      await TrustedClock.sync(client: serverSaying(DateTime(2026, 10, 24, 9)));
      final before = TrustedClock.now();
      expect(dailyDate(), '2026-10-24');
      // the player puts the clock on a week, and then back a week
      TrustedClock.deviceNow = () => DateTime(2026, 10, 31, 9, 0);
      expect(TrustedClock.now(), before);
      expect(dailyDate(), '2026-10-24');
      TrustedClock.deviceNow = () => DateTime(2026, 10, 17, 9, 0);
      expect(dailyDate(), '2026-10-24');
      // time still passes, by the stopwatch
      mono += const Duration(hours: 3);
      expect(TrustedClock.now().difference(before), const Duration(hours: 3));
    });

    test('the day changes at local midnight, by the server\'s time', () async {
      // the device is 40 seconds slow: 23:59:30 here, 00:00:10 on the server
      final device = DateTime(2026, 10, 24, 23, 59, 30);
      TrustedClock.deviceNow = () => device;
      expect(dailyDate(), '2026-10-24');
      await TrustedClock.sync(
        client: serverSaying(device.add(const Duration(seconds: 40))),
      );
      expect(dailyDate(), '2026-10-25');
      // and it stays on the server's time as the stopwatch runs
      mono += const Duration(hours: 24);
      expect(dailyDate(), '2026-10-26');
    });

    test(
      'it asks one HEAD request, to a new address each time, uncached',
      () async {
        final seen = <http.BaseRequest>[];
        var t = 1000;
        TrustedClock.deviceNow = () =>
            DateTime.fromMillisecondsSinceEpoch(t += 7);
        final client = MockClient((r) async {
          seen.add(r);
          return http.Response(
            '',
            200,
            headers: {'date': httpDate(DateTime.now())},
          );
        });
        await TrustedClock.sync(client: client);
        await TrustedClock.sync(client: client);
        expect(seen.length, 2);
        expect(seen.every((r) => r.method == 'HEAD'), isTrue);
        expect(
          seen.every((r) => r.headers['cache-control'] == 'no-cache'),
          isTrue,
        );
        expect(seen[0].url.query, isNot(seen[1].url.query));
        expect(seen[0].url.queryParameters.keys, ['t']);
        // nothing about the player goes with it
        expect(seen[0].headers.keys, ['cache-control']);
        expect(seen[0].url.host, 'aaronified.github.io');
      },
    );

    test('it can be sent to another address', () async {
      Uri? asked;
      final client = MockClient((r) async {
        asked = r.url;
        return http.Response(
          '',
          200,
          headers: {'date': httpDate(DateTime.now())},
        );
      });
      await TrustedClock.sync(
        client: client,
        url: Uri.parse('https://example.org/time'),
      );
      expect(asked, Uri.parse('https://example.org/time'));
    });

    test('with no client given it makes one, and closes it', () async {
      var made = 0;
      var closed = false;
      TrustedClock.clientFactory = () {
        made++;
        return _Closing(
          serverSaying(DateTime(2026, 10, 24, 9)),
          () => closed = true,
        );
      };
      expect(await TrustedClock.sync(), isTrue);
      expect(made, 1);
      expect(closed, isTrue);
      // a client the caller gave is the caller's to close
      closed = false;
      final mine = _Closing(
        serverSaying(DateTime(2026, 10, 24, 9)),
        () => closed = true,
      );
      await TrustedClock.sync(client: mine);
      expect(closed, isFalse);
    });
  });

  group('when the server cannot be asked', () {
    test('the system time is used, quietly', () async {
      TrustedClock.deviceNow = () => DateTime(2026, 10, 24, 12);
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      expect(await TrustedClock.sync(client: client), isFalse);
      expect(TrustedClock.verified, isFalse);
      expect(TrustedClock.offset, Duration.zero);
      expect(TrustedClock.now(), DateTime(2026, 10, 24, 12));
      expect(dailyDate(), '2026-10-24');
      // and the device clock is followed, as there is nothing to hold it to
      TrustedClock.deviceNow = () => DateTime(2026, 10, 25, 0, 0, 1);
      expect(dailyDate(), '2026-10-25');
    });

    test('a server error with no usable Date is ignored', () async {
      for (final headers in [
        <String, String>{},
        {'date': 'not a date'},
      ]) {
        final client = MockClient(
          (_) async => http.Response('', 500, headers: headers),
        );
        expect(
          await TrustedClock.sync(client: client),
          isFalse,
          reason: '$headers',
        );
      }
      expect(TrustedClock.verified, isFalse);
    });

    test('a slow server is given up on', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final ok = await TrustedClock.sync(
        client: client,
        timeout: const Duration(milliseconds: 20),
      );
      expect(ok, isFalse);
      expect(TrustedClock.verified, isFalse);
    });

    test('a failed ask after a good one keeps the good answer', () async {
      final device = DateTime(2026, 10, 24, 10);
      TrustedClock.deviceNow = () => device;
      await TrustedClock.sync(
        client: serverSaying(device.add(const Duration(minutes: 5))),
      );
      final before = TrustedClock.now();
      final bad = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      expect(await TrustedClock.sync(client: bad), isFalse);
      expect(TrustedClock.now(), before);
      expect(TrustedClock.verified, isTrue);
    });
  });

  group('how fresh it is', () {
    test('an answer is fresh for ten minutes', () async {
      TrustedClock.deviceNow = () => DateTime(2026, 10, 24, 10);
      expect(TrustedClock.isFresh(), isFalse);
      await TrustedClock.sync(client: serverSaying(DateTime(2026, 10, 24, 10)));
      expect(TrustedClock.isFresh(), isTrue);
      mono += const Duration(minutes: 9);
      expect(TrustedClock.isFresh(), isTrue);
      mono += const Duration(minutes: 2);
      expect(TrustedClock.isFresh(), isFalse);
      expect(TrustedClock.isFresh(const Duration(hours: 1)), isTrue);
    });

    test('the device clock does not make an answer stale or fresh', () async {
      TrustedClock.deviceNow = () => DateTime(2026, 10, 24, 10);
      await TrustedClock.sync(client: serverSaying(DateTime(2026, 10, 24, 10)));
      TrustedClock.deviceNow = () => DateTime(2030, 1, 1);
      expect(TrustedClock.isFresh(), isTrue);
    });
  });
}

/// A client that says when it is closed.
class _Closing extends http.BaseClient {
  _Closing(this._inner, this._onClose);
  final http.Client _inner;
  final void Function() _onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => _onClose();
}
