import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backup of a player with some history.
AppState sample() {
  final s = AppState()
    ..lang = 'fr'
    ..length = 6
    ..tries = 4
    ..pool = 6000
    ..helper = Helper.skill
    ..mode = GameMode.relay
    ..share = 25
    ..themeMode = ThemeMode.light
    ..seenHowTo = true;
  s.stats
    ..played = 12
    ..wins = 9
    ..streak = 2
    ..bestStreak = 5
    ..langsWon = {'fr', 'en'}
    ..lengthsWon = {5, 6}
    ..mastery = {
      'fr': {'5:6:1500', '6:4:6000'},
    };
  s.ach['first_light'] = AchState(times: 1, dates: ['2026-10-01']);
  s.ach['wins_10'] = AchState(progress: 4);
  s.ach['mastery'] = AchState(times: 1, dates: ['2026-10-09'], seen: {'fr'});
  return s;
}

Map<String, dynamic> valid() =>
    jsonDecode(backupToText(sample())) as Map<String, dynamic>;

String text(Map<String, dynamic> m) => jsonEncode(m);

void expectRefused(String body, [String? messagePart]) {
  expect(
    () => parseBackup(body),
    throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        messagePart == null ? isNotEmpty : contains(messagePart),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the file', () {
    test('it says what it is, and has everything that is saved', () {
      final m = valid();
      expect(m['app'], 'lexodle');
      expect(m['version'], backupVersion);
      expect(DateTime.tryParse(m['exported'] as String), isNotNull);
      expect(
        (m['settings'] as Map).keys,
        containsAll([
          'lang',
          'length',
          'tries',
          'pool',
          'helper',
          'mode',
          'share',
          'theme',
          'seenHowTo',
        ]),
      );
      expect((m['stats'] as Map)['played'], 12);
      // the achievements that belong to no language, then each language's own
      expect((m['achievements'] as Map).keys, contains('mastery'));
      expect((m['achievements'] as Map).keys, isNot(contains('wins_10')));
      final en = (m['languages'] as Map)[(m['settings'] as Map)['lang']] as Map;
      expect((en['achievements'] as Map).keys, contains('wins_10'));
      expect(en.keys, containsAll(['playstyle', 'daily', 'achievements']));
    });

    test('the name carries the day', () {
      expect(
        backupFileName(DateTime(2026, 10, 18, 23, 59)),
        'lexodle-backup-2026-10-18.json',
      );
    });

    test('it round trips: what is read is what was written', () {
      final b = parseBackup(backupToText(sample()));
      final s = sample();
      expect(b.settings, s.settingsJson());
      expect(b.stats.toJson(), s.stats.toJson());
      expect(
        {
          for (final e in b.achievements.entries) e.key: e.value.toJson(),
          for (final e
              in b.languages![b.settings['lang']]!.achievements.entries)
            e.key: e.value.toJson(),
        },
        {for (final e in s.ach.entries) e.key: e.value.toJson()},
      );
      expect(b.earned, 2, reason: 'two have been earned, one is in progress');
    });
  });

  group('restoring', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('everything comes back, and is saved', () async {
      final source = sample();
      final fresh = AppState();
      await fresh.load();
      final b = parseBackup(backupToText(source));
      fresh.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
      );
      expect(fresh.settingsJson(), source.settingsJson());
      expect(fresh.stats.toJson(), source.stats.toJson());
      expect(fresh.unlockedCount, source.unlockedCount);
      expect(fresh.ach['wins_10']!.progress, 4);
      expect(fresh.ach['mastery']!.seen, {'fr'});

      // it was written to storage, so a restart finds it
      final again = AppState();
      await again.load();
      expect(again.settingsJson(), source.settingsJson());
      expect(again.stats.toJson(), source.stats.toJson());
      expect(again.unlockedCount, source.unlockedCount);
    });

    test(
      'a setting the file lacks keeps its value; stats are replaced',
      () async {
        final s = AppState();
        await s.load();
        s.setup(lang: 'de', length: 7, tries: 3);
        s.stats.played = 50;
        final m = valid()..['settings'] = {'length': 4};
        final b = parseBackup(text(m));
        s.restore(
          settings: b.settings,
          stats: b.stats,
          ach: b.achievements,
          languages: b.languages,
        );
        expect(s.length, 4);
        expect(s.lang, 'de', reason: 'not in the file');
        expect(s.tries, 3);
        expect(s.stats.played, 12, reason: 'the file\'s, not the old 50');
      },
    );

    test('it replaces the achievements as well, not adds to them', () async {
      final s = AppState();
      await s.load();
      s.ach['one_shot'] = AchState(times: 4, dates: ['x']);
      final b = parseBackup(backupToText(sample()));
      s.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
      );
      expect(s.ach.containsKey('one_shot'), isFalse);
    });

    test('listeners are told, so the screens follow', () async {
      final s = AppState();
      await s.load();
      var told = 0;
      s.addListener(() => told++);
      final b = parseBackup(backupToText(sample()));
      s.restore(
        settings: b.settings,
        stats: b.stats,
        ach: b.achievements,
        languages: b.languages,
      );
      expect(told, 1);
    });
  });

  group('a file that is not a backup is refused whole', () {
    test('not json, not an object, not ours', () {
      expectRefused('', 'not a lexodle backup');
      expectRefused('hello', 'not a lexodle backup');
      expectRefused('[1, 2, 3]', 'not a lexodle backup');
      expectRefused('"lexodle"', 'not a lexodle backup');
      expectRefused('{"app": "wordle", "version": 1}', 'not a lexodle backup');
      expectRefused('{"version": 1}', 'not a lexodle backup');
    });

    test('a version it cannot read', () {
      expectRefused(text(valid()..['version'] = 3), 'newer version');
      expectRefused(text(valid()..['version'] = 0), 'damaged');
      expectRefused(text(valid()..['version'] = '1'), 'damaged');
      expectRefused(text(valid()..remove('version')), 'damaged');
    });

    test('too big to be one', () {
      expectRefused('x' * (maxBackupBytes + 1), 'too big');
    });

    test('settings out of range or of the wrong type', () {
      for (final (key, bad) in <(String, Object)>[
        ('length', 3),
        ('length', 9),
        ('length', '5'),
        ('length', 5.5),
        ('tries', 0),
        ('tries', 13),
        ('tries', 'six'),
        ('pool', 1234),
        ('pool', '500'),
        ('pool', -1),
        ('helper', 4),
        ('helper', -1),
        ('helper', 'full'),
        ('mode', 3),
        ('mode', -1),
        ('mode', true),
        ('share', 31),
        ('share', -1),
        ('share', 10.5),
        ('theme', 3),
        ('theme', -1),
        ('theme', 'dark'),
        ('seenHowTo', 1),
        ('seenHowTo', 'yes'),
        ('lang', 5),
        ('lang', ''),
        ('lang', 'a'),
        ('lang', '../../x'),
        ('lang', 'english'),
        ('lang', 'en gb'),
        ('lang', 'en-GB-extra-long-x'),
      ]) {
        final m = valid();
        (m['settings'] as Map)[key] = bad;
        expectRefused(text(m), 'damaged');
      }
      expectRefused(text(valid()..['settings'] = [1]), 'damaged');
      expectRefused(text(valid()..['settings'] = 'x'), 'damaged');
    });

    test('statistics that cannot be real', () {
      for (final (key, bad) in <(String, Object)>[
        ('played', -1), ('played', '12'), ('played', 1000000000),
        ('wins', -3), ('wins', 99), // more wins than games
        ('streak', -1), ('bestStreak', 'x'),
      ]) {
        final m = valid();
        (m['stats'] as Map)[key] = bad;
        expectRefused(text(m));
      }
      expectRefused(text(valid()..['stats'] = 5));
      expectRefused(text(valid()..['stats'] = [1]));
      final m = valid();
      (m['stats'] as Map)['langsWon'] = [1, 2];
      expectRefused(text(m));
      final n = valid();
      (n['stats'] as Map)['mastery'] = {'fr': 'x'};
      expectRefused(text(n));
    });

    test('achievements that cannot be real', () {
      for (final bad in <Object>[
        5,
        'x',
        [1],
        {'times': -1},
        {'times': 'two'},
        {'times': 1, 'dates': 7},
        {'progress': -2},
        {'seen': 'fr'},
        {
          'dates': [1, 2],
        },
      ]) {
        final m = valid();
        (m['achievements'] as Map)['one_shot'] = bad;
        expectRefused(text(m));
      }
      expectRefused(text(valid()..['achievements'] = []));
    });

    test('an achievement this version lacks is dropped, not an error', () {
      final m = valid();
      (m['achievements'] as Map)['from_the_future'] = {'times': 3};
      final code = (m['settings'] as Map)['lang'] as String;
      final en = (m['languages'] as Map)[code] as Map;
      (en['achievements'] as Map)['from_the_past'] = {'times': 3};
      final b = parseBackup(text(m));
      expect(b.achievements.containsKey('from_the_future'), isFalse);
      expect(b.achievements.containsKey('mastery'), isTrue);
      final kept = b.languages![code]!.achievements;
      expect(kept.containsKey('from_the_past'), isFalse);
      expect(kept.containsKey('wins_10'), isTrue);
    });

    test('a file with only some parts is accepted for those parts', () {
      final b = parseBackup(
        '{"app":"lexodle","version":1,"stats":{"played":3,"wins":2}}',
      );
      expect(b.stats.played, 3);
      expect(b.settings, isEmpty);
      expect(b.achievements, isEmpty);
    });

    test('whatever is done to a good file, it is read or refused cleanly', () {
      final good = backupToText(sample());
      final rng = Random(99);
      var refused = 0, read = 0;
      for (var i = 0; i < 600; i++) {
        var t = good;
        switch (i % 4) {
          case 0: // cut it short
            t = t.substring(0, rng.nextInt(t.length));
          case 1: // change a character
            final at = rng.nextInt(t.length);
            t = t.replaceRange(at, at + 1, '{}[]":,0-9az'[rng.nextInt(12)]);
          case 2: // delete a stretch
            final at = rng.nextInt(t.length - 10);
            t = t.replaceRange(at, at + 1 + rng.nextInt(10), '');
          case 3: // repeat a stretch
            final at = rng.nextInt(t.length - 10);
            t = t.replaceRange(at, at, t.substring(at, at + 10));
        }
        try {
          final b = parseBackup(t);
          // read: then it must be usable
          expect(b.stats.wins, lessThanOrEqualTo(b.stats.played));
          read++;
        } on FormatException {
          refused++;
        }
      }
      expect(refused, greaterThan(100));
      expect(read + refused, 600);
    });
  });

  group('in the settings popup', () {
    late _FakeIO io;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'seenHowTo': true});
      io = _FakeIO();
      BackupIO.current = io;
      await appState.load();
      appState.restore(
        settings: const {'lang': 'en', 'length': 5},
        stats: Stats()
          ..played = 3
          ..wins = 1,
        ach: {
          'first_light': AchState(times: 1, dates: ['2026-09-01']),
        },
      );
    });
    tearDown(() => BackupIO.current = FilePickerBackupIO());

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
      await tester.pumpAndSettle();
    }

    Finder byKey(String k) => find.byKey(ValueKey(k));

    testWidgets('download saves a file of everything, named for today', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('backup'), findsOneWidget);
      await tester.tap(byKey('backup-download'));
      await tester.pumpAndSettle();
      expect(io.saved.length, 1);
      expect(io.saved.single.$1, backupFileName(DateTime.now()));
      final b = parseBackup(utf8.decode(io.saved.single.$2));
      expect(b.stats.played, 3);
      expect(
        b.languages!['en']!.achievements.containsKey('first_light'),
        isTrue,
      );
      expect(b.settings['lang'], 'en');
      expect(find.text('backup saved'), findsOneWidget);
    });

    testWidgets('a cancelled save says so, and an error is an error', (
      tester,
    ) async {
      await open(tester);
      io.saveResult = false;
      await tester.tap(byKey('backup-download'));
      await tester.pumpAndSettle();
      expect(find.text('nothing was saved'), findsOneWidget);
      io.saveError = StateError('disk full');
      await tester.tap(byKey('backup-download'));
      await tester.pumpAndSettle();
      expect(find.text('could not save the backup'), findsOneWidget);
    });

    testWidgets('upload asks first, and cancel changes nothing', (
      tester,
    ) async {
      io.toPick = BackupFile(
        'x.json',
        Uint8List.fromList(utf8.encode(backupToText(sample()))),
      );
      await open(tester);
      await tester.tap(byKey('backup-upload'));
      await tester.pumpAndSettle();
      final summary = tester.widget<Text>(byKey('backup-summary')).data!;
      expect(summary, contains('12 games (9 won)'));
      expect(summary, contains('2 achievements'));
      expect(
        summary,
        contains('replaces what is saved here: 3 games, 1 achievement'),
      );
      expect(appState.stats.played, 3, reason: 'nothing replaced yet');

      await tester.tap(byKey('backup-cancel'));
      await tester.pumpAndSettle();
      expect(byKey('backup-summary'), findsNothing);
      expect(appState.stats.played, 3);
      expect(appState.lang, 'en');
    });

    testWidgets('confirming restores everything and the screens follow', (
      tester,
    ) async {
      io.toPick = BackupFile(
        'x.json',
        Uint8List.fromList(utf8.encode(backupToText(sample()))),
      );
      await open(tester);
      await tester.tap(byKey('backup-upload'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('backup-confirm'));
      await tester.pumpAndSettle();
      expect(appState.stats.played, 12);
      expect(appState.lang, 'fr');
      expect(appState.mode, GameMode.relay);
      expect(appState.themeMode, ThemeMode.light);
      expect(appState.ach['mastery']!.seen, {'fr'});
      expect(find.text('restored: 12 games, 2 achievements'), findsOneWidget);
      expect(byKey('backup-summary'), findsNothing);
      // the theme setting changed with it: the popup is now the light theme
      expect(
        Theme.of(tester.element(byKey('backup-download'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('a wrong file says why and changes nothing', (tester) async {
      await open(tester);
      for (final (bytes, message) in <(List<int>, String)>[
        (utf8.encode('hello'), 'that file is not a lexodle backup'),
        (
          utf8.encode('{"app":"lexodle","version":7}'),
          'that backup was made by a newer version of lexodle',
        ),
        (
          utf8.encode(text(valid()..['stats'] = {'played': -1})),
          'that backup is damaged (played)',
        ),
        ([0xff, 0xfe, 0xfa, 0x00, 0x80], 'that file is not a lexodle backup'),
      ]) {
        io.toPick = BackupFile('x.json', Uint8List.fromList(bytes));
        await tester.tap(byKey('backup-upload'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget, reason: message);
        expect(byKey('backup-confirm'), findsNothing);
        expect(appState.stats.played, 3);
      }
    });

    testWidgets(
      'cancelling the picker says nothing; a picker error is reported',
      (tester) async {
        await open(tester);
        io.toPick = null;
        await tester.tap(byKey('backup-upload'));
        await tester.pumpAndSettle();
        expect(byKey('backup-note'), findsNothing);
        io.pickError = StateError('no access');
        await tester.tap(byKey('backup-upload'));
        await tester.pumpAndSettle();
        expect(find.text('could not read that file'), findsOneWidget);
      },
    );

    testWidgets('a new upload forgets the old one waiting for a yes', (
      tester,
    ) async {
      await open(tester);
      io.toPick = BackupFile(
        'x.json',
        Uint8List.fromList(utf8.encode(backupToText(sample()))),
      );
      await tester.tap(byKey('backup-upload'));
      await tester.pumpAndSettle();
      expect(byKey('backup-confirm'), findsOneWidget);
      io.toPick = BackupFile('y.json', Uint8List.fromList(utf8.encode('nope')));
      await tester.tap(byKey('backup-upload'));
      await tester.pumpAndSettle();
      expect(
        byKey('backup-confirm'),
        findsNothing,
        reason: 'cannot confirm the old one',
      );
      expect(appState.stats.played, 3);
    });
  });
}

class _FakeIO implements BackupIO {
  final saved = <(String, Uint8List)>[];
  bool saveResult = true;
  Object? saveError;
  BackupFile? toPick;
  Object? pickError;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (saveError != null) throw saveError!;
    saved.add((fileName, bytes));
    return saveResult;
  }

  @override
  Future<BackupFile?> pick() async {
    if (pickError != null) throw pickError!;
    return toPick;
  }
}
