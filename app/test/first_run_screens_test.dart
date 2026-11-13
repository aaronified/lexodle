import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/first_run/gateway_page.dart';
import 'package:lexodle/first_run/modes_offer_page.dart';
import 'package:lexodle/first_run/modes_tour_page.dart';
import 'package:lexodle/modes.dart';

Widget _wrap(Widget w) => MaterialApp(home: w);

void main() {
  testWidgets('gateway buttons fire', (t) async {
    var okay = 0, replay = 0;
    await t.pumpWidget(
      _wrap(GatewayPage(onOkay: () => okay++, onReplay: () => replay++)),
    );
    await t.tap(find.text('okay'));
    await t.tap(find.text('replay'));
    expect([okay, replay], [1, 1]);
  });

  testWidgets('offer buttons fire', (t) async {
    var yes = 0, no = 0;
    await t.pumpWidget(
      _wrap(ModesOfferPage(onLearn: () => yes++, onNotNow: () => no++)),
    );
    await t.tap(find.text('yes'));
    await t.tap(find.text('not now'));
    expect([yes, no], [1, 1]);
  });

  testWidgets('tour: seven modes, swipe, learn, close, finish', (t) async {
    final learned = <GameMode>[];
    var done = 0;
    await t.pumpWidget(
      _wrap(ModesTourPage(onLearn: learned.add, onDone: () => done++)),
    );
    expect(find.byKey(const ValueKey('tour-dot-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('tour-dot-7')), findsNothing);
    expect(find.text('quartet'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tour-learn')));
    expect(learned, [GameMode.quartet]);
    await t.drag(
      find.byKey(const ValueKey('tour-pages')),
      const Offset(-500, 0),
    );
    await t.pumpAndSettle();
    expect(find.text('relay race'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tour-learn')));
    expect(learned.last, GameMode.relay);
    for (var i = 0; i < 5; i++) {
      await t.drag(
        find.byKey(const ValueKey('tour-pages')),
        const Offset(-500, 0),
      );
      await t.pumpAndSettle();
    }
    expect(find.text('mastermind'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tour-close')));
    await t.tap(find.byKey(const ValueKey('tour-finish')));
    expect(done, 2);
  });
}
