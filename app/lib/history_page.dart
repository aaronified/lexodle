import 'dart:math';

import 'package:flutter/material.dart';

import 'analysis.dart';
import 'daily.dart';
import 'history.dart';
import 'logic.dart';
import 'language_picker.dart';
import 'main.dart';
import 'modes.dart';
import 'period_chart.dart';
import 'playstyle_card.dart' show StatTile, hairlineCard;
import 'replay.dart';
import 'routes.dart';
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
      appState.updateStyle(lang: l);
    }
    appState.refresh();
    if (mounted) setState(() => _total = 0);
  }

  Future<void> _open(GameRow g) async {
    final lang = _langs[g.lang];
    if (lang == null || _opening) return;
    setState(() {
      _opening = true;
      _error = '';
    });
    try {
      final bank = await WordBank.load(lang);
      final rows = appState.history.guessesOf(g.id);
      final record = g.isClassic
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
      appBar: AppBar(title: const Text('history')),
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
                    if (g.lang == _lang) g,
                ];
                final total = mine.length;
                final shown = min(_shown, total);
                final more = total - shown;
                // the cards, the note about the games, then the games (built
                // as they scroll into view), then the button for more
                const fixed = 4;
                return Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      itemCount: fixed + shown + (more > 0 ? 1 : 0),
                      itemBuilder: (context, row) {
                        // the playstyle is not on this page: it has its own
                        final i = row == 0 ? 0 : row + 1;
                        // (these are not const: a const widget is not rebuilt
                        // when this builder runs, and they must follow the
                        // history as it changes, after games are scored again)
                        // ignore: prefer_const_constructors
                        if (i == 0) {
                          return _Block(
                            LanguagePicker(
                              codes: appState.playedLanguages.toList()..sort(),
                              languages: _langs,
                              selected: _lang,
                              onSelect: (code) => setState(() {
                                _lang = code;
                                _shown = historyPageSize;
                              }),
                            ),
                          );
                        }
                        // ignore: prefer_const_constructors
                        if (i == 2) return _Block(_Overall(_lang));
                        if (i == 3) {
                          return _Block(
                            _Trend(_lang, key: ValueKey('trend-$_lang')),
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
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton(
                            key: const ValueKey('load-more'),
                            onPressed: () =>
                                setState(() => _shown += historyPageSize),
                            child: Text('load $next more · $more left'),
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
  const _Overall(this.lang);

  /// The language it adds up.
  final String lang;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final h = appState.history;
    final s = summarise(h, [
      for (final g in h.games)
        if (g.lang == lang) g,
    ]);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    String whole(double? v) => v == null ? '–' : v.round().toString();
    return hairlineCard(
      context,
      key: const ValueKey('overall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Caption('overall'),
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
          metricLine(
            context,
            s.games == 0
                ? 'nothing to add up yet'
                : 'luck ${s.scored == 0 ? '–' : luckText(s.luck)} · '
                      '${s.meanTries == null ? '–' : s.meanTries!.toStringAsFixed(1)} '
                      'guesses to win · ${s.classic} of ${s.games} classic',
            'luck',
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

/// How play changed over time: a bar for each of the last 50 weeks or months,
/// for skill, risk, share won or games, and what was in the one picked.
class _Trend extends StatefulWidget {
  const _Trend(this.lang, {super.key});

  /// The language whose periods it draws.
  final String lang;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  bool _weekly = true;

  /// The lines drawn: all three to begin with.
  final _shown = <PeriodSeries>{...PeriodSeries.values};

  /// The period picked (null: the last, which is the one running now).
  int? _picked;

  // working the periods out reads every game, so it is done again only when the
  // history, the day or the choice of weeks or months has changed
  List<Period>? _periods;
  Object? _key;

  List<Period> _periodsNow() {
    final h = appState.history;
    final today = dailyDate();
    final key = (
      h.games.length,
      h.games.isEmpty ? -1 : h.games.last.id,
      h.stale().length,
      _weekly,
      today,
      widget.lang,
    );
    if (_periods == null || _key != key) {
      _periods = _weekly
          ? weeklyPeriods(h, today, lang: widget.lang)
          : monthlyPeriods(h, today, lang: widget.lang);
      _key = key;
    }
    return _periods!;
  }

  void _setWeekly(bool weekly) {
    if (weekly == _weekly) return;
    setState(() {
      _weekly = weekly;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final periods = _periodsNow();
    final sel = (_picked ?? periods.length - 1).clamp(0, periods.length - 1);
    final p = periods[sel];
    final unit = _weekly ? 'week' : 'month';
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
              _Choice(
                'weeks',
                selected: _weekly,
                onTap: () => _setWeekly(true),
              ),
              const SizedBox(width: 6),
              _Choice(
                'months',
                selected: !_weekly,
                onTap: () => _setWeekly(false),
              ),
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
            _weekly ? '${p.start} to ${p.end}' : p.label,
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
            border: Border.all(color: selected ? c.primary : c.outlineVariant),
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
                      ? (color ?? c.primary)
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            FlagBadge(language?.flag ?? '', size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.isEmpty ? _date(game.at) : '${_date(game.at)} · $tag',
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
                  game.won
                      ? 'solved in ${rows.length}/${game.tries}'
                      : 'missed',
                  style: TextStyle(
                    fontSize: 13,
                    color: game.won ? c.secondary : c.error,
                  ),
                ),
                const SizedBox(height: 2),
                metricLine(context, 'skill $skill', 'skill', style: dim),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
