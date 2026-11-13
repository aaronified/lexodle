import 'package:flutter/material.dart';

import 'lex.dart';
import 'lex_widgets.dart';
import 'main.dart' show appState;
import 'store.dart';
import 'ui.dart';

/// The lex page (issue #93): the balance, what earns it, what hints cost, the
/// details and the recent ledger.
class LexPage extends StatelessWidget {
  const LexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('lex')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
            children: const [LexSection()],
          ),
        ),
      ),
    );
  }
}

/// The lex content, a column that sits on its own page and at the top of the
/// achievements page, which is where lex is earned.
class LexSection extends StatelessWidget {
  const LexSection({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) => _body(context, appState.lex),
  );

  /// The achievements shown as examples: (id, level index).
  static const _examples = [
    ('skill_avg', 1),
    ('quick', 1),
    ('wins', 0),
    ('played', 1),
  ];

  Widget _body(BuildContext context, Lex lex) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final now = DateTime.now();
    var today = 0;
    for (final e in lex.ledger) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.at);
      if (e.why.startsWith('earn:') &&
          e.delta > 0 &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        today += e.delta;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          c,
          Column(
            children: [
              LexChip(lex.balance, big: true),
              const SizedBox(height: 10),
              Text(
                'earned today: $today',
                key: const ValueKey('lex-today'),
                style: TextStyle(fontSize: 12, color: dim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Caption('how to earn it'),
        const SizedBox(height: 8),
        const Text(
          'earn a medal on any achievement and it pays lex',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          [for (final m in Medal.values) '${m.name} ${medalValue(m)}']
              .join(' · '),
          style: TextStyle(fontSize: 12, color: dim),
        ),
        const SizedBox(height: 6),
        for (final (id, lv) in _examples) _example(c, id, lv),
        const SizedBox(height: 8),
        Text(
          'each achievement pays once a day in each language, and only in a '
          'game where you used no hint. your streak is safe either way.',
          style: TextStyle(fontSize: 12, height: 1.4, color: dim),
        ),
        const SizedBox(height: 20),
        const Caption('hints cost'),
        const SizedBox(height: 4),
        for (final k in HintKind.values)
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hintTitle(k),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                LexChip(k.price),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _details(c, dim, lex),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              const FilledButton.tonal(onPressed: null, child: Text('buy lex')),
              const SizedBox(height: 6),
              Text(
                'soon · coming in an upcoming release',
                style: TextStyle(fontSize: 12, color: dim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(ColorScheme c, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      color: c.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
    ),
    child: child,
  );

  Widget _example(ColorScheme c, String id, int level) {
    final base = achievementById(id);
    if (base == null || level >= base.levels.length) {
      return const SizedBox.shrink();
    }
    final a = base.atLevel(level);
    final color = medalColor(c, a.medal);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          TablerIcon(a.icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  a.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.onSurface.withValues(alpha: dimAlpha),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${medalValue(a.medal)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(ColorScheme c, Color dim, Lex lex) {
    Widget line(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontSize: 13, height: 1.4)),
    );
    final recent = lex.ledger.reversed.take(10).toList();
    return Theme(
      data: ThemeData(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: const ValueKey('lex-details'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text(
          'the details',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'what each achievement pays, and the limits',
          style: TextStyle(fontSize: 12, color: dim),
        ),
        children: [
          line(
            [for (final m in Medal.values) '${m.name} ${medalValue(m)}']
                .join(' · '),
          ),
          line(
            'an achievement pays once a day per language. example: silver at '
            '9am pays 2, and again at 6pm the second pays 0. the next day it '
            'pays 2 again.',
          ),
          line(
            'if one game earns both gold and silver of the same achievement '
            'you get the higher: 3, not 5.',
          ),
          line(
            'in a daily your friends see that you used a hint, nothing more.',
          ),
          const SizedBox(height: 8),
          const Caption('recent'),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            Text(
              'nothing yet',
              key: const ValueKey('lex-empty'),
              style: TextStyle(fontSize: 13, color: dim),
            )
          else
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        _date(e.at),
                        style: TextStyle(fontSize: 12, color: dim),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _reason(e.why),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      e.delta > 0 ? '+${e.delta}' : '${e.delta}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec', //
  ];

  static String _date(int at) {
    final d = DateTime.fromMillisecondsSinceEpoch(at);
    return '${d.day} ${_months[d.month - 1]}';
  }

  /// A ledger code as a short readable line (never a word or a guess).
  static String _reason(String why) {
    final p = why.split(':');
    HintKind? kind() => p.length > 1 ? HintKind.named(p[1]) : null;
    switch (p.first) {
      case 'earn':
        final a = p.length > 1 ? achievementById(p[1]) : null;
        final lv = p.length > 2 ? int.tryParse(p[2]) : null;
        if (a == null) return 'achievement medal';
        final shown = lv != null && lv >= 0 && lv < a.levels.length
            ? a.atLevel(lv)
            : a;
        return shown.title;
      case 'hint':
        final k = kind();
        return k == null ? 'hint' : 'hint · ${hintTitle(k)}';
      case 'free':
        final k = kind();
        return k == null ? 'free hint' : 'free hint · ${hintTitle(k)}';
      case 'refund':
      case 'refund-free':
        return 'hint undone';
      case 'grant':
        return 'starting grant';
    }
    return 'lex';
  }
}
