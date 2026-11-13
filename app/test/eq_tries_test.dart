import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an equations difficulty sets eqTries and leaves tries alone', () {
    final a = AppState();
    expect(a.tries, 6);
    expect(a.eqTries, 5);
    a.setup(eqTries: 3, eqLength: 7);
    expect(a.eqTries, 3);
    expect(a.tries, 6);
    a.setup(eqTries: 9); // not a level: ignored
    expect(a.eqTries, 3);
    a.setup(tries: 4);
    expect(a.tries, 4);
    expect(a.eqTries, 3);
  });

  test('eqTries is kept, and an earlier stored tries is untouched', () async {
    SharedPreferences.setMockInitialValues({'tries': 8});
    final a = AppState();
    await a.load();
    expect(a.tries, 8);
    expect(a.eqTries, 5);
    a.setup(eqTries: 4);
    final b = AppState();
    await b.load();
    expect(b.eqTries, 4);
    expect(b.tries, 8);
  });
}
