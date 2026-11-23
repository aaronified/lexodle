import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/master_game.dart';
import 'package:lexodle/words.dart';

Future<WordBank> _bank(WidgetTester tester) async => (await tester.runAsync(
  () async => WordBank.load(
    (await WordBank.languages()).firstWhere((l) => l.code == 'en'),
  ),
))!;

void main() {
  testWidgets('a classic game narrows the words and ends on the word', (
    tester,
  ) async {
    final bank = await _bank(tester);
    final g = MasterGame(
      bank: bank,
      kind: MasterKind.classic,
      length: 5,
      answer: 'about',
      analyse: false,
    );
    expect(g.pool.length, bank.answers(5).length);
    for (final c in 'tares'.split('')) {
      g.type(c);
    }
    expect(await g.submit(), isNull);
    expect(g.rows.length, 1);
    expect(g.pool.length, lessThan(bank.answers(5).length));
    expect(g.pool, contains('about'));
    expect(g.last, isNotNull);
    expect(g.keyMarks['a'], Mark.present);
    for (final c in 'about'.split('')) {
      g.type(c);
    }
    await g.submit();
    expect(g.done, isTrue);
    expect(g.pool, ['about']);
  });

  testWidgets('a word that is not in the list is not played', (tester) async {
    final bank = await _bank(tester);
    final g = MasterGame(
      bank: bank,
      kind: MasterKind.classic,
      length: 5,
      answer: 'about',
      analyse: false,
    );
    for (final c in 'zzzzz'.split('')) {
      g.type(c);
    }
    expect(await g.submit(), 'not in the word list');
    g.back();
    expect(g.typed.length, 4);
    expect(await g.submit(), 'a word has 5 letters');
  });

  testWidgets('a blind game shows counts, and the pencil follows the rules', (
    tester,
  ) async {
    final bank = await _bank(tester);
    final g = MasterGame(
      bank: bank,
      kind: MasterKind.blind,
      length: 5,
      answer: 'about',
      analyse: false,
    );
    for (final c in 'tares'.split('')) {
      g.type(c);
    }
    await g.submit();
    // about has a and... t: t is in place? no: t is at 3 in about, 0 in tares
    expect(g.rows.single.green + g.rows.single.yellow, 2);
    // a letter the counts cannot settle is the player's to mark
    expect(g.shownAt(0, 0), isNull);
    expect(g.keyChances.containsKey('t'), isTrue);
    final (green, yellow) = g.keyChances['t']!;
    expect(green + yellow, greaterThan(0));
  });

  testWidgets('a mastermind has no word, and its replies always fit one', (
    tester,
  ) async {
    final bank = await _bank(tester);
    final g = MasterGame(
      bank: bank,
      kind: MasterKind.mastermind,
      length: 5,
      seed: 3,
      analyse: false,
    );
    expect(g.answer, isNull);
    for (final c in 'tares'.split('')) {
      g.type(c);
    }
    await g.submit();
    expect(g.pool, isNotEmpty);
    expect(g.rows.single.after, g.pool.length);
  });

  testWidgets('the plot of a guess has one column for each reply', (
    tester,
  ) async {
    final bank = await _bank(tester);
    final g = MasterGame(
      bank: bank,
      kind: MasterKind.classic,
      length: 5,
      answer: 'about',
      analyse: false,
    );
    final p = g.plotOf('tares');
    expect(p.outcomes.length, greaterThan(100));
    final sum = p.outcomes.fold<double>(0, (a, o) => a + o.chance);
    expect(sum, closeTo(1, 1e-9));
    expect(p.sizes!.fold<int>(0, (a, b) => a + b), g.pool.length);
  });
}
