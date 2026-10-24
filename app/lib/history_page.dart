import 'dart:math';

import 'package:flutter/material.dart';

import 'analysis.dart';
import 'daily.dart';
import 'history.dart';
import 'logic.dart';
import 'main.dart';
import 'modes.dart';
import 'period_chart.dart';
import 'playstyle.dart';
import 'replay.dart';
import 'routes.dart';
import 'ui.dart';
import 'words.dart';

/// How many games the list shows at first, and how many more each press adds.
/// There can be thousands, so the rest are loaded as they are asked for.
const historyPageSize = 10;

/// The player's history: their playstyle and what it is read from, an analysis
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
    // the numbers moved, so the playstyle is read again from them
    appState.saveHistory();
    appState.updateStyle();
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
                final total = h.games.length;
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
                      itemBuilder: (context, i) {
                        // (these are not const: a const widget is not rebuilt
                        // when this builder runs, and they must follow the
                        // history as it changes, after games are scored again)
                        // ignore: prefer_const_constructors
                        if (i == 0) return _Block(_Profile());
                        // ignore: prefer_const_constructors
                        if (i == 1) return _Block(_Overall());
                        // ignore: prefer_const_constructors
                        if (i == 2) return _Block(_Trend());
                        if (i == 3) {
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
                        final k = i - fixed;
                        if (k < shown) {
                          // newest first: the list is the history read backwards
                          final g = h.games[total - 1 - k];
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

/// A hairline box, as the other cards of the app.
Widget _card(BuildContext context, {Key? key, required Widget child}) {
  final c = Theme.of(context).colorScheme;
  return Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: c.outlineVariant),
      borderRadius: BorderRadius.circular(3),
    ),
    child: child,
  );
}

/// The playstyle now, the traits it is read from, and which of the six the
/// player has been.
class _Profile extends StatefulWidget {
  const _Profile();

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  /// The style whose description is open: tapped, since a tooltip needs a hover
  /// or a long press, which a phone does not give.
  Playstyle? _picked;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = appState.style;
    final t = traitsOf(appState.history);
    final games = appState.history.recentClassic().length;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    String why() {
      if (games < minRatedGames) {
        return 'play ${minRatedGames - games} more classic '
            '${minRatedGames - games == 1 ? 'game' : 'games'} to be given a '
            'playstyle';
      }
      return 'not enough guesses with a choice in them yet';
    }

