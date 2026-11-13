import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/game_timer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var clock = Duration.zero;
  Duration now() => clock;
  void pass(int s) => clock += Duration(seconds: s);
  late GameTimer t;

  setUp(() {
    clock = Duration.zero;
    t = GameTimer(now: now);
  });
  tearDown(() => t.dispose());

  test('it counts nothing before the first key', () {
    pass(5);
    expect(t.running, isFalse);
    expect(t.elapsedMs, 0);
    t.resume(); // not started: nothing
    expect(t.running, isFalse);
  });

  test('start, pause, resume and stop', () {
    t.start();
    pass(3);
    expect(t.running, isTrue);
    expect(t.elapsedMs, 3000);
    t.start(); // already running: nothing
    pass(1);
    t.pause();
    pass(10);
    expect(t.running, isFalse);
    expect(t.elapsedMs, 4000);
    t.resume();
    pass(2);
    expect(t.elapsedMs, 6000);
    t.stop();
    pass(10);
    expect(t.elapsedMs, 6000);
    t.start();
    t.resume();
    expect(t.running, isFalse);
  });

  test('a resumed game goes on from the time it had', () {
    final r = GameTimer(elapsedMs: 5000, now: now);
    expect(r.elapsedMs, 5000);
    r.start();
    pass(2);
    expect(r.elapsedMs, 7000);
    r.dispose();
  });

  test('leaving the app pauses it, coming back resumes what was running', () {
    t.start();
    pass(2);
    t.didChangeAppLifecycleState(AppLifecycleState.inactive);
    t.didChangeAppLifecycleState(AppLifecycleState.paused);
    pass(30);
    expect(t.running, isFalse);
    t.didChangeAppLifecycleState(AppLifecycleState.resumed);
    pass(1);
    expect(t.running, isTrue);
    expect(t.elapsedMs, 3000);
    t.stop();
    t.didChangeAppLifecycleState(AppLifecycleState.paused);
    t.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(t.running, isFalse);
  });

  test('coming back does not start a timer that never started', () {
    t.didChangeAppLifecycleState(AppLifecycleState.paused);
    t.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(t.running, isFalse);
  });

  testWidgets('it notifies every second while it runs', (tester) async {
    var n = 0;
    t.addListener(() => n++);
    t.start();
    final after = n;
    await tester.pump(const Duration(seconds: 3));
    expect(n, greaterThanOrEqualTo(after + 3));
    t.stop();
    final stopped = n;
    await tester.pump(const Duration(seconds: 3));
    expect(n, stopped);
  });

  test('formatElapsed', () {
    expect(formatElapsed(0), '0:00');
    expect(formatElapsed(7999), '0:07');
    expect(formatElapsed(754000), '12:34');
    expect(formatElapsed(3599000), '59:59');
    expect(formatElapsed(3600000), '1:00:00');
    expect(formatElapsed(3723000), '1:02:03');
    expect(formatElapsed(-5), '0:00');
  });
}
