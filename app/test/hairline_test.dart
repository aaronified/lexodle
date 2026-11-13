import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/ui.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / ((x > y ? y : x) + .05);
}

void main() {
  final themes = {
    'light': buildTheme(Brightness.light),
    'dark': buildTheme(Brightness.dark),
    'black': buildTheme(Brightness.dark, black: true),
  };

  test('the hairline is 0.75 wide and quiet but visible in every theme', () {
    for (final e in themes.entries) {
      final c = e.value.colorScheme;
      expect(hairline(c).width, 0.75, reason: e.key);
      final r = _ratio(hairlineColor(c), c.surface);
      expect(r, inInclusiveRange(1.4, 2.1), reason: '${e.key} $r');
    }
  });

  testWidgets('a card, an outlined button and a field have outlines', (
    tester,
  ) async {
    final theme = themes['dark']!;
    final c = theme.colorScheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                hairlineCard(
                  context,
                  key: const ValueKey('card'),
                  child: const Text('a'),
                ),
                hairlineCard(
                  context,
                  key: const ValueKey('inner'),
                  color: shadeUp(c),
                  child: const Text('b'),
                ),
                OutlinedButton(
                  key: const ValueKey('btn'),
                  onPressed: () {},
                  child: const Text('c'),
                ),
                const TextField(key: ValueKey('field')),
              ],
            ),
          ),
        ),
      ),
    );
    final card = tester.widget<Container>(find.byKey(const ValueKey('card')));
    expect(
      (card.decoration! as BoxDecoration).border,
      Border.fromBorderSide(hairline(c)),
    );
    final inner = tester.widget<Container>(find.byKey(const ValueKey('inner')));
    expect((inner.decoration! as BoxDecoration).border, isNull);
    final btnStyle = OutlinedButtonTheme.of(
      tester.element(find.byKey(const ValueKey('btn'))),
    ).style!;
    expect(btnStyle.side!.resolve({}), hairline(c));
    final field = tester.widget<TextField>(find.byKey(const ValueKey('field')));
    final dec = theme.inputDecorationTheme;
    expect((dec.enabledBorder! as OutlineInputBorder).borderSide, hairline(c));
    expect(
      (dec.focusedBorder! as OutlineInputBorder).borderSide.width,
      greaterThan(hairline(c).width * 1.5),
    );
    expect(field, isNotNull);
  });
}
