import 'package:flutter/material.dart';

import 'app_log.dart';
import 'logic.dart' show luckText;
import 'main.dart';
import 'mode_filter.dart';
import 'modes.dart';
import 'playstyle.dart';
import 'routes.dart';
import 'ui.dart';

/// A shaded card, as those of the history page: radius 6. On the page's ground
/// (no [color]) it has the soft [hairline]; a card inside a card, one shade up
/// (a [color] given), has none.
Widget hairlineCard(
  BuildContext context, {
  Key? key,
  Color? color,
  required Widget child,
}) {
  final c = Theme.of(context).colorScheme;
  return Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color ?? c.surfaceContainerHighest,
      border: color == null ? Border.fromBorderSide(hairline(c)) : null,
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}

/// One shade up from a card's own: for a control that sits apart from the
/// cards (a button under the list) or inside one.
Color shadeUp(ColorScheme c) => Color.alphaBlend(
  c.onSurface.withValues(alpha: .08),
  c.surfaceContainerHighest,
);

/// The playstyle now, the habits it is read from with the exact shares, and
/// which of the six the player has been, as shaded rows. The playstyle screen
/// ([PlaystylePage]) shows it; the history page links to that screen.
class PlaystyleCard extends StatefulWidget {
  const PlaystyleCard(this.lang, {super.key});

  /// The language it is for.
  final String lang;

  @override
  State<PlaystyleCard> createState() => _PlaystyleCardState();
}

/// How a style is read: the long explanation behind the info dot.
final howStyleIsRead =
    'A playstyle is two habits. The early game is a guess made with 64 or more '
    'words still possible. The end game is 16 or fewer words possible, or 3 or '
    'more greens known. Each guess in a phase is counted as one thing, the first '
    'that applies. Early: a gambler (risk $gamblerRisk or more), else a maximiser '
    '(in the top $topRank% of all the guesses scored, by expected gain), else an '
    'eliminator ($freshLetters or more letters never tried). End: a closer (the '
    'guess fits every clue), else a prober (it does not fit, ranks in the top '
    '$topRank% and 3 or more words are left). Your habit in a phase is what '
    'most of its guesses were, if that is ${(habitShare * 100).round()}% or '
    'more. The two habits make the style. It is read from your last '
    '$styleWindow games of the mode, and needs $minRatedGames games and '
    '$minPhaseGuesses guesses in each phase.';

class _PlaystyleCardState extends State<PlaystyleCard> {
  /// The style whose description is open: tapped, since a tooltip needs a hover
  /// or a long press, which a phone does not give.
  Playstyle? _picked;

  /// The mode the card is about (null: all of them): the one being played to
  /// begin with, if it has playstyles.
  GameMode? _mode = hasPlaystyle(appState.mode) ? appState.mode : null;

