import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/profile.dart';
import 'package:lexodle/you_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trip', () {
    final p = Profile.fromJson(
      Profile(name: 'ann', icon: 'bolt', bg: 2).toJson(),
    );
    expect((p.name, p.icon, p.bg), ('ann', 'bolt', 2));
  });

  test('damage is tolerated', () {
    for (final j in <Object?>[
      null,
      5,
      'x',
      [],
      {'name': 3, 'icon': 1, 'bg': 'a'},
    ]) {
      final p = Profile.fromJson(j);
      expect((p.name, p.icon, p.bg), ('player', 'ghost', 0));
    }
    final p = Profile.fromJson({
      'name': 'abcdefghijklmnopqrstuvwxyz',
      'icon': 'nope',
      'bg': 9,
    });
    expect(p.name, 'abcdefghijklmnop');
    expect((p.icon, p.bg), ('ghost', 0));
  });

  testWidgets('the chip shows the name and the sheet changes the profile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setProfile(Profile());
    await tester.binding.setSurfaceSize(const Size(420, 1700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: YouPage(onReplayFirstGame: () {})),
      ),
    );
    await tester.pump();
    expect(find.text('player'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('you-chip')));
    await tester.pumpAndSettle();
    expect(find.text('your name and photo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-icon-flame')));
    await tester.tap(find.byKey(const ValueKey('profile-bg-3')));
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'zed ');
    await tester.pump();
    expect(appState.profile.icon, 'flame');
    expect(appState.profile.bg, 3);
    expect(appState.profile.name, 'zed ');
    await tester.tap(find.byTooltip('close'));
    await tester.pumpAndSettle();
    expect(find.text('zed '), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('profile'), contains('flame'));
  });
}