    return _card(
      context,
      key: const ValueKey('profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TablerIcon(
                p?.icon ?? 'puzzle',
                key: ValueKey('profile-icon-${p?.id ?? 'unrated'}'),
                size: 44,
                color: p == null
                    ? c.onSurface.withValues(alpha: dimAlpha)
                    : c.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.name ?? 'not rated yet',
                      key: const ValueKey('profile-name'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p?.blurb ?? why(),
                      key: const ValueKey('profile-blurb'),
                      style: dim,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (t != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 28,
              runSpacing: 8,
              children: [
                _Stat('skill', t.skill.round().toString()),
                _Stat('daring', t.daring.round().toString()),
                _Stat('games', t.games.toString()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'the means over your last ${t.games} classic '
              '${t.games == 1 ? 'game' : 'games'}, up to $styleWindow',
              style: dim.copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          // the six share the card's width, so they fit the narrowest phone,
          // and a name shrinks before it can touch its neighbour
          Row(
            children: [
              for (final s in playstyles)
                Expanded(
                  child: _StyleDot(
                    s,
                    held: appState.stylesHeld.contains(s.id),
                    current: s.id == p?.id,
                    picked: s.id == _picked?.id,
                    onTap: () =>
                        setState(() => _picked = _picked == s ? null : s),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // what the tapped style is, in the card, so it fits any width
          if (_picked case final s?)
            Text(
              '${s.name}: ${s.blurb}'
              '${s.id == p?.id
                  ? ' (your style now)'
                  : appState.stylesHeld.contains(s.id)
                  ? ' (you have been this)'
                  : ' (not yet)'}',
              key: const ValueKey('style-detail'),
              style: const TextStyle(fontSize: 12, height: 1.4),
            )
          else
            Text(
              appState.styleChanges == 0
                  ? 'tap a style to see what it is. it moves with the way you '
                        'play'
                  : 'tap a style to see what it is. changed '
                        '${appState.styleChanges} '
                        '${appState.styleChanges == 1 ? 'time' : 'times'}',
              style: dim.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.prefix = 'stat'});
  final String label;
  final String value;

  /// Keeps the keys of one card apart from another's.
  final String prefix;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        key: ValueKey('$prefix-$label'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      Caption(label),
    ],
  );
}

/// Every game kept, added up: always there, however many there are.
class _Overall extends StatelessWidget {
  const _Overall();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final h = appState.history;
    final s = summarise(h, h.games);
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    String whole(double? v) => v == null ? '–' : v.round().toString();
    return _card(
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
              _Stat('games', '${s.games}', prefix: 'overall'),
              _Stat(
                'won',
                s.games == 0 ? '–' : '${s.winRate.round()}%',
                prefix: 'overall',
              ),
              _Stat(
                'skill',
                whole(s.scored == 0 ? null : s.skill),
                prefix: 'overall',
              ),
              _Stat('daring', whole(s.daring), prefix: 'overall'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.games == 0
                ? 'nothing to add up yet'
                : 'luck ${s.scored == 0 ? '–' : luckText(s.luck)} · '
                      '${s.meanTries == null ? '–' : s.meanTries!.toStringAsFixed(1)} '
                      'guesses to win · ${s.classic} of ${s.games} classic',
            key: const ValueKey('overall-line'),
            style: dim,
          ),
          if (s.stale > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${s.stale} ${s.stale == 1 ? 'game' : 'games'} saved under '
              'older maths ${s.stale == 1 ? 'is' : 'are'} left out of skill, '
              'luck and daring until scored again',
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
/// for skill, daring, share won or games, and what was in the one picked.
class _Trend extends StatefulWidget {
  const _Trend();

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
    );
    if (_periods == null || _key != key) {
      _periods = _weekly ? weeklyPeriods(h, today) : monthlyPeriods(h, today);
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
    return _card(
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
                  series == PeriodSeries.luck ? 'luck (50 = 0%)' : series.label,
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
          Text(
            s.isEmpty
                ? 'no games'
                : '${s.games} ${s.games == 1 ? 'game' : 'games'} · '
                      '${s.winRate.round()}% won · '
                      'skill ${whole(s.scored == 0 ? null : s.skill)} · '
                      'daring ${whole(s.daring)} · '
                      'luck ${s.scored == 0 ? '–' : luckText(s.luck)}',
            key: const ValueKey('period-detail'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          if (p.style != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                TablerIcon(p.style!.icon, size: 18, color: c.primary),
                const SizedBox(width: 6),
                Text(
                  'played like a ${p.style!.name}',
                  key: const ValueKey('period-style'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${[for (final e in changes.entries) '${e.key.label} ${e.value}'].join(' · ')}'
              ' on the last $unit you played',
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

/// One of the six playstyles: lit if the player has been it, ringed if it is
/// their style now.
class _StyleDot extends StatelessWidget {
  const _StyleDot(
    this.style, {
    required this.held,
    required this.current,
    required this.picked,
    required this.onTap,
  });
  final Playstyle style;
  final bool held;
  final bool current;

  /// Whether its description is open, and what a tap does.
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: picked,
      label: '${style.name}${held ? '' : ', not yet'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          key: ValueKey('dot-${style.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: current
                  ? c.primary
                  : picked
                  ? c.outline
                  : c.outlineVariant.withValues(alpha: 0),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            children: [
              TablerIcon(
                style.icon,
                size: 24,
                color: held ? c.primary : c.outlineVariant,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  style.name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    color: c.onSurface.withValues(alpha: held ? 1 : dimAlpha),
                  ),
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
                Text('skill $skill', style: dim),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
