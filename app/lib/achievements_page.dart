import 'package:flutter/material.dart';

import 'language_picker.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'store.dart';
import 'ui.dart';
import 'words.dart';

int achievementCount() => levelCount;

/// The achievements. Each language has its own (except the few that count
/// languages, and the mastery badges), so the page is about one language at a
/// time, with its flag on every one of its achievements; the ones that span
/// languages carry the flags of the languages they count. "All" shows every
/// language at once: each achievement wears the flag of every language played,
/// bright where it was earned there and dim where not, with the times, first and
/// latest days added up across them.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  String _lang = appState.lang;
  Map<String, Language> _langs = {};
  Medal? _medal;

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((ls) {
      if (mounted) setState(() => _langs = {for (final l in ls) l.code: l});
    });
  }

  /// Played, won, and the win streak now and best, in [lang]'s games (every
  /// game when null).
  ({int played, int wins, int streak, int best}) _record(String? lang) {
    var played = 0, wins = 0, streak = 0, best = 0;
    for (final g in appState.history.games) {
      if (lang != null && g.lang != lang) continue;
      played++;
      if (g.won) {
        wins++;
        streak++;
        if (streak > best) best = streak;
      } else {
        streak = 0;
      }
    }
    return (played: played, wins: wins, streak: streak, best: best);
  }

  /// Every language's achievements added up: the times, the days (in order), and
  /// for a global one (which no language owns) its own state.
  Map<String, AchState> _merged(List<String> codes) {
    final out = <String, AchState>{};
    for (final a in achievements) {
      if (a.global) {
        final st = appState.achOf(
          codes.isEmpty ? appState.lang : codes.first,
        )[a.id];
        if (st != null) out[a.id] = st;
        continue;
      }
      // the furthest level of any language, with the days it was reached
      AchState? best;
      for (final l in codes) {
        final st = appState.achOf(l)[a.id];
        if (st != null && st.times > (best?.times ?? 0)) best = st;
      }
      if (best != null) {
        out[a.id] = AchState(times: best.times, dates: List.of(best.dates));
      }
    }
    return out;
  }

  /// The medal of the highest level earned of [a], or null for none.
  Medal? _topMedal(Map<String, AchState> mine, Achievement a) {
    final n = (mine[a.id]?.times ?? 0).clamp(0, a.count);
    return n == 0 ? null : a.levels[n - 1].medal;
  }

  /// How many levels of medal [m] (every medal when null) are earned.
  int _earnedAt(Map<String, AchState> mine, Medal? m) {
    var n = 0;
    for (final a in achievements) {
      final t = (mine[a.id]?.times ?? 0).clamp(0, a.count);
      for (var i = 0; i < t; i++) {
        if (m == null || a.levels[i].medal == m) n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('achievements')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              final all = _lang == allLanguages;
              final codes = appState.playedLanguages.toList()..sort();
              final s = _record(all ? null : _lang);
              final mine = all ? _merged(codes) : appState.achOf(_lang);
              final won = appState.stats.langsWon.toList()..sort();
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  LanguagePicker(
                    codes: codes,
                    languages: _langs,
                    selected: _lang,
                    showAll: true,
                    onSelect: (code) => setState(() => _lang = code),
                  ),
                  const SizedBox(height: 12),
                  Caption(
                    '${achievements.fold(0, (n, a) => n + (mine[a.id]?.times ?? 0))} of '
                    '$levelCount levels earned '
                    '${all ? 'in any language' : 'in $_lang'}',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat('played', s.played),
                      _Stat('won', s.wins),
                      _Stat('streak', s.streak),
                      _Stat('best', s.best),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in [null, ...Medal.values])
                        _MedalPill(
                          m,
                          earned: _earnedAt(mine, m),
                          total: m == null ? levelCount : achievements.length,
                          on: _medal == m,
                          onTap: () => setState(() => _medal = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final a in achievements.where(
                    (a) => _medal == null || _topMedal(mine, a) == _medal,
                  )) ...[
                    const Divider(),
                    _Row(
                      a,
                      mine[a.id] ?? AchState(),
                      languages: _langs.length,
                      // one language's own wears its flag; one that counts
                      // languages wears theirs
                      badges: a.global
                          ? won
                          : all
                          ? codes
                          : [_lang],
                      // "all": the languages it is not yet earned in are dim
                      dimmed: all && !a.global
                          ? {
                              for (final l in codes)
                                if ((appState.achOf(l)[a.id]?.times ?? 0) == 0)
                                  l,
                            }
                          : const {},
                      // progress is a language's own
                      showBar: !(all && !a.global),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Caption('history'),
                  const SizedBox(height: 10),
                  _History(c, mine),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One achievement: its glyph in the medal of the highest level earned, what
/// the next level asks for, a pip for each level, and a bar towards the next. A
/// streak shows an icon for each of its levels instead.
class _Row extends StatelessWidget {
  const _Row(
    this.a,
    this.st, {
    this.badges = const [],
    this.dimmed = const {},
    this.showBar = true,
    this.languages = 0,
  });
  final Achievement a;
  final AchState st;

  /// How many languages there are, for the targets that count them.
  final int languages;

  /// Of those, the ones drawn dim (where it has not been earned), and whether
  /// the progress bar is shown.
  final Set<String> dimmed;
  final bool showBar;

  /// The languages whose flags it wears.
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final done = st.times.clamp(0, a.count);
    final complete = done >= a.count;
    // what it asks next (or, once complete, its top level)
    final next = a.atLevel(complete ? a.count - 1 : done);
    final top = done == 0 ? null : a.atLevel(done - 1);
    final medal = medalColor(c, next.medal);
    final earnedColor = top == null ? null : medalColor(c, top.medal);
    final ghost = c.onSurface.withValues(alpha: .22);
    // a tap lists every level: its name, what it asks, and when it was earned
    void tap() => showHairlineDialog<void>(
      context,
      title: a.family,
      children: [
        for (var i = 0; i < a.count; i++)
          Padding(
            key: ValueKey('detail-${a.id}-$i'),
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TablerIcon(
                  a.atLevel(i).icon,
                  size: 32,
                  color: i < done ? medalColor(c, a.levels[i].medal) : ghost,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.levels[i].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            a.levels[i].medal.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: medalColor(c, a.levels[i].medal),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        a.atLevel(i).description,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      if (i < done && i < st.dates.length) Caption(st.dates[i]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (a.metric == 'mastered')
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, Routes.mastery);
            },
            child: const Text('language by language'),
          ),
      ],
    );
    final target = a.targetAt(next.level, languages: languages);

    Widget pips() => Row(
      key: ValueKey('levels-${a.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < a.count; i++)
          Container(
            key: ValueKey('level-${a.id}-$i'),
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? medalColor(c, a.levels[i].medal) : null,
              border: Border.all(color: i < done ? Colors.transparent : ghost),
            ),
          ),
      ],
    );

    final glyph = a.separate
        ? Row(
            key: ValueKey('streak-icons-${a.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < a.count; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      TablerIcon(
                        a.atLevel(i).icon,
                        key: ValueKey('streak-icon-${a.id}-$i'),
                        size: 34,
                        color: i < done
                            ? medalColor(c, a.levels[i].medal)
                            : ghost,
                      ),
                      Text(
                        '${a.levels[i].target}',
                        style: TextStyle(
                          fontSize: 10,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        : TablerIcon(a.icon, size: 44, color: earnedColor ?? ghost);

    final text = Opacity(
      opacity: done > 0 ? 1 : .55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  // the name changes as the levels are reached
                  (top ?? next).title,
                  key: ValueKey('name-${a.id}'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                next.medal.name,
                key: ValueKey('medal-${a.id}'),
                style: TextStyle(fontSize: 11, color: medal),
              ),
              if (a.tag != null) ...[
                const SizedBox(width: 6),
                TablerIcon(
                  a.tag == GameMode.quartet ? 'layout-grid' : 'chess-knight',
                  size: 13,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(next.description, style: const TextStyle(fontSize: 12)),
          if (!a.separate) ...[const SizedBox(height: 6), pips()],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              key: ValueKey('badges-${a.id}'),
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final code in badges)
                  Opacity(
                    key: ValueKey('badge-${a.id}-$code'),
                    opacity: dimmed.contains(code) ? .3 : 1,
                    child: languageBadge(code, size: 11),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final right = done == 0
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$done/${a.count}',
                key: ValueKey('count-${a.id}'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: earnedColor,
                ),
              ),
              Caption(st.latest ?? ''),
            ],
          );

    return InkWell(
      key: ValueKey('${a.id}-row'),
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.separate) ...[
              Row(
                children: [
                  Expanded(child: text),
                  ?right,
                ],
              ),
              const SizedBox(height: 10),
              glyph,
            ] else
              Row(
                children: [
                  glyph,
                  const SizedBox(width: 16),
                  Expanded(child: text),
                  ?right,
                ],
              ),
            if (a.numbered && showBar && !complete) ...[
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(left: a.separate ? 0 : 60),
                child: _Bar(
                  progress: st.value.toInt(),
                  target: target,
                  color: medal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One medal's filter: its name and how many of its achievements are earned.
class _MedalPill extends StatelessWidget {
  const _MedalPill(
    this.medal, {
    required this.earned,
    required this.total,
    required this.on,
    required this.onTap,
  });
  final Medal? medal;
  final int earned, total;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = medal == null ? c.onSurface : medalColor(c, medal!);
    return InkWell(
      key: ValueKey('medal-filter-${medal?.name ?? 'all'}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: on ? color : c.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '${medal?.name ?? 'all'} $earned/$total',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    );
  }
}

/// Language by language: how far each language is from mastery. It is a page
/// of its own ([Routes.mastery]), opened from the language mastery achievement.
class MasteryPage extends StatelessWidget {
  const MasteryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('language mastery')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              final mastery = appState.stats.mastery;
              return FutureBuilder<List<Language>>(
                future: WordBank.languages(),
                builder: (context, snap) {
                  final langs = snap.data ?? const <Language>[];
                  final done = langs
                      .where(
                        (l) =>
                            masteryWon(l, mastery[l.code]) >= masteryTarget(l),
                      )
                      .length;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      Caption('$done of ${langs.length} languages mastered'),
                      const SizedBox(height: 8),
                      const Text(
                        'win once at every length and every difficulty '
                        '(tries and word length) of a language to earn its '
                        'badge. only classic games count.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      for (final l in langs)
                        _MasteryRow(l, masteryWon(l, mastery[l.code])),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One language's mastery: how many of its settings have been won at.
class _MasteryRow extends StatelessWidget {
  const _MasteryRow(this.language, this.won);
  final Language language;
  final int won;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final target = masteryTarget(language);
    final done = won >= target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          FlagBadge(language.flag),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              language.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done ? FontWeight.bold : FontWeight.normal,
                color: done ? c.primary : c.onSurface,
              ),
            ),
          ),
          Expanded(
            child: _Bar(progress: won, target: target),
          ),
        ],
      ),
    );
  }
}

/// Progress towards the next earning. It starts again from 0 each time.
class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.target, this.color});
  final int progress;
  final int target;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final frac = (progress / target).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  key: const ValueKey('bar-fill'),
                  height: 4,
                  width: box.maxWidth * frac,
                  decoration: BoxDecoration(
                    color: color ?? c.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$progress/$target',
          style: TextStyle(
            fontSize: 11,
            color: c.onSurface.withValues(alpha: dimAlpha),
          ),
        ),
      ],
    );
  }
}

/// When each earned achievement was first and last earned, and how many times.
class _History extends StatelessWidget {
  const _History(this.c, this.states);
  final ColorScheme c;
  final Map<String, AchState> states;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final a in achievements)
        if ((states[a.id]?.times ?? 0) > 0) (a, states[a.id]!),
    ]..sort((x, y) => y.$2.latest!.compareTo(x.$2.latest!));

    if (rows.isEmpty) {
      return Text(
        'nothing earned yet.',
        style: TextStyle(
          fontSize: 13,
          color: c.onSurface.withValues(alpha: dimAlpha),
        ),
      );
    }

    final head = TextStyle(
      fontSize: 10,
      letterSpacing: .8,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    const cell = TextStyle(fontSize: 11);
    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: w);
    return Table(
      columnWidths: const {
        1: FixedColumnWidth(34),
        2: FixedColumnWidth(88),
        3: FixedColumnWidth(88),
      },
      children: [
        TableRow(
          children: [
            pad(Text('achievement', style: head)),
            pad(Text('times', style: head, textAlign: TextAlign.right)),
            pad(Text('first', style: head, textAlign: TextAlign.right)),
            pad(Text('latest', style: head, textAlign: TextAlign.right)),
          ],
        ),
        for (final (a, st) in rows)
          TableRow(
            children: [
              pad(Text(a.title, style: cell)),
              pad(Text('${st.times}', style: cell, textAlign: TextAlign.right)),
              pad(
                Text(st.first ?? '', style: cell, textAlign: TextAlign.right),
              ),
              pad(
                Text(st.latest ?? '', style: cell, textAlign: TextAlign.right),
              ),
            ],
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Caption(label),
      ],
    ),
  );
}
