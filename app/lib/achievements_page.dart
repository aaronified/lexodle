import 'package:flutter/material.dart';

import 'language_picker.dart';
import 'main.dart';
import 'routes.dart';
import 'store.dart';
import 'ui.dart';
import 'words.dart';

int achievementCount() => achievements.length;

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
      var times = 0;
      final dates = <String>[];
      for (final l in codes) {
        final st = appState.achOf(l)[a.id];
        if (st == null) continue;
        times += st.times;
        dates.addAll(st.dates);
      }
      if (times > 0) {
        out[a.id] = AchState(times: times, dates: dates..sort());
      }
    }
    return out;
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
                    '${mine.values.where((x) => x.times > 0).length} of '
                    '${achievements.length} earned '
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
                  const SizedBox(height: 20),
                  for (final a in achievements) ...[
                    const Divider(),
                    a.track == Track.badges
                        ? _BadgeRow(
                            a,
                            mine[a.id] ?? AchState(),
                            mastery: a.id == 'mastery',
                          )
                        : _Row(
                            a,
                            mine[a.id] ?? AchState(),
                            // one language's own wears its flag; one that counts
                            // languages wears theirs
                            badges: a.id == towerOfBabelId
                                // every language there is, bright once completed
                                ? (_langs.keys.toList()..sort())
                                : a.global
                                ? won
                                : all
                                ? codes
                                : [_lang],
                            // "all": the languages it is not yet earned in are dim
                            dimmed: a.id == towerOfBabelId
                                ? {
                                    for (final l in _langs.keys)
                                      if (!appState.completedIn(l)) l,
                                  }
                                : all && !a.global
                                ? {
                                    for (final l in codes)
                                      if ((appState.achOf(l)[a.id]?.times ??
                                              0) ==
                                          0)
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

/// One achievement: its glyph, what it asks for, how often it has been earned
/// and, for numbered ones, a bar showing progress towards the next time.
class _Row extends StatelessWidget {
  const _Row(
    this.a,
    this.st, {
    this.badges = const [],
    this.dimmed = const {},
    this.showBar = true,
  });
  final Achievement a;
  final AchState st;

  /// Of those, the ones drawn dim (where it has not been earned), and whether
  /// the progress bar is shown.
  final Set<String> dimmed;
  final bool showBar;

  /// The languages whose flags it wears.
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final earned = st.times > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // earned at least once: the accent colour; not yet: a faint ghost
              TablerIcon(
                a.icon,
                size: 44,
                color: earned ? c.primary : c.onSurface.withValues(alpha: .22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: earned ? 1 : .55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(a.description, style: const TextStyle(fontSize: 12)),
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
                ),
              ),
              if (earned)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '×${st.times}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.primary,
                      ),
                    ),
                    Caption(st.latest ?? ''),
                  ],
                ),
            ],
          ),
          if (a.numbered && showBar) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: _Bar(progress: st.progress, target: a.target),
            ),
          ],
        ],
      ),
    );
  }
}

/// The language mastery achievement: one achievement, a badge for every
/// language mastered, kept for good. Tap it for the language by language list.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow(this.a, this.st, {this.mastery = true});
  final Achievement a;
  final AchState st;

  /// The language mastery (which opens its list) or the completionist (which
  /// only collects its badges).
  final bool mastery;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final earned = st.seen.isNotEmpty;
    return InkWell(
      key: ValueKey('${a.id}-row'),
      onTap: mastery
          ? () => Navigator.pushNamed(context, Routes.mastery)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: FutureBuilder<List<Language>>(
          future: WordBank.languages(),
          builder: (context, snap) {
            final langs = snap.data ?? const <Language>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TablerIcon(
                      a.icon,
                      size: 44,
                      color: earned
                          ? c.primary
                          : c.onSurface.withValues(alpha: .22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Opacity(
                        opacity: earned ? 1 : .55,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${st.seen.length}/${langs.length}',
                          key: ValueKey('${a.id}-count'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: earned ? c.primary : null,
                          ),
                        ),
                        if (mastery)
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // the badges collected: a flag for every language mastered
                      for (final l in langs)
                        if (st.seen.contains(l.code))
                          Container(
                            key: ValueKey('badge-${l.code}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: c.primary),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FlagBadge(l.flag, size: 18),
                          ),
                      if (!earned)
                        Text(
                          'no badges yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
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
  const _Bar({required this.progress, required this.target});
  final int progress;
  final int target;

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
                    color: c.primary,
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
