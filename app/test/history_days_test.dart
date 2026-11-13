import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

void game(
  History h,
  int day, {
  double skill = 70,
  double luck = 0,
  double risk = 30,
  bool won = true,
}) {
  h.add(
    at: DateTime(2026, 10, day, 12).toUtc().millisecondsSinceEpoch,
    lang: 'en',
    mode: GameMode.classic,
    length: 5,
    tries: 6,
    pool: 500,
    answers: ['slate'],
    won: won,
    guesses: [
      for (var i = 0; i < 2; i++)
        GuessRow(
          game: 0,
          n: i,
          word: 'crane',
          skill: skill,
          luck: luck,
          risk: risk,
          before: 100,
          after: 10,
        ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    dailyClock = () => DateTime(2026, 10, 24, 12);
  });
  tearDown(() => dailyClock = DateTime.now);

  History prepared() {
    final h = History();
    game(h, 20, skill: 80, luck: 10, risk: 20);
    game(h, 20, skill: 90, luck: -20, risk: 40, won: false);
    game(h, 24, skill: 60, luck: 0, risk: 50);
    return h;
  }

  test('a day is the mean of its games, with gaps between played days', () {
    final d = dailyPeriods(prepared(), '2026-10-24', lang: 'en');
    expect(d.length, 50);
    expect(d.last.label, '2026-10-24');
    expect(d.first.label, '2026-09-05');
    final first = d[d.length - 5]; // 2026-10-20
    expect(first.label, '2026-10-20');
    expect(first.stats.games, 2);
    expect(first.stats.won, 1);
    expect(first.stats.skill, closeTo(85, 1e-9));
    expect(first.stats.luck, closeTo(-5, 1e-9));
    expect(first.stats.risk, closeTo(30, 1e-9));
    for (var i = 1; i <= 3; i++) {
      expect(d[d.length - 5 + i].stats.isEmpty, isTrue);
      expect(PeriodSeries.skill.plot(d[d.length - 5 + i].stats), isNull);
    }
    expect(d.last.stats.games, 1);
    expect(d.last.stats.skill, closeTo(60, 1e-9));
  });

  test('the weeks are unchanged by it', () {
    final w = weeklyPeriods(prepared(), '2026-10-24', lang: 'en');
    expect(w.length, 50);
    expect(w.last.start, '2026-10-18');
    expect(w.last.stats.games, 3);
    expect(w.last.stats.skill, closeTo((80 + 90 + 60) / 3, 1e-9));
  });

  testWidgets('the days range is chosen from the third button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1900));
    await appState.load();
    appState.history = prepared();
    appState.lang = 'en';
    await tester.pumpWidget(const MaterialApp(home: HistoryPage()));
    await tester.pump();
    expect(find.text('the last 50 weeks'), findsOneWidget);
    await tester.ensureVisible(find.text('days'));
    await tester.tap(find.text('days'));
    await tester.pump();
    expect(find.text('the last 50 days'), findsOneWidget);
    expect(
      textOf(tester.widget<Text>(find.byKey(const ValueKey('period-label')))),
      '2026-10-24',
    );
    final detail = textOf(
      tester.widget<Text>(find.byKey(const ValueKey('period-detail'))),
    )!;
    expect(detail, contains('1 game'));
    expect(detail, contains('skill 60'));
    await tester.tap(find.text('weeks'));
    await tester.pump();
    expect(find.text('the last 50 weeks'), findsOneWidget);
  });
}
