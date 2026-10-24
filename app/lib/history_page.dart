import 'package:flutter/material.dart';

import 'history.dart';
import 'main.dart';
import 'modes.dart';
import 'playstyle.dart';
import 'replay.dart';
import 'routes.dart';
import 'ui.dart';
import 'words.dart';

/// The player's history: their playstyle and what it is read from, then every
/// game kept, newest first. A game opens its review, rebuilt from the guesses.
/// Games saved under an older version of the maths are scored again while the
/// page is open.
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

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((ls) {
      if (!mounted) return;
      setState(() => _langs = {for (final l in ls) l.code: l});
      _rescore();
    });
  }

  /// Scores again, in the background, any game saved under older maths.
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
                final games = appState.history.games.reversed.toList();
                final won = games.where((g) => g.won).length;
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: [
                        // not const: a const widget is not rebuilt when this
                        // builder runs, and the profile must follow the style
                        // as it changes (after games are scored again, say)
                        // ignore: prefer_const_constructors
                        _Profile(),
                        const SizedBox(height: 20),
                        if (_total > 0) ...[
                          Caption(
                            'scoring $_done of $_total older games again '
                            'with the current maths…',
                          ),
                          const SizedBox(height: 10),
                        ],
                        Caption(
                          games.isEmpty
                              ? 'no games yet'
                              : '${games.length} games kept · $won won',
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_error, style: TextStyle(color: c.error)),
                        ],
                        const SizedBox(height: 6),
                        if (games.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'finish a game and it will be here, to look back '
                              'on step by step.',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.onSurface.withValues(alpha: dimAlpha),
                              ),
                            ),
                          ),
                        for (final g in games)
                          _GameTile(
                            key: ValueKey('game-${g.id}'),
                            game: g,
                            language: _langs[g.lang],
                            onTap: () => _open(g),
                          ),
                      ],
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

    return Container(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
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
            Row(
              children: [
                _Stat('skill', t.skill.round().toString()),
                const SizedBox(width: 28),
                _Stat('daring', t.daring.round().toString()),
                const SizedBox(width: 28),
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
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        key: ValueKey('stat-$label'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      Caption(label),
    ],
  );
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
