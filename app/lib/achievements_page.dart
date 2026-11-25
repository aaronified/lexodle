import 'package:flutter/material.dart';

import 'language_picker.dart';
import 'language_switch.dart';
import 'lex.dart';
import 'lex_widgets.dart' show LexChip;
import 'main.dart';
import 'mode_wheel.dart' show modeIconName;
import 'modes.dart' show GameMode;
import 'routes.dart';
import 'store.dart';
import 'settings_button.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';

int achievementCount() => levelCount;

/// Achievements of one category beyond this many rows are laid out row by row
/// in the page's lazy list, not in one group.
const _longGroup = 30;

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

  /// Whether the lex dropdown at the top of the list is open.
  bool _lexOpen = false;

  /// The sort of the list: one of [_sorts], or null for the page's own order.
  String? _sort;
  static const _sorts = ['closest', 'medal', 'a to z'];

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
    for (final g in appState.history.scoredGames) {
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
        out[a.id] = AchState(
          times: best.times,
          dates: List.of(best.dates),
          hits: List.of(best.hits),
          cycle: best.cycle,
          rounds: best.rounds,
        );
      }
    }
    return out;
  }

  /// The sections of the list, in order.
  static const _sections = [
    'general',
    'milestones',
    'quartet',
    'relay race',
    'lockdown',
    'blind',
    'equations',
    'mastermind',
    'streaks',
  ];

  /// The section [a] is listed in: the mode it is about, else its kind.
  static String _sectionOf(Achievement a) {
    if (a.separate) return 'streaks';
    final mode = a.tag;
    if (mode != null) {
      return switch (mode) {
        GameMode.quartet => 'quartet',
        GameMode.relay => 'relay race',
        GameMode.lockdown => 'lockdown',
        GameMode.blind => 'blind',
        GameMode.equations => 'equations',
        GameMode.mastermind => 'mastermind',
        _ => 'general',
      };
    }
    return const {
          'lengths',
          'langs',
          'mastered',
          'completed',
          'fullSet',
          'dailies',
          'doubles',
          'modesWon',
          'dailyDay',
          'dailyFullDays',
          'stylesWorn',
          'collected',
          'saved',
          'noted',
        }.contains(a.metric)
        ? 'milestones'
        : 'general';
  }

  /// What is listed, by section (each keeps its own order), under the medal
  /// filter; under a sort, in that order instead, whatever the section.
  List<Achievement> _shown(
    Map<String, AchState> mine, {
    int languages = 0,
    int words = 0,
  }) {
    final list = [
      for (final a in achievements)
        if (_medal == null || _topMedal(mine, a) == _medal) a,
    ];
    final sort = _sort;
    if (sort != null) {
      return sortAchievements(
        list,
        mine,
        sort,
        languages: languages,
        words: words,
      );
    }
    // a stable sort: within a section the order is the one they are defined in
    return [
      for (final sec in _sections)
        for (final a in list)
          if (_sectionOf(a) == sec) a,
    ];
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
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                final learned = {
                  for (final e in appState.learnLog.events) e.language,
                }.toList()..sort();
                final shown = _shown(
                  mine,
                  languages: _langs.length,
                  words: all ? 0 : appState.wordsOf(_lang),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      text: 'achievements',
                      back: true,
                      info: appState.lexUnlocked
                          ? InkResponse(
                              key: const ValueKey('lex-chip'),
                              onTap: () => setState(() => _lexOpen = !_lexOpen),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                child: Center(
                                  child: LexChip(appState.lexBalance),
                                ),
                              ),
                            )
                          : null,
                      actions: [
                        IconButton(
                          key: const ValueKey('achievement-history'),
                          tooltip: 'history',
                          icon: TablerIcon(
                            'clock',
                            size: 22,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _HistoryPage(
                                () => _lang == allLanguages
                                    ? _merged(
                                        appState.playedLanguages.toList()
                                          ..sort(),
                                      )
                                    : appState.achOf(_lang),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          if (appState.lexUnlocked && _lexOpen) ...[
                            const _LexDrop(),
                            const SizedBox(height: 16),
                          ],
                          LanguagePicker(
                            codes: languageStops(codes),
                            languages: _langs,
                            selected: _lang,
                            showAll: true,
                            onSelect: (code) => setState(() => _lang = code),
                          ),
                          const SizedBox(height: 12),
                          TonalCard(
                            child: StatsStrip([
                              ('${s.played}', 'played', null),
                              ('${s.wins}', 'won', null),
                              ('${s.streak}', 'streak', null),
                              ('${s.best}', 'best', null),
                            ]),
                          ),
                          _Recent(mine, DateTime.now(), all ? null : _lang),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
                            child: Caption(
                              '${achievements.fold(0, (n, a) => n + (mine[a.id]?.times ?? 0))} of '
                              '$levelCount levels earned '
                              '${all ? 'in any language' : 'in $_lang'}',
                            ),
                          ),
                          ChoiceSlider<Medal?>(
                            id: 'achievements-medal',
                            compact: true,
                            selected: _medal,
                            onChanged: (m) => setState(() => _medal = m),
                            items: [
                              ChoiceItem<Medal?>(
                                value: null,
                                label:
                                    'all ${_earnedAt(mine, null)}/$levelCount',
                              ),
                              for (final m in Medal.values)
                                ChoiceItem<Medal?>(
                                  value: m,
                                  label:
                                      '${m.name} ${_earnedAt(mine, m)}/'
                                      '${achievements.length}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Caption('sort'),
                              for (final o in _sorts)
                                _SortPill(
                                  o,
                                  on: _sort == o,
                                  onTap: () => setState(
                                    () => _sort = _sort == o ? null : o,
                                  ),
                                ),
                            ],
                          ),
                          ..._list(
                            context,
                            shown,
                            mine,
                            all: all,
                            codes: codes,
                            learned: learned,
                            won: won,
                          ),
                        ],
                      ),
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

  /// The list under the sort and the medal filter: a [SectionLabel] for each
  /// category, with its rows in one [GroupedList]. A sort lists them all as one
  /// group, without labels. A group of more than [_longGroup] rows is laid out
  /// row by row in the page's own lazy list, with the same look.
  List<Widget> _list(
    BuildContext context,
    List<Achievement> shown,
    Map<String, AchState> mine, {
    required bool all,
    required List<String> codes,
    required List<String> learned,
    required List<String> won,
  }) {
    final groups = <String, List<Achievement>>{};
    for (final a in shown) {
      (groups[_sort == null ? _sectionOf(a) : ''] ??= []).add(a);
    }
    final out = <Widget>[];
    for (final e in groups.entries) {
      if (_sort == null) out.add(SectionLabel(e.key));
      final rows = [
        for (final a in e.value)
          _achievementRow(
            context,
            a,
            mine[a.id] ?? AchState(),
            languages: _langs.length,
            words: all ? 0 : appState.wordsOf(_lang),
            // one language's own wears its flag; one that counts languages
            // wears theirs
            badges: a.learn
                ? learned
                : a.global
                ? won
                : all
                ? codes
                : [_lang],
            // "all": the languages it is not yet earned in are dim
            dimmed: all && !a.global
                ? {
                    for (final l in codes)
                      if ((appState.achOf(l)[a.id]?.times ?? 0) == 0) l,
                  }
                : const {},
            // progress is a language's own
            showBar: !(all && !a.global),
          ),
      ];
      if (rows.length <= _longGroup) {
        out.add(GroupedList(rows: rows));
        continue;
      }
      const outer = Radius.circular(radiusContainer);
      const inner = Radius.circular(4);
      final n = rows.length;
      for (final (i, r) in rows.indexed) {
        if (i > 0) out.add(const SizedBox(height: 2));
        out.add(
          _LongRow(
            r,
            radius: BorderRadius.only(
              topLeft: i == 0 ? outer : inner,
              topRight: i == 0 ? outer : inner,
              bottomLeft: i == n - 1 ? outer : inner,
              bottomRight: i == n - 1 ? outer : inner,
            ),
          ),
        );
      }
    }
    return out;
  }
}

/// [list] in the order of [sort] ('closest', 'medal' or 'a to z'). Ties keep
/// the order of [list].
List<Achievement> sortAchievements(
  List<Achievement> list,
  Map<String, AchState> mine,
  String sort, {
  int languages = 0,
  int words = 0,
}) {
  int done(Achievement a) => (mine[a.id]?.times ?? 0).clamp(0, a.count);
  // how far the next level is: maxed ones last, ones with no count at 0
  double ratio(Achievement a) {
    final d = done(a);
    if (d >= a.count && !a.cycles) return -1;
    if (!a.numbered) return 0;
    final next = a.cycles ? (mine[a.id]?.cycle ?? 0).clamp(0, a.count - 1) : d;
    final t = a.targetAt(next, languages: languages, words: words);
    return t <= 0 ? 0 : ((mine[a.id]?.value ?? 0) / t).clamp(0.0, 1.0);
  }

  String name(Achievement a) {
    final d = done(a);
    return (d == 0 ? a : a.atLevel(d - 1)).title.toLowerCase();
  }

  int medal(Achievement a) {
    final d = done(a);
    return d == 0 ? -1 : a.levels[d - 1].medal.index;
  }

  final order = {for (final (i, a) in list.indexed) a.id: i};
  return List.of(list)..sort((x, y) {
    final c = switch (sort) {
      'closest' => ratio(y).compareTo(ratio(x)),
      'medal' => medal(y).compareTo(medal(x)),
      'a to z' => name(x).compareTo(name(y)),
      _ => 0,
    };
    return c != 0 ? c : order[x.id]!.compareTo(order[y.id]!);
  });
}

/// How long ago [day] ('yyyy-mm-dd') was from [now]: today, yesterday, or N
/// days ago.
String daysAgo(String day, DateTime now) {
  final d = DateTime.tryParse(day);
  if (d == null) return day;
  final n = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (n <= 0) return 'today';
  return n == 1 ? 'yesterday' : '$n days ago';
}

/// The three achievements earned most recently, each with its icon in the
/// medal of the level reached; nothing when none is earned yet.
class _Recent extends StatelessWidget {
  const _Recent(this.mine, this.now, this.lang);
  final Map<String, AchState> mine;
  final DateTime now;

  /// The language shown, or null for all of them.
  final String? lang;

  /// What [a] (at the level [level]) paid on [day]: its lex when the ledger
  /// holds that payout, 0 when the achievement paid that day at another level
  /// (the daily payout was already given), null when nothing is known.
  int? _paid(Achievement a, int level, String day) {
    if (!appState.lexUnlocked) return null;
    int? other;
    for (final e in appState.lex.ledger) {
      if (!e.why.startsWith('earn:${a.id}:')) continue;
      if (lang != null && e.lang != lang) continue;
      if (_dayOf(e.at) != day) continue;
      if (e.why == 'earn:${a.id}:$level') return e.delta;
      other = 0;
    }
    return other;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final rows = [
      for (final a in achievements)
        if ((mine[a.id]?.times ?? 0) > 0 && mine[a.id]!.latest != null)
          (a, mine[a.id]!),
    ];
    // newest first; the days are sorted text, ties keep the page's order
    final order = {for (final (i, r) in rows.indexed) r.$1.id: i};
    rows.sort((x, y) {
      final d = y.$2.latest!.compareTo(x.$2.latest!);
      return d != 0 ? d : order[x.$1.id]!.compareTo(order[y.$1.id]!);
    });
    if (rows.isEmpty) return const SizedBox.shrink();
    final items = <GroupRow>[];
    for (final (a, st) in rows.take(3)) {
      final lvl = a.atLevel(st.times.clamp(1, a.count) - 1);
      final color = medalColor(c, lvl.medal);
      final paid = _paid(a, lvl.level, st.latest!);
      items.add(
        GroupRow(
          key: ValueKey('recent-${a.id}'),
          leading: TonalTile(lvl.icon, big: true, color: color),
          // the medal of the level reached, after the title, in its colour
          title: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: lvl.title),
                TextSpan(
                  text: ' ${lvl.medal.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          subtitle: Text(lvl.description),
          chevron: false,
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (paid != null) ...[
                paid > 0
                    ? LexChip(paid, key: ValueKey('recent-lex-${a.id}'))
                    : _PaidEarlier(key: ValueKey('recent-paid-${a.id}')),
                const SizedBox(height: 4),
              ],
              Caption(
                daysAgo(st.latest!, now),
                key: ValueKey('recent-when-${a.id}'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('recent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('recent'),
        GroupedList(rows: items),
      ],
    );
  }
}

/// The local day of a ledger time, as the achievements keep their days.
String _dayOf(int at) {
  final d = DateTime.fromMillisecondsSinceEpoch(at);
  String t(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${t(d.month)}-${t(d.day)}';
}

/// A small chip: that level's lex for the day was already paid.
class _PaidEarlier extends StatelessWidget {
  const _PaidEarlier({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tonesOf(context).s2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'paid earlier',
        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
      ),
    );
  }
}

/// The lifetime lex earned: the positive earnings and the starting grant in the
/// ledger. The ledger keeps the last [lexLedgerCap] lines, so past that the
/// total is only what it still holds.
int lexEarnedTotal(Lex lex) {
  var n = 0;
  for (final e in lex.ledger) {
    if (e.delta > 0 && (e.why.startsWith('earn:') || e.why == 'grant')) {
      n += e.delta;
    }
  }
  return n;
}

/// The dropdown under the lex chip: the total earned and the rule.
class _LexDrop extends StatelessWidget {
  const _LexDrop();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final sub = TextStyle(fontSize: 13, color: c.onSurfaceVariant, height: 1.5);
    return Container(
      key: const ValueKey('lex-drop'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tonesOf(context).s1,
        borderRadius: BorderRadius.circular(radiusContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'earned in total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              LexChip(lexEarnedTotal(appState.lex)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'earn a medal on any achievement and it pays lex: '
            'bronze ${medalValue(Medal.bronze)} · '
            'silver ${medalValue(Medal.silver)} · '
            'gold ${medalValue(Medal.gold)} · '
            'platinum ${medalValue(Medal.platinum)}.',
            style: sub,
          ),
          const SizedBox(height: 6),
          Text(
            'each achievement pays once a day in each language, and only in a '
            'game where you used no hint. your streak stays safe either way.',
            style: sub,
          ),
        ],
      ),
    );
  }
}

/// One sort option of the list: a tonal pill, 36 high, its name in bold on the
/// green when it is the sort in use.
class _SortPill extends StatelessWidget {
  const _SortPill(this.label, {required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: on ? c.secondaryContainer : tonesOf(context).s1,
      shape: const StadiumBorder(),
      child: InkWell(
        key: ValueKey('sort-$label'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : null,
                  color: on ? c.onSecondaryContainer : c.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One achievement's row of the list: a big tile with its icon in the medal of
/// the highest level earned, its name and the medal of the next level, what the
/// next level asks, a dot for each level, a bar towards the next, and the count
/// and the day of the last. A locked one (nothing earned) is drawn at 55%. A tap
/// lists every level.
GroupRow _achievementRow(
  BuildContext context,
  Achievement a,
  AchState st, {
  required int languages,
  required int words,
  required List<String> badges,
  required Set<String> dimmed,
  required bool showBar,
}) {
  final c = Theme.of(context).colorScheme;
  final tones = tonesOf(context);
  final done = st.times.clamp(0, a.count);
  // one that counts up starts a new round once done, and counts the rounds
  final complete = done >= a.count && !a.cycles;
  // what it asks next (or, once complete, its top level)
  final next = a.atLevel(
    a.cycles
        ? st.cycle.clamp(0, a.count - 1)
        : (done >= a.count ? a.count - 1 : done),
  );
  final top = done == 0 ? null : a.atLevel(done - 1);
  final medal = medalColor(c, next.medal);
  final earnedColor = top == null ? null : medalColor(c, top.medal);
  final ghost = c.onSurface.withValues(alpha: .22);
  final locked = done == 0;
  Widget dim(Widget w) => locked ? Opacity(opacity: .55, child: w) : w;

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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
  final target = a.targetAt(next.level, languages: languages, words: words);

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
            color: i < done ? c.onSurface : tones.s3,
          ),
        ),
    ],
  );

  // a streak shows an icon for each of its levels instead
  final streakIcons = Row(
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
                color: i < done ? medalColor(c, a.levels[i].medal) : ghost,
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
  );

  final title = Row(
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: medal,
        ),
      ),
      if (a.tag != null || a.tagIcon != null) ...[
        const SizedBox(width: 6),
        TablerIcon(
          a.tagIcon ?? modeIconName(a.tag!),
          size: 13,
          color: c.onSurface.withValues(alpha: dimAlpha),
        ),
      ],
    ],
  );

  final showingBar = a.numbered && showBar && !complete;
  final below = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (a.separate) ...[
        const SizedBox(height: 6),
        streakIcons,
      ] else ...[
        const SizedBox(height: 6),
        pips(),
      ],
      if (showingBar) ...[
        const SizedBox(height: 6),
        _LevelBar(progress: st.value.toInt(), target: target, color: medal),
      ],
      if (badges.isNotEmpty) ...[
        const SizedBox(height: 6),
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
  );

  final right = done == 0
      ? null
      : Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$done/${a.count}',
              key: ValueKey('count-${a.id}'),
              style: TextStyle(fontWeight: FontWeight.bold, color: earnedColor),
            ),
            // done again: the games that did what the top level asks
            if (st.hits.length >= done && st.hits[done - 1] >= 1)
              Text(
                '×${st.hits[done - 1]}',
                key: ValueKey('times-${a.id}'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: earnedColor,
                ),
              ),
            Caption(st.latest ?? ''),
          ],
        );

  return GroupRow(
    key: ValueKey('${a.id}-row'),
    onTap: tap,
    chevron: false,
    leading: dim(TonalTile(a.icon, big: true, color: earnedColor ?? medal)),
    title: dim(title),
    subtitle: dim(Text(next.description)),
    below: dim(below),
    trailing: right,
  );
}

