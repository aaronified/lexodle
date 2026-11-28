import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/lex.dart';
import 'package:lexodle/lex_widgets.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
  });

  Future<void> show(WidgetTester tester, Achievement a) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: EarnedRow(a))));

  testWidgets('with lex the row is the name and the lex it paid', (
    tester,
  ) async {
    appState.lex.veteran = true;
    final a = achievements.first;
    appState.lex.lastPaid
      ..clear()
      ..[a.id] = 5;
    await show(tester, a);
    expect(find.text(a.title), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.textContaining(a.description), findsNothing);
  });

  testWidgets('an achievement that paid nothing shows no number', (
    tester,
  ) async {
    appState.lex.veteran = true;
    final a = achievements.first;
    appState.lex.lastPaid.clear();
    await show(tester, a);
    expect(find.text(a.title), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('before lex the row says what the achievement asks', (
    tester,
  ) async {
    appState.lex.veteran = false;
    final a = achievements.first;
    await show(tester, a);
    expect(find.textContaining(a.description), findsOneWidget);
  });

  test('a game pays each achievement once, and says how much', () {
    final lex = Lex();
    final a = achievements.first;
    final paid = lex.earn([a], lang: 'en', today: '2026-11-28', hinted: false);
    expect(paid, greaterThan(0));
    expect(lex.lastPaid[a.id], paid);
    // the same day again: paid already, so nothing
    lex.earn([a], lang: 'en', today: '2026-11-28', hinted: false);
    expect(lex.lastPaid, isEmpty);
    // a hinted game pays nothing
    lex.earn([a], lang: 'en', today: '2026-11-29', hinted: true);
    expect(lex.lastPaid, isEmpty);
  });
}
