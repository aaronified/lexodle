import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/daily.dart';
import 'package:lexodle/daily_intro.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/multi_game.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordBank bank;
  final intro = find.byKey(const ValueKey('daily-intro'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setup(lang: 'en', length: 5, mode: GameMode.classic);
  });

  Future<void> loadBank(WidgetTester tester) async {
    bank = (await tester.runAsync(
      () async => WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
      ),
    ))!;
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Widget daily() => GamePage(
    bank: bank,
    mode: GameMode.classic,
    daily: Daily(dailyDate(), 'crane', tries: dailyTriesOf(GameMode.classic)),
  );

  testWidgets('the first daily shows it, got it dismisses and persists; the '
      'second does not', (tester) async {
    await loadBank(tester);
    appState.dailyIntroSeen = false;
    await open(tester, daily());
    expect(intro, findsOneWidget);
    expect(find.text('your first daily'), findsOneWidget);
    expect(
      find.text('${dailyTriesOf(GameMode.classic)} tries.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('daily-intro-ok')));
    await tester.pumpAndSettle();
    expect(intro, findsNothing);
    expect(appState.dailyIntroSeen, isTrue);
    expect(appState.settingsJson()['dailyIntroSeen'], isTrue);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('dailyIntroSeen'), isTrue);
    await open(tester, const SizedBox());
    await open(tester, daily());
    expect(intro, findsNothing);
  });

  testWidgets('tapping outside dismisses it', (tester) async {
    await loadBank(tester);
    appState.dailyIntroSeen = false;
    await open(tester, daily());
    expect(intro, findsOneWidget);
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(intro, findsNothing);
  });

  testWidgets('the multi-board daily shows it too', (tester) async {
    await loadBank(tester);
    appState.dailyIntroSeen = false;
    final d = DailyMulti.of(bank, GameMode.quartet);
    expect(d, isNotNull);
    await open(tester, MultiGamePage(bank: bank, daily: d));
    expect(intro, findsOneWidget);
    expect(
      find.text('${dailyTriesOf(GameMode.quartet)} tries.'),
      findsOneWidget,
    );
  });

  testWidgets('free play and practice never show it', (tester) async {
    await loadBank(tester);
    appState.dailyIntroSeen = false;
    await open(tester, GamePage(bank: bank, mode: GameMode.classic));
    expect(intro, findsNothing);
    await open(tester, const SizedBox());
    await open(
      tester,
      GamePage(
        bank: bank,
        mode: GameMode.classic,
        practice: true,
        daily: const Daily('', 'crane', tries: 6),
      ),
    );
    expect(intro, findsNothing);
    expect(appState.dailyIntroSeen, isFalse);
  });

  testWidgets('a veteran or a player with a daily on record is done from the '
      'start', (tester) async {
    await loadBank(tester);
    appState.lex.veteran = true;
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    // a fresh player: not seen
    appState.lex.veteran = false;
    appState.dailyIntroSeen = false;
    appState.recordDaily(dailyDate(), dailySolved);
    final p = await SharedPreferences.getInstance();
    await p.remove('dailyIntroSeen');
    await appState.load();
    expect(appState.dailyIntroSeen, isTrue);
  });

  test('the tries line is true for every mode', () {
    expect(dailyIntroTries(GameMode.mastermind), 'no limit on guesses.');
    expect(
      dailyIntroTries(GameMode.lockdown),
      '$lockdownTries tries and $dailyHearts hearts.',
    );
    expect(
      dailyIntroTries(GameMode.blind),
      '${dailyTriesOf(GameMode.blind)} tries.',
    );
  });
}
