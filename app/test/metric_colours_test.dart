import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/analysis.dart';
import 'package:lexodle/backup.dart';
import 'package:lexodle/history.dart';
import 'package:lexodle/history_page.dart';
import 'package:lexodle/logic.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/modes.dart';
import 'package:lexodle/period_chart.dart';
import 'package:lexodle/playstyle.dart';
import 'package:lexodle/playstyle_card.dart';
import 'package:lexodle/review.dart';
import 'package:lexodle/routes.dart';
import 'package:lexodle/store.dart';
import 'package:lexodle/ui.dart';
import 'package:lexodle/words.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_of.dart';

/// A colour without its alpha, to compare shades that a row dims.
int rgb(Color c) => c.toARGB32() & 0xFFFFFF;

GuessMetrics gm(
  String g,
  double skill,
  double luck,
  int before,
  int after, {
  double? risk = 40,
  int triesLeft = 3,
}) => GuessMetrics(
  guess: g,
  skill: skill,
  luck: luck,
  before: before,
  after: after,
  expected: 1,
  groups: 1,
  largest: 1,
  risk: risk,
  triesLeft: triesLeft,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the three colours', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      test('${b.name}: skill, luck and risk are three different colours', () {
        final c = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: b);
        final all = {rgb(skillColor(c)), rgb(luckColor(c)), rgb(riskColor(c))};
        expect(all, hasLength(3));
        expect(metricColor(c, 'skill'), skillColor(c));
        expect(metricColor(c, 'luck'), luckColor(c));
        expect(metricColor(c, 'risk'), riskColor(c));
      });
    }

    test('the black theme uses the dark shades', () {
      final dark = buildTheme(Brightness.dark).colorScheme;
      final black = buildTheme(Brightness.dark, black: true).colorScheme;
      expect(skillColor(black), skillColor(dark));
      expect(luckColor(black), luckColor(dark));
      expect(riskColor(black), riskColor(dark));
    });

    test('each reads on the page of every theme', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (la > lb ? la + .05 : lb + .05) /
            (la > lb ? lb + .05 : la + .05);
      }

      for (final t in [
        buildTheme(Brightness.light),
        buildTheme(Brightness.dark),
        buildTheme(Brightness.dark, black: true),
      ]) {
        final c = t.colorScheme;
        for (final k in [skillColor(c), luckColor(c), riskColor(c)]) {
          expect(contrast(k, c.surface), greaterThanOrEqualTo(3));
        }
      }
    });
  });

  group('the review', () {
    late WordBank bank;
    late List<String> pool;

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      );
      pool = bank.guessable(4);
    });

    GameRecord record(
      List<GuessMetrics> metrics, {
      List<int>? sizes,
      bool won = true,
    }) {
      final n = metrics.length;
      final answer = pool[3];
      final sz = sizes ?? [for (var i = 0; i < n; i++) 40 - i * 10];
      return GameRecord(
        bank: bank,
        length: 4,
        poolSize: 500,
        answer: answer,
        guesses: [for (var i = 0; i < n; i++) metrics[i].guess],
        marks: [for (var i = 0; i < n; i++) evaluate(answer, metrics[i].guess)],
        metrics: metrics,
        befores: [for (final s in sz) pool.take(s).toList()],
        finalEligible: [answer],
        won: won,
        tries: 6,
      );
    }

    Future<void> open(
      WidgetTester tester,
      GameRecord r, {
      int step = 0,
      Brightness b = Brightness.dark,
      bool settle = true,
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(b),
          home: ReviewPage(record: r, initialStep: step),
        ),
      );
      if (settle) await tester.pump(const Duration(seconds: 40));
    }

    List<GuessMetrics> three({
      double l0 = 40,
      double l1 = -30,
      double l2 = 0,
    }) => [
      gm(pool[10], 80, l0, 40, 20, risk: 10, triesLeft: 5),
      gm(pool[11], 60, l1, 20, 8, risk: 50, triesLeft: 4),
      gm(pool[3], 30, l2, 8, 1, risk: 90, triesLeft: 3),
    ];

    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets(
        '${b.name}: the four pills carry the four colours, the sign carries luck',
        (tester) async {
          await open(tester, record(three()), step: 0, b: b, settle: false);
          final c = Theme.of(tester.element(find.byType(ReviewPage)))
              .colorScheme;
          for (final (k, color) in [
            ('skill', skillColor(c)),
            ('luck', luckColor(c)),
            ('risk', riskColor(c)),
            ('bits', bitsColor(c)),
          ]) {
            final t = tester.widget<Text>(
              find.byKey(ValueKey('pill-value-$k')),
            );
            expect(rgb(t.style!.color!), rgb(color), reason: k);
          }
          expect(
            textOf(
              tester.widget<Text>(
                find.byKey(const ValueKey('pill-value-luck')),
              ),
            ),
            '+40',
          );
          await tester.pump(const Duration(seconds: 40));
        },
      );
    }

    testWidgets('the table: header words and numbers carry the colours', (
      tester,
    ) async {
      await open(tester, record(three()), step: 2, settle: false);
      final c = Theme.of(tester.element(find.byType(ReviewPage))).colorScheme;
      Color head(String h) =>
          tester.widget<Text>(find.byKey(ValueKey('head-$h'))).style!.color!;
      expect(head('skill'), skillColor(c));
      expect(head('risk'), riskColor(c));
      for (var i = 0; i < 3; i++) {
        for (final (k, color) in [
          ('skill', skillColor(c)),
          ('risk', riskColor(c)),
        ]) {
          final t = tester.widget<Text>(find.byKey(ValueKey('$k-$i')));
          expect(rgb(t.style!.color!), rgb(color), reason: '$k row $i');
        }
      }
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets('a pill explains itself with its term in its colour', (
      tester,
    ) async {
      await open(tester, record(three()), step: 1);
      final c = Theme.of(tester.element(find.byType(ReviewPage))).colorScheme;
      for (final (k, color) in [
        ('skill', skillColor(c)),
        ('luck', luckColor(c)),
        ('risk', riskColor(c)),
      ]) {
        await tester.tap(find.byKey(ValueKey('pill-$k')));
        await tester.pumpAndSettle();
        final spans = <TextSpan>[];
        for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
          w.text.visitChildren((s) {
            if (s is TextSpan && s.text == k && s.style?.color == color) {
              spans.add(s);
            }
            return true;
          });
        }
        expect(spans, isNotEmpty, reason: k);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
      }
    });
  });

  group('the playstyle card', () {
    late WordBank bank;

    History played(double luck) {
      final pool = bank.answers(4);
      final h = History();
      for (var i = 0; i < 12; i++) {
        h.add(
          at: DateTime(2026, 10, 1 + i).millisecondsSinceEpoch,
          lang: 'fr',
          mode: GameMode.classic,
          length: 4,
          tries: 6,
          pool: 500,
          answers: [pool[10]],
          won: true,
          guesses: [
            for (var k = 0; k < 3; k++)
              GuessRow(
                game: 0,
                n: k,
                word: pool[k + 1],
                skill: 80,
                luck: luck,
                risk: 30,
                before: 50,
                after: 20,
              ),
          ],
        );
      }
      return h;
    }

    Future<void> show(WidgetTester tester, History h) async {
      await tester.binding.setSurfaceSize(const Size(420, 1900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await appState.load();
      appState.lang = 'fr';
      appState.history = h;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: appState,
                builder: (context, _) => PlaystyleCard('fr'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUpAll(() async {
      bank = await WordBank.load(
        (await WordBank.languages()).firstWhere((l) => l.code == 'fr'),
      );
    });

    setUp(() => SharedPreferences.setMockInitialValues({'seenHowTo': true}));

    testWidgets('it shows the average luck, as luckText writes it', (
      tester,
    ) async {
      await show(tester, played(20));
      final t = tester.widget<Text>(find.byKey(const ValueKey('stat-luck')));
      expect(textOf(t), luckText(20));
      expect(textOf(t), '+20%');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile')),
          matching: find.byKey(const ValueKey('stat-luck')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a negative luck has the minus sign and the same colour', (
      tester,
    ) async {
      await show(tester, played(-20));
      final t = tester.widget<Text>(find.byKey(const ValueKey('stat-luck')));
      expect(textOf(t), '−20%');
      final c = Theme.of(tester.element(find.byType(PlaystyleCard)))
          .colorScheme;
      expect(t.style!.color, luckColor(c));
    });

    testWidgets('skill, luck and risk there have the three colours', (
      tester,
    ) async {
      await show(tester, played(20));
      final c = Theme.of(tester.element(find.byType(PlaystyleCard)))
          .colorScheme;
      Color of(String k) =>
          tester.widget<Text>(find.byKey(ValueKey('stat-$k'))).style!.color!;
      expect(of('skill'), skillColor(c));
      expect(of('luck'), luckColor(c));
      expect(of('risk'), riskColor(c));
      // and their labels
      for (final (k, color) in [
        ('skill', skillColor(c)),
        ('luck', luckColor(c)),
        ('risk', riskColor(c)),
      ]) {
        final label = find.descendant(
          of: find.byKey(const ValueKey('profile')),
          matching: find.text(k),
        );
        expect(label, findsOneWidget, reason: k);
        expect(tester.widget<Text>(label).style!.color, color, reason: k);
      }
    });

    test('the traits carry the mean luck', () async {
      final t = traitsOf(played(-20), lang: 'fr')!;
      expect(t.luck, closeTo(-20, 1e-9));
    });

    testWidgets('the trend lines use the three colours too', (tester) async {
      await show(tester, played(20));
      final c = Theme.of(tester.element(find.byType(PlaystyleCard)))
          .colorScheme;
      final colours = seriesColors(c);
      expect(colours[PeriodSeries.skill], skillColor(c));
      expect(colours[PeriodSeries.luck], luckColor(c));
      expect(colours[PeriodSeries.risk], riskColor(c));
    });
  });

  group('the black theme', () {
    const black = Color(0xFF000000);

    test(
      'a black scaffold, surfaces, cards, dialogs and bars on the dark scheme',
      () {
        final t = buildTheme(Brightness.dark, black: true);
        expect(t.brightness, Brightness.dark);
        expect(t.scaffoldBackgroundColor, black);
        expect(t.colorScheme.surface, black);
        expect(t.colorScheme.surfaceContainer, black);
        expect(t.cardColor, black);
        expect(t.dialogTheme.backgroundColor, black);
        expect(t.appBarTheme.backgroundColor, black);
        // dark in every other respect: the same accent colours as the dark one
        final dark = buildTheme(Brightness.dark);
        expect(t.colorScheme.primary, dark.colorScheme.primary);
        expect(t.colorScheme.onSurface, dark.colorScheme.onSurface);
        expect(dark.scaffoldBackgroundColor, isNot(black));
      },
    );

    test('the lines stay legible on it', () {
      final c = buildTheme(Brightness.dark, black: true).colorScheme;
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (la > lb ? la + .05 : lb + .05) /
            (la > lb ? lb + .05 : la + .05);
      }

      expect(contrast(c.onSurface, c.surface), greaterThanOrEqualTo(7));
      expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
      expect(contrast(c.outlineVariant, c.surface), greaterThanOrEqualTo(1.5));
    });

    testWidgets('a dialog and a card on it are black', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark, black: true),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Card(child: Text('a card'))),
        ),
      );
      Color? material(Finder f) => tester
          .widget<Material>(
            find.descendant(of: f, matching: find.byType(Material)).first,
          )
          .color;
      final ctx = tester.element(find.text('a card'));
      expect(Theme.of(ctx).scaffoldBackgroundColor, black);
      expect(
        tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.text('a card'),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        black,
      );
      showDialog<void>(
        context: ctx,
        builder: (_) => const AlertDialog(title: Text('a dialog')),
      );
      await tester.pumpAndSettle();
      expect(material(find.byType(AlertDialog)) ?? black, black);
      expect(
        Theme.of(tester.element(find.text('a dialog')))
            .dialogTheme
            .backgroundColor,
        black,
      );
    });

    group('the setting', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({'seenHowTo': true});
        await appState.load();
        appState.setup(themeMode: ThemeMode.system);
      });

      testWidgets('the settings show four options, black the fourth', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(420, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
        await tester.pumpAndSettle();
        // the theme choice is a stepper with its values in order
        for (final label in ['system', 'light', 'dark', 'black']) {
          appState.setup(
            themeMode: switch (label) {
              'system' => ThemeMode.system,
              'light' => ThemeMode.light,
              _ => ThemeMode.dark,
            },
            black: label == 'black',
          );
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(appState.themeIndex, 3);
      });

      testWidgets('choosing black paints the app black', (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const LexodleApp(initialRoute: '/settings'));
        await tester.pumpAndSettle();
        appState.setup(themeMode: ThemeMode.dark, black: true);
        await tester.pumpAndSettle();
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final ctx = tester.element(find.byType(Scaffold).first);
        expect(Theme.of(ctx).scaffoldBackgroundColor, black);
        expect(scaffold.backgroundColor, anyOf(isNull, black));
        // light and dark are not black
        appState.setup(themeMode: ThemeMode.dark);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).first))
              .scaffoldBackgroundColor,
          isNot(black),
        );
        expect(appState.blackTheme, isFalse);
      });

      test('it is stored as 3, and read back', () async {
        appState.setup(themeMode: ThemeMode.dark, black: true);
        final p = await SharedPreferences.getInstance();
        expect(p.getInt('theme'), 3);
        expect(appState.themeIndex, 3);
        appState.setup(themeMode: ThemeMode.system);
        appState.setup(themeMode: ThemeMode.light);
        expect(appState.blackTheme, isFalse);
        SharedPreferences.setMockInitialValues({'theme': 3});
        await appState.load();
        expect(appState.blackTheme, isTrue);
        expect(appState.themeMode, ThemeMode.dark);
        expect(appState.themeIndex, 3);
      });

      test('the old values keep their places', () async {
        for (final (i, mode) in [
          (0, ThemeMode.system),
          (1, ThemeMode.light),
          (2, ThemeMode.dark),
        ]) {
          SharedPreferences.setMockInitialValues({'theme': i});
          await appState.load();
          expect(appState.themeMode, mode, reason: '$i');
          expect(appState.blackTheme, isFalse, reason: '$i');
          expect(appState.themeIndex, i);
        }
        SharedPreferences.setMockInitialValues({'theme': 4});
        await appState.load();
        expect(appState.themeIndex, isNot(4));
      });

      test('a backup with black restores it', () async {
        final s = AppState()
          ..themeMode = ThemeMode.dark
          ..blackTheme = true;
        final text = backupToText(s);
        expect((jsonDecode(text)['settings'] as Map)['theme'], 3);
        final b = parseBackup(text);
        expect(b.settings['theme'], 3);
        appState.setup(themeMode: ThemeMode.light);
        appState.restore(
          settings: b.settings,
          stats: b.stats,
          ach: b.achievements,
        );
        expect(appState.blackTheme, isTrue);
        expect(appState.themeMode, ThemeMode.dark);
        final p = await SharedPreferences.getInstance();
        expect(p.getInt('theme'), 3);
        // and 4 is refused
        final bad = jsonDecode(text) as Map<String, dynamic>;
        (bad['settings'] as Map)['theme'] = 4;
        expect(() => parseBackup(jsonEncode(bad)), throwsFormatException);
      });
    });
  });
}
