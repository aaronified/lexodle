import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/hint_pick.dart';
import 'package:lexodle/lex.dart';

void main() {
  const letters = {'a', 'b', 'c', 'd', 'e'};

  test('a hint survives the saved JSON', () {
    const h = HintPick(HintKind.green, 'c', 2, 3);
    final back = hintsFromJson(
      hintsToJson([h]),
      boards: 4,
      length: 5,
      letters: letters,
    );
    expect(back, hasLength(1));
    expect(back.single.kind, HintKind.green);
    expect(back.single.letter, 'c');
    expect(back.single.pos, 2);
    expect(back.single.board, 3);
  });

  test('a save without the key, or a damaged one, gives no hints', () {
    for (final j in [
      null,
      'x',
      7,
      [1, 'a', <String, dynamic>{}],
      [
        {'k': 'grey', 'l': 'z'},
        {'k': 'grey', 'l': 'a', 'b': 9},
        {'k': 'nope', 'l': 'a'},
        {'k': 'green', 'l': 'a', 'p': 5},
      ],
    ]) {
      expect(hintsFromJson(j, boards: 4, length: 5, letters: letters), isEmpty);
    }
  });

  test('restoring a hint charges nothing', () {
    final lex = Lex()
      ..balance = 50
      ..freeHints = 0;
    final game = restoreHints([
      const HintPick(HintKind.yellow, 'a'),
    ], guesses: 2);
    expect(game.hinted, isTrue);
    expect(game.kinds, [HintKind.yellow]);
    expect(lex.balance, 50);
    expect(lex.ledger, isEmpty);
  });
}
