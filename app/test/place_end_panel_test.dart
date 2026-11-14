import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexodle/game.dart';
import 'package:lexodle/geography.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/place_info_view.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/word_info.dart';
import 'package:lexodle/words.dart';
import 'package:lexodle/wiktionary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The end panel of a geography game asks Wikipedia about the place; the
/// other modes still ask Wiktionary about the word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

  Future<void> type(WidgetTester tester, String w) async {
    for (final ch in w.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(ch.codeUnitAt(0)),
        character: ch,
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  Future<void> play(WidgetTester tester, GameMode mode) async {
    final offline = MockClient((_) async => http.Response('{}', 404));
    PlaceWiki.shared = PlaceWiki(client: offline);
    Wiktionary.shared = Wiktionary(client: offline);
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await appState.load();
    appState.setup(lang: 'en', length: 5, tries: 6, mode: mode);
    final bank = (await tester.runAsync(() async {
      final en = (await WordBank.languages()).firstWhere((l) => l.code == 'en');
      return mode == GameMode.themed ? Geography.load(en) : WordBank.load(en);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(bank: bank, mode: mode, random: Random(7)),
        onGenerateRoute: onGenerateRoute,
      ),
    );
    await tester.pump();
    // six wrong guesses end the game, whatever the answer is
    final wrong = bank.guessable(5).take(6).toList();
    for (final w in wrong) {
      await type(tester, w);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a geography game ends with the place view', (tester) async {
    await play(tester, GameMode.themed);
    expect(find.byType(PlaceInfoView), findsOneWidget);
    expect(find.byType(WordInfoView), findsNothing);
  });

  testWidgets('the classic game still shows the word view', (tester) async {
    await play(tester, GameMode.classic);
    expect(find.byType(WordInfoView), findsOneWidget);
    expect(find.byType(PlaceInfoView), findsNothing);
  });
}