  Widget _behaviour(
    ColorScheme c,
    Habits h,
    Behaviour b, {
    required bool habit,
  }) {
    final n = h.opportunities[b.phase] ?? 0;
    final k = h.counts[b] ?? 0;
    final own = behaviourColor(c, b.label);
    final color = habit ? own : own.withValues(alpha: .6);
    final share = n == 0 ? 0.0 : h.share(b);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        key: ValueKey('habit-${b.label}'),
        children: [
          Row(
            children: [
              TablerIcon(b.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: habit ? FontWeight.bold : FontWeight.normal,
                    color: color,
                  ),
                ),
              ),
              Text(
                n == 0 ? '–' : '${(share * 100).round()}%  ($k of $n)',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // the share of the phase's guesses, in the behaviour's colour
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 3,
              color: color,
              backgroundColor: c.outlineVariant.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.lang;
    final mode = _mode;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    // with no mode picked it is all of them: read from their games together,
    // and not kept, as each mode keeps its own
    final modes = [
      for (final m in GameMode.values)
        if (hasPlaystyle(m)) m,
    ];
    final p = mode == null
        ? classify(habitsOf(appState.history, mode: null, lang: lang))
        : appState.styleOf(lang, mode);
    final held = mode == null
        ? {for (final m in modes) ...appState.stylesHeldOf(lang, m)}
        : appState.stylesHeldOf(lang, mode);
    final changes = mode == null
        ? modes.fold(0, (n, m) => n + appState.styleChangesOf(lang, m))
        : appState.styleChangesOf(lang, mode);
    final t = traitsOf(appState.history, mode: mode, lang: lang);
    final h = habitsOf(appState.history, mode: mode, lang: lang);
    final label = mode == null ? 'all modes' : mode.label;
    final games = appState.history.recent(mode, 100, lang).length;
    String why() {
      if (games < minRatedGames) {
        return 'play ${minRatedGames - games} more ${mode == null ? '' : '$label '}'
            '${minRatedGames - games == 1 ? 'game' : 'games'} to be given a '
            'playstyle';
      }
      return 'not enough early and end game guesses yet';
    }

    Widget phaseBlock(Phase phase, String title, String sub) {
      final habit = h.habit(phase);
      return hairlineCard(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Caption(title)),
                Text(
                  '${h.opportunities[phase] ?? 0} guesses',
                  style: dim.copyWith(fontSize: 11),
                ),
              ],
            ),
            Text(sub, style: dim.copyWith(fontSize: 11)),
            for (final b in Behaviour.values.where((b) => b.phase == phase))
              _behaviour(c, h, b, habit: b == habit),
          ],
        ),
      );
    }

    final head = hairlineCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption('playstyle · $label', key: const ValueKey('profile-mode')),
          const SizedBox(height: 8),
          ModeFilter(
            modes: modes,
            selected: mode,
            onSelect: (m) => setState(() {
              _mode = m;
              _picked = null;
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TablerIcon(
                p?.icon ?? 'puzzle',
                key: ValueKey('profile-icon-${p?.id ?? 'unrated'}'),
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
                StatTile('skill', t.skill.round().toString()),
                StatTile('luck', luckText(t.luck)),
                StatTile('risk', t.risk.round().toString()),
                StatTile('games', t.games.toString()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'the means over your last ${t.games} ${mode == null ? '' : '$label '}'
              '${t.games == 1 ? 'game' : 'games'}, up to $styleWindow',
              style: dim.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
    final picker = hairlineCard(
      context,
      key: const ValueKey('style-picker'),
      color: shadeUp(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // the six share the card's width, so they fit the narrowest phone,
          // and a name shrinks before it can touch its neighbour
          Row(
            children: [
              for (final s in playstyles)
                Expanded(
                  child: _StyleDot(
                    s,
                    held: held.contains(s.id),
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
          if (_picked case final s?
              when !(s.id == p?.id || held.contains(s.id)))
            // a style not unlocked yet stays hidden: no name, no description
            Text(
              'a playstyle you have not been yet. it shows once you are rated it.',
              key: const ValueKey('style-detail'),
              style: const TextStyle(fontSize: 12, height: 1.4),
            )
          else if (_picked case final s?) ...[
            Text(
              '${s.name}: ${s.blurb}'
              '${s.id == p?.id
                  ? ' (your style now)'
                  : held.contains(s.id)
                  ? ' (you have been this)'
                  : ' (not yet)'}',
              key: const ValueKey('style-detail'),
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final b in [s.early, s.end])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TablerIcon(
                        b.icon,
                        size: 16,
                        color: behaviourColor(c, b.label),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b.phase == Phase.early
                            ? '${b.label} early'
                            : '${b.label} at the end',
                        style: dim,
                      ),
                    ],
                  ),
              ],
            ),
          ] else
            Text(
              changes == 0
                  ? 'tap a style to see what it is. it moves with the way you '
                        'play'
                  : 'tap a style to see what it is. changed '
                        '$changes '
                        '${changes == 1 ? 'time' : 'times'}',
              style: dim.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
    return Column(
      key: const ValueKey('profile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
          child: Row(
            children: [
              const Expanded(child: Caption('your habits')),
              InfoDot(howStyleIsRead, title: 'how a style is read'),
            ],
          ),
        ),
        phaseBlock(
          Phase.early,
          'early game',
          '$earlyFrom or more words possible',
        ),
        const SizedBox(height: 6),
        phaseBlock(
          Phase.end,
          'end game',
          '$endUpTo or fewer words possible, or $endGreens greens',
        ),
        const SizedBox(height: 6),
        picker,
      ],
    );
  }
}

/// One number with its name under it. skill, luck and risk show in their
/// own colours.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.prefix = 'stat'});
  final String label;
  final String value;

  /// Keeps the keys of one card apart from another's.
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // skill, luck and risk always show in their own colours
    final measure = const ['skill', 'luck', 'risk'].contains(label);
    final color = measure ? metricColor(c, label) : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          key: ValueKey('$prefix-$label'),
          style: TextStyle(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        measure
            ? Text(
                label,
                style: TextStyle(fontSize: 11, letterSpacing: .8, color: color),
              )
            : Caption(label),
      ],
    );
  }
}

/// The playstyle screen: a page with a back button, the playstyle card as
/// shaded rows, and a history button at the bottom, which goes to the history
/// page. It is a route of its own ([Routes.playstyle]).
class PlaystylePage extends StatelessWidget {
  const PlaystylePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('playstyle')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
              children: [
                // it listens, so a game finished behind it is read at once
                ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) => PlaystyleCard(appState.lang),
                ),
                const SizedBox(height: 6),
                Material(
                  color: shadeUp(c),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    key: const ValueKey('playstyle-history'),
                    borderRadius: BorderRadius.circular(6),
                    // replaces this page, so back from the history is home
                    onTap: () {
                      try {
                        Navigator.pushReplacementNamed(context, Routes.history);
                      } catch (e) {
                        appLog.w('playstyle', 'history: ${e.runtimeType}');
                      }
                    },
                    child: const SizedBox(
                      height: 48,
                      child: Center(child: Text('history')),
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
      label: held || current ? style.name : 'locked playstyle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          key: ValueKey('dot-${style.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: current
                ? c.secondaryContainer
                : picked
                ? c.surfaceContainerHighest
                : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            children: [
              if (held || current)
                TablerIcon(
                  style.icon,
                  size: 24,
                  color: behaviourColor(c, style.early.label),
                )
              else
                SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(fontSize: 18, color: c.outlineVariant),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  held || current ? style.name : '???',
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
