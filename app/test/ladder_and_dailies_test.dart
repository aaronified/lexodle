import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/ladder.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/my_dailies.dart';

void main() {
  group('the ladder', () {
    test('is in order, and every mode but classic opens once', () {
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].games, greaterThan(ladder[i - 1].games));
      }
      final opened = [
        for (final s in ladder)
          if (s.mode != null) s.mode!,
      ];
      expect(opened.toSet().length, opened.length);
      expect(opened, isNot(contains(GameMode.classic)));
      expect(opened.length, GameMode.values.length - 1);
    });

    test('classic is open from the first game, the others as scheduled', () {
      expect(isOpen(GameMode.classic, 0), isTrue);
      expect(isOpen(GameMode.classic, 1), isTrue);
      expect(isOpen(GameMode.quartet, 3), isFalse);
      expect(isOpen(GameMode.quartet, 4), isTrue);
      expect(gamesToOpen(GameMode.themed), 22);
    });

    test('a veteran has every mode open', () {
      expect(openModes(1, veteran: true), GameMode.values);
      expect(openModes(1), [GameMode.classic]);
    });

    test('what opens now and what comes next', () {
      expect(justOpened(4).single.mode, GameMode.quartet);
      expect(justOpened(6).single.name, 'every mode');
      expect(justOpened(6).single.mode, isNull);
      expect(justOpened(8), isEmpty);
      expect(justOpened(24).single.name, 'learn');
      expect(nextStep(4)!.games, 5);
      expect(nextStep(5)!.name, 'every mode');
      expect(nextStep(22)!.name, 'learn');
      expect(nextStep(24), isNull);
    });

    test('the two feature steps open no mode', () {
      expect(gamesToOpen(GameMode.lockdown), 7);
      expect(isOpen(GameMode.lockdown, 6), isFalse);
      expect(openModes(6), openModes(5));
    });
  });

  group('my dailies', () {
    test('a new player has classic, and one daily always stays', () {
      final d = MyDailies();
      expect(d.of('en'), [GameMode.classic]);
      expect(d.remove('en', GameMode.classic), isFalse);
      expect(d.add('en', GameMode.quartet), isTrue);
      expect(d.add('en', GameMode.quartet), isFalse);
      expect(d.remove('en', GameMode.classic), isTrue);
      expect(d.of('en'), [GameMode.quartet]);
    });

    test('each language has its own choice', () {
      final d = MyDailies()..add('en', GameMode.blind);
      expect(d.of('fr'), [GameMode.classic]);
      expect(d.has('en', GameMode.blind), isTrue);
    });

    test(
      'a veteran starts from the streaks, or classic when there are none',
      () {
        final d = MyDailies()
          ..startFrom('en', [GameMode.lockdown, GameMode.quartet]);
        expect(d.of('en'), [GameMode.quartet, GameMode.lockdown]);
        d.startFrom('fr', const []);
        expect(d.of('fr'), [GameMode.classic]);
        expect(d.decided('fr'), isTrue);
        expect(MyDailies().decided('de'), isFalse);
      },
    );

    test('round trips through json, and a damaged entry is skipped', () {
      final d = MyDailies()
        ..add('en', GameMode.relay)
        ..add('en', GameMode.mastermind);
      final back = MyDailies.fromJson(d.toJson());
      expect(back.of('en'), d.of('en'));
      final bad = MyDailies.fromJson({
        'en': [99, 'x'],
        'fr': [1],
        3: [0],
        'de': 'nope',
      });
      expect(bad.of('en'), [GameMode.classic]);
      expect(bad.of('fr'), [GameMode.quartet]);
      expect(MyDailies.fromJson(null).of('en'), [GameMode.classic]);
    });
  });
}
