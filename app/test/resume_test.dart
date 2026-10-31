import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/clock.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var asked = 0;
  var redraws = 0;
  void count() => redraws++;

  setUp(() {
    asked = 0;
    redraws = 0;
    var mono = Duration.zero;
    TrustedClock.reset();
    TrustedClock.monotonic = () => mono;
    TrustedClock.deviceNow = () => DateTime.utc(2026, 10, 24, 18, 29, 50);
    TrustedClock.clientFactory = () => MockClient((_) async {
      asked++;
      return http.Response(
        '',
        200,
        headers: {'date': 'Sat, 24 Oct 2026 18:30:30 GMT'}, // 00:00:30 in IST
      );
    });
    dailyClock = TrustedClock.now;
    appState.addListener(count);
  });

  tearDown(() {
    appState.removeListener(count);
    TrustedClock.reset();
    dailyClock = TrustedClock.now;
  });

  test('coming back draws everything again', () {
    AppResume().didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(redraws, greaterThanOrEqualTo(1));
  });

  test(
    'and asks the server the time when the last answer is old or none',
    () async {
      AppResume().didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(asked, 1);
      expect(TrustedClock.verified, isTrue);
      expect(
        redraws,
        greaterThanOrEqualTo(2),
        reason: 'again once it answered',
      );
    },
  );

  test('not when the last answer is fresh', () async {
    await TrustedClock.sync(client: TrustedClock.clientFactory());
    asked = 0;
    AppResume().didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(asked, 0);
    expect(redraws, 1);
  });

  test('other changes of state do nothing', () {
    final r = AppResume();
    for (final s in [
      AppLifecycleState.paused,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      r.didChangeAppLifecycleState(s);
    }
    expect(redraws, 0);
    expect(asked, 0);
  });

  test('the day it shows follows the server after it answers', () async {
    // the device says 23:59:50 on the 24th, the server 00:00:30 on the 25th
    // in a zone that is ahead: the date the daily is on is the server's
    final before = dailyDate();
    await TrustedClock.sync(client: TrustedClock.clientFactory());
    final after = dailyDate();
    expect(before, '2026-10-24');
    // 18:30:30 UTC is 00:00:30 on the 25th in India
    expect(after, '2026-10-25');
  });
}