/// Language by language: how far each language is from mastery. It is a page
/// of its own ([Routes.mastery]), opened from the language mastery achievement.
class MasteryPage extends StatelessWidget {
  const MasteryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('language mastery'),
        actions: [const SettingsButton()],
      ),
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
                    padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
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

/// A progress bar of a row: 6 high on the tone three above the page, filled in
/// the medal of the next level, with the fraction beside it.
class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.progress,
    required this.target,
    required this.color,
  });
  final int progress;
  final int target;
  final Color color;

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
                  height: 6,
                  decoration: BoxDecoration(
                    color: tonesOf(context).s3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  key: const ValueKey('bar-fill'),
                  height: 6,
                  width: box.maxWidth * frac,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$progress/$target',
          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A row of a long list: the look of a [GroupedList] row (the tonal surface at
/// its radius, the leading, the title, the line and the rest, the trailing),
/// laid out directly in the page's lazy list.
class _LongRow extends StatelessWidget {
  const _LongRow(this.row, {required this.radius});
  final GroupRow row;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          crossAxisAlignment: row.crossAxisStart
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (row.leading != null) ...[
              row.leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    child: row.title,
                  ),
                  if (row.subtitle != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: c.onSurfaceVariant,
                      ),
                      child: row.subtitle!,
                    ),
                  if (row.below != null) row.below!,
                ],
              ),
            ),
            if (row.trailing != null) ...[
              const SizedBox(width: 8),
              DefaultTextStyle.merge(
                style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                child: row.trailing!,
              ),
            ],
          ],
        ),
      ),
    );
    return Material(
      key: row.key,
      color: tonesOf(context).s1,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: row.onTap == null ? body : InkWell(onTap: row.onTap, child: body),
    );
  }
}

/// The page of the history button: what was earned, and when.
class _HistoryPage extends StatelessWidget {
  const _HistoryPage(this.states);
  final Map<String, AchState> Function() states;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('history'),
        actions: [const SettingsButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
              children: [_History(c, states())],
            ),
          ),
        ),
      ),
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
