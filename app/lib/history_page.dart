import 'equations.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import 'analysis.dart';
import 'app_log.dart';
import 'daily.dart';
import 'earned_rows.dart';
import 'geography.dart';
import 'game_timer.dart' show formatElapsed;
import 'history.dart';
import 'logic.dart';
import 'language_picker.dart';
import 'mode_filter.dart';
import 'main.dart';
import 'modes.dart';
import 'period_chart.dart';
import 'edge_fade.dart';
import 'mode_wheel.dart' show modeIconName;
import 'playstyle.dart' show classify, habitsOfGames, hasPlaystyle;
import 'playstyle_card.dart' show StatTile, hairlineCard, shadeUp;
import 'puzzle.dart';
import 'replay.dart';
import 'routes.dart';
import 'share_puzzle.dart';
import 'store.dart' show earnedFrom;
import 'settings_button.dart';
import 'ui.dart';
import 'words.dart';

/// How many games the list shows at first, and how many more each press adds.
/// There can be thousands, so the rest are loaded as they are asked for.
const historyPageSize = 10;

/// The player's history: an analysis
/// of every game (overall, and week by week and month by month over the last 50
/// of each), then the games, newest first, ten at a time. A game opens its
/// review, rebuilt from the guesses. Games saved under an older version of the
/// maths are scored again, newest first, while the page is open.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  var _langs = <String, Language>{};
  int _done = 0, _total = 0;
  bool _opening = false;
  String _error = '';

  /// How many of the newest games the list shows.
  int _shown = historyPageSize;

  /// The language the page is about: each has its own games, playstyle and
  /// calendar. The one being played to begin with.
  String _lang = appState.lang;

  /// The mode the page is limited to (null: all of them).
  GameMode? _mode;

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((ls) {
      if (!mounted) return;
      setState(() => _langs = {for (final l in ls) l.code: l});
      _rescore();
    });
  }

  /// Scores again, in the background, any game saved under older maths. There
  /// can be thousands, so it saves as it goes and can be left and picked up
  /// again: what is done stays done.
  Future<void> _rescore() async {
    final total = appState.history.stale().length;
    if (total == 0) return;
    setState(() {
      _done = 0;
      _total = total;
    });
    await rescoreStale(
      appState.history,
      (code) async {
        final l = _langs[code];
        return l == null ? null : WordBank.load(l);
      },
      onEach: (done, total) {
        if (done % 20 == 0) appState.saveHistory();
        if (mounted) setState(() => _done = done);
      },
      cancelled: () => !mounted,
    );
    // the numbers moved, so each language's playstyle is read again from them
    appState.saveHistory();
    for (final l in appState.playedLanguages) {
      for (final m in GameMode.values) {
        appState.updateStyle(lang: l, mode: m);
      }
    }
    appState.refresh();
    if (mounted) setState(() => _total = 0);
  }

  Future<void> _open(GameRow g) async {
    final lang = _langs[g.lang];
    if (lang == null || _opening) return;
    // (a practice game timed out before any guess has nothing to review)
    if (appState.history.guessesOf(g.id).isEmpty) return;
    setState(() {
      _opening = true;
      _error = '';
    });
    try {
      final bank = g.mode == GameMode.themed
          ? await Geography.load(lang)
          : g.mode == GameMode.equations
          ? await Equations.load(lang)
          : await WordBank.load(lang);
      final rows = appState.history.guessesOf(g.id);
      final record = !g.mode.multi
          ? replayClassic(bank, g, rows)
          : replayMulti(bank, g, rows);
      if (!mounted) return;
      await Navigator.pushNamed(context, Routes.review, arguments: record);
    } catch (_) {
      if (mounted) setState(() => _error = 'could not rebuild that game');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('history'),
        actions: [const SettingsButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                final h = appState.history;
                // the games of the language in view, oldest first
                final mine = [
                  for (final g in h.games)
                    if (g.lang == _lang && (_mode == null || g.mode == _mode))
                      g,
                ];
                final total = mine.length;
                final shown = min(_shown, total);
                final more = total - shown;
                // the cards, the note about the games, then the games (built
                // as they scroll into view), then the button for more
                const fixed = 5;
                return Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
                      itemCount: fixed + shown + (more > 0 ? 1 : 0),
                      itemBuilder: (context, row) {
                        final i = row;
                        // (these are not const: a const widget is not rebuilt
                        // when this builder runs, and they must follow the
                        // history as it changes, after games are scored again)
                        // ignore: prefer_const_constructors
                        if (i == 0) {
                          return _Block(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EdgeFade(
                                  key: const ValueKey('lang-fade'),
                                  child: LanguagePicker(
                                    // (a language only practised is in the list)
                                    codes: {
                                      ...appState.playedLanguages,
                                      for (final g in h.games) g.lang,
                                    }.toList()..sort(),
                                    languages: _langs,
                                    selected: _lang,
                                    onSelect: (code) => setState(() {
                                      _lang = code;
                                      _shown = historyPageSize;
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ModeFilter(
                                  selected: _mode,
                                  onSelect: (m) => setState(() {
                                    _mode = m;
                                    _shown = historyPageSize;
                                  }),
                                ),
                              ],
                            ),
                          );
                        }
                        // ignore: prefer_const_constructors
                        if (i == 1) return _Block(_Overall(_lang, _mode));
                        if (i == 3) {
                          return _Block(_PlaystyleRow(_lang, _mode));
                        }
                        if (i == 2) {
                          return _Block(
                            _Trend(
                              _lang,
                              _mode,
                              key: ValueKey('trend-$_lang-${_mode?.name}'),
                            ),
                          );
                        }
                        if (i == 4) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_total > 0) ...[
                                  Caption(
                                    'scoring $_done of $_total older games '
                                    'again with the current maths…',
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Caption(
                                  total == 0
                                      ? 'no games yet'
                                      : 'your games, newest first',
                                ),
                                if (_error.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _error,
                                    style: TextStyle(color: c.error),
                                  ),
                                ],
                                if (total == 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'finish a game and it will be here, to '
                                      'look back on step by step.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.onSurface.withValues(
                                          alpha: dimAlpha,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                        final k = row - fixed;
                        if (k < shown) {
                          // newest first: the list is the history read backwards
                          final g = mine[total - 1 - k];
                          return _GameTile(
                            key: ValueKey('game-${g.id}'),
                            game: g,
                            language: _langs[g.lang],
                            onTap: () => _open(g),
                          );
                        }
                        final next = min(historyPageSize, more);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Material(
                            color: shadeUp(c),
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              key: const ValueKey('load-more'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: () =>
                                  setState(() => _shown += historyPageSize),
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: Center(
                                  child: Text('load $next more · $more left'),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_opening)
                      const Positioned.fill(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A card's place in the list: the space under it.
class _Block extends StatelessWidget {
  const _Block(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 18), child: child);
}

/// Every game kept, added up: always there, however many there are.
class _Overall extends StatelessWidget {
  const _Overall(this.lang, this.mode);

  /// The language it adds up, and the mode (null: all of them).
  final String lang;
  final GameMode? mode;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final h = appState.history;
    final s = summarise(h, [
      for (final g in h.scoredGames)
        if (g.lang == lang && (mode == null || g.mode == mode)) g,
    ]);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    String whole(double? v) => v == null ? '–' : v.round().toString();
    // the mode with the most games, and how many of the games are in it
    final games = [
      for (final g in h.scoredGames)
        if (g.lang == lang && (mode == null || g.mode == mode)) g,
    ];
    final counts = <GameMode, int>{};
    for (final g in games) {
      counts[g.mode] = (counts[g.mode] ?? 0) + 1;
    }
    GameMode? top;
    for (final e in counts.entries) {
      if (top == null || e.value > counts[top]!) top = e.key;
    }
    return hairlineCard(
      context,
      key: const ValueKey('overall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption(mode == null ? 'overall' : 'overall · ${mode!.label}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              StatTile('games', '${s.games}', prefix: 'overall'),
              StatTile(
                'won',
                s.games == 0 ? '–' : '${s.winRate.round()}%',
                prefix: 'overall',
              ),
              StatTile(
                'skill',
                whole(s.scored == 0 ? null : s.skill),
                prefix: 'overall',
              ),
              StatTile('risk', whole(s.risk), prefix: 'overall'),
            ],
          ),
          const SizedBox(height: 8),
          s.games == 0 || top == null
              ? Text(
                  'nothing to add up yet',
                  key: const ValueKey('overall-line'),
                  style: dim,
                )
              : Text.rich(
                  TextSpan(
                    children: [
                      metricSpan(
                        c,
                        'luck ${s.scored == 0 ? '–' : luckText(s.luck)}',
                        'luck',
                      ),
                      TextSpan(
                        text:
                            ' · ${s.meanTries == null ? '–' : s.meanTries!.toStringAsFixed(1)}'
                            ' guesses · ',
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: TablerIcon(
                          modeIconName(top),
                          key: const ValueKey('overall-mode-icon'),
                          size: 14,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                      TextSpan(text: ' ${counts[top]}/${s.games}'),
                    ],
                  ),
                  key: const ValueKey('overall-line'),
                  style: dim,
                ),
          if (s.stale > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${s.stale} ${s.stale == 1 ? 'game' : 'games'} saved under '
              'older maths ${s.stale == 1 ? 'is' : 'are'} left out of skill, '
              'luck and risk until scored again',
              key: const ValueKey('overall-stale'),
              style: dim,
            ),
          ],
        ],
      ),
    );
  }
}

/// The playstyle of the language and mode in view, as a card of its own under
/// the plot: its icon, name and a chevron. It opens the playstyle screen.
class _PlaystyleRow extends StatelessWidget {
  const _PlaystyleRow(this.lang, this.mode);
  final String lang;
  final GameMode? mode;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final h = appState.history;
    final p = mode == null
        ? classify(habitsOfGames(h, h.recent(null, 100, lang)))
        : hasPlaystyle(mode!)
        ? appState.styleOf(lang, mode!)
        : null;
    return Material(
      color: c.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: hairline(c),
      ),
      child: InkWell(
        key: const ValueKey('playstyle-row'),
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          try {
            Navigator.pushNamed(context, Routes.playstyle);
          } catch (e) {
            appLog.w('history', 'playstyle: ${e.runtimeType}');
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TablerIcon(
                  p?.icon ?? 'puzzle',
                  size: 44,
                  color: p == null
                      ? c.onSurface.withValues(alpha: dimAlpha)
                      : behaviourColor(c, p.early.label),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p?.name ?? 'not rated yet',
                        key: const ValueKey('playstyle-row-name'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'your playstyle',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The range of the trend plot.
enum _Range { days, weeks, months }

/// The last [count] local days, oldest first, the last of them [today]: a
/// period for each day, empty when nothing was played (a gap in the plot). Games
/// dated after [today] are counted in the last. The label, start and end are
/// the date itself.
List<Period> dailyPeriods(
  History h,
  String today, {
  int count = 50,
  String? lang,
  GameMode? mode,
}) {
  final byDate = <String, List<GameRow>>{};
  for (final g in h.scoredGames) {
    if (lang != null && g.lang != lang) continue;
    if (mode != null && g.mode != mode) continue;
    var d = dailyDate(DateTime.fromMillisecondsSinceEpoch(g.at, isUtc: true));
    if (d.compareTo(today) > 0) d = today;
    byDate.putIfAbsent(d, () => []).add(g);
  }
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final d = dailyShift(today, -i);
        final games = byDate[d] ?? const <GameRow>[];
        return Period(
          label: d,
          start: d,
          end: d,
          stats: summarise(h, games),
          style: classify(
            habitsOfGames(h, [
              for (final g in games)
                if (hasPlaystyle(g.mode)) g,
            ]),
          ),
        );
      }(),
  ];
}

/// How play changed over time: a bar for each of the last 50 days, weeks or months,
/// for skill, risk, share won or games, and what was in the one picked.
class _Trend extends StatefulWidget {
  const _Trend(this.lang, this.mode, {super.key});

  /// The language whose periods it draws, and the mode (null: all of them).
  final String lang;
  final GameMode? mode;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  _Range _range = _Range.weeks;

  /// The lines drawn: all three to begin with.
  final _shown = <PeriodSeries>{...PeriodSeries.values};

  /// The period picked (null: the last, which is the one running now).
  int? _picked;

  // working the periods out reads every game, so it is done again only when the
  // history, the day or the choice of days, weeks or months has changed
  List<Period>? _periods;
  Object? _key;

  List<Period> _periodsNow() {
    final h = appState.history;
    final today = dailyDate();
    final key = (
      h.scoredGames.length,
      h.scoredGames.isEmpty ? -1 : h.scoredGames.last.id,
      h.stale().length,
      _range,
      today,
      widget.lang,
      widget.mode,
    );
    if (_periods == null || _key != key) {
      _periods = switch (_range) {
        _Range.days => dailyPeriods(
          h,
          today,
          lang: widget.lang,
          mode: widget.mode,
        ),
        _Range.weeks => weeklyPeriods(
          h,
          today,
          lang: widget.lang,
          mode: widget.mode,
        ),
        _Range.months => monthlyPeriods(
          h,
          today,
          lang: widget.lang,
          mode: widget.mode,
        ),
      };
      _key = key;
    }
    return _periods!;
  }

  void _setRange(_Range range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final periods = _periodsNow();
    final sel = (_picked ?? periods.length - 1).clamp(0, periods.length - 1);
    final p = periods[sel];
    final unit = _range.name.substring(0, _range.name.length - 1);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );

    // for each line drawn, the change on the last period before this one that
    // had something to show
    final changes = <PeriodSeries, String>{};
    for (final series in PeriodSeries.values) {
      if (!_shown.contains(series)) continue;
      final now = series.of(p.stats);
      if (now == null) continue;
      for (var j = sel - 1; j >= 0; j--) {
        final before = series.of(periods[j].stats);
        if (before == null) continue;
        final d = (now - before).round();
        changes[series] = d == 0
            ? 'no change'
            : '${d > 0 ? '+' : '−'}${d.abs()}'
                  '${series == PeriodSeries.luck ? '%' : ''}';
        break;
      }
    }

    final s = p.stats;
    String whole(double? v) => v == null ? '–' : v.round().toString();
    return hairlineCard(
      context,
      key: const ValueKey('trend'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Caption('the last ${periods.length} ${unit}s')),
              for (final (i, r) in _Range.values.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                _Choice(
                  r.name,
                  selected: _range == r,
                  onTap: () => _setRange(r),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          PeriodChart(
            periods: periods,
            shown: _shown,
            selected: sel,
            onSelect: (i) => setState(() => _picked = i),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 26),
              Text(periods.first.label, style: dim.copyWith(fontSize: 9)),
              const Spacer(),
              Text('now', style: dim.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          // the legend, which also switches each line on and off; luck is drawn
          // about the middle line, which is a luck of 0%
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final series in PeriodSeries.values)
                _Choice(
                  switch (series) {
                    PeriodSeries.luck => 'luck (50 = 0%)',
                    _ => series.label,
                  },
                  key: ValueKey('series-${series.name}'),
                  selected: _shown.contains(series),
                  color: seriesColors(c)[series],
                  onTap: () => setState(() {
                    if (!_shown.remove(series)) _shown.add(series);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _range == _Range.weeks ? '${p.start} to ${p.end}' : p.label,
            key: const ValueKey('period-label'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text.rich(
            s.isEmpty
                ? const TextSpan(text: 'no games')
                : TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${s.games} ${s.games == 1 ? 'game' : 'games'} · '
                            '${s.winRate.round()}% won · ',
                      ),
                      metricSpan(
                        c,
                        'skill ${whole(s.scored == 0 ? null : s.skill)}',
                        'skill',
                      ),
                      const TextSpan(text: ' · '),
                      metricSpan(c, 'risk ${whole(s.risk)}', 'risk'),
                      const TextSpan(text: ' · '),
                      metricSpan(
                        c,
                        'luck ${s.scored == 0 ? '–' : luckText(s.luck)}',
                        'luck',
                      ),
                    ],
                  ),
            key: const ValueKey('period-detail'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  for (final (i, e) in changes.entries.indexed) ...[
                    if (i > 0) const TextSpan(text: ' · '),
                    metricSpan(c, '${e.key.label} ${e.value}', e.key.label),
                  ],
                  TextSpan(text: ' on the last $unit you played'),
                ],
              ),
              key: const ValueKey('period-change'),
              style: dim,
            ),
          ],
        ],
      ),
    );
  }
}

/// A small switch of the trend card.
class _Choice extends StatelessWidget {
  const _Choice(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A line's colour, shown as a swatch before the name (for the legend).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.secondaryContainer : c.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                Container(
                  width: 10,
                  height: 3,
                  color: selected ? color : c.outlineVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? c.onSecondaryContainer
                      : c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// One game of the list.
class _GameTile extends StatelessWidget {
  const _GameTile({
    super.key,
    required this.game,
    required this.language,
    required this.onTap,
  });
  final GameRow game;
  final Language? language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final rows = appState.history.guessesOf(game.id);
    // a classic guess with one word left has no skill to speak of
    final scored = [
      for (final r in rows)
        if (!game.isClassic || r.before > 1) r.skill,
    ];
    final skill = scored.isEmpty
        ? '–'
        : (scored.reduce((a, b) => a + b) / scored.length).round().toString();
    final tag = [
      if (game.isDaily) 'daily',
      if (game.mode != GameMode.classic) game.mode.label,
    ].join(' · ');
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: c.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: hairline(c),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                FlagBadge(language?.flag ?? '', size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.isEmpty
                            ? _date(game.at)
                            : '${_date(game.at)} · $tag',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.answers.join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dim,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      [
                        game.won
                            ? 'solved in ${rows.length}/${game.tries}'
                            : 'missed',
                        if (game.ms != null) formatElapsed(game.ms!),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: game.won ? c.secondary : c.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // a game that is not scored has no skill to show: the tag
                    // takes its place
                    if (game.unscored)
                      Container(
                        key: ValueKey('unscored-${game.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(hairline(c)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('not scored', style: dim),
                      )
                    else
                      metricLine(context, 'skill $skill', 'skill', style: dim),
                    // the achievements the game earned
                    if (game.earned.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: EarnedStrip(earnedFrom(game.earned)),
                      ),
                  ],
                ),
                // a past game can be shared as a puzzle, hashed or with its guesses;
                // the daily is not shared, as anyone can open the app and play it
                if (!game.isDaily)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: SharePuzzleButton(
                      key: ValueKey('share-${game.id}'),
                      compact: true,
                      (withGuesses) => Puzzle.hashed(
                        game.lang,
                        game.mode,
                        length: game.length,
                        tries: game.tries,
                        answers: game.answers,
                        guesses: withGuesses
                            ? [for (final r in rows) r.word]
                            : const [],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
