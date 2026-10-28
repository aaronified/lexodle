import 'package:flutter/material.dart';

import 'logic.dart' show luckText;
import 'main.dart';
import 'playstyle.dart';
import 'routes.dart';
import 'ui.dart';

/// A hairline box, as the cards of the history page.
Widget hairlineCard(BuildContext context, {Key? key, required Widget child}) {
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

/// The playstyle now, the habits it is read from with the exact shares, and
/// which of the six the player has been. The history page shows it at its top,
/// and the home page's playstyle button opens it in a popup
/// ([PlaystyleDialog]).
class PlaystyleCard extends StatefulWidget {
  const PlaystyleCard(this.lang, {super.key, this.bordered = true});

  /// The language it is for.
  final String lang;

  /// Whether it has its own hairline box (not when it sits in a popup that has
  /// one).
  final bool bordered;

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
    '$styleWindow classic games, and needs $minRatedGames games and '
    '$minPhaseGuesses guesses in each phase.';

class _PlaystyleCardState extends State<PlaystyleCard> {
  /// The style whose description is open: tapped, since a tooltip needs a hover
  /// or a long press, which a phone does not give.
  Playstyle? _picked;

  Widget _behaviour(
    ColorScheme c,
    Habits h,
    Behaviour b, {
    required bool habit,
  }) {
    final n = h.opportunities[b.phase] ?? 0;
    final k = h.counts[b] ?? 0;
    final color = habit ? c.primary : c.onSurface.withValues(alpha: dimAlpha);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        key: ValueKey('habit-${b.label}'),
        children: [
          TablerIcon(b.icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              b.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: habit ? FontWeight.bold : FontWeight.normal,
                color: habit ? null : color,
              ),
            ),
          ),
          Text(
            n == 0 ? '–' : '${(h.share(b) * 100).round()}%  ($k of $n)',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lang = widget.lang;
    final p = appState.styleOf(lang);
    final t = traitsOf(appState.history, lang: lang);
    final h = habitsOf(appState.history, lang: lang);
    final games = appState.history.recentClassic(100, lang).length;
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
      return 'not enough early and end game guesses yet';
    }

    Widget phaseBlock(Phase phase, String title, String sub) {
      final habit = h.habit(phase);
      return Column(
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
      );
    }

    final body = Column(
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
              StatTile('skill', t.skill.round().toString()),
              StatTile('luck', luckText(t.luck)),
              StatTile('risk', t.risk.round().toString()),
              StatTile('games', t.games.toString()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'the means over your last ${t.games} classic '
            '${t.games == 1 ? 'game' : 'games'}, up to $styleWindow',
            style: dim.copyWith(fontSize: 11),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Caption('your habits')),
            InfoDot(howStyleIsRead, title: 'how a style is read'),
          ],
        ),
        const SizedBox(height: 6),
        phaseBlock(
          Phase.early,
          'early game',
          '$earlyFrom or more words possible',
        ),
        const SizedBox(height: 10),
        phaseBlock(
          Phase.end,
          'end game',
          '$endUpTo or fewer words possible, or $endGreens greens',
        ),
        const SizedBox(height: 14),
        // the six share the card's width, so they fit the narrowest phone,
        // and a name shrinks before it can touch its neighbour
        Row(
          children: [
            for (final s in playstyles)
              Expanded(
                child: _StyleDot(
                  s,
                  held: appState.stylesHeldOf(lang).contains(s.id),
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
        if (_picked case final s?) ...[
          Text(
            '${s.name}: ${s.blurb}'
            '${s.id == p?.id
                ? ' (your style now)'
                : appState.stylesHeldOf(lang).contains(s.id)
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
                    TablerIcon(b.icon, size: 16, color: c.primary),
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
            appState.styleChangesOf(lang) == 0
                ? 'tap a style to see what it is. it moves with the way you '
                      'play'
                : 'tap a style to see what it is. changed '
                      '${appState.styleChangesOf(lang)} '
                      '${appState.styleChangesOf(lang) == 1 ? 'time' : 'times'}',
            style: dim.copyWith(fontSize: 11),
          ),
      ],
    );
    return widget.bordered
        ? hairlineCard(context, key: const ValueKey('profile'), child: body)
        : KeyedSubtree(key: const ValueKey('profile'), child: body);
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

/// The playstyle card as a popup, shaped like the game modes one: a hairline
/// box on the app's own background, a close cross at the top right, and a
/// history button at the bottom, which goes to the history page. It is a route
/// of its own ([Routes.playstyle]).
class PlaystyleDialog extends StatelessWidget {
  const PlaystyleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the close button sits 8 from the top and the right edge
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'playstyle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('playstyle-close'),
                    tooltip: 'close',
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                // it listens, so a game finished behind it is read at once
                child: ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) =>
                      PlaystyleCard(appState.lang, bordered: false),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('playstyle-history'),
                  // replaces the popup, so back from the history is home
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, Routes.history),
                  child: const Text('history'),
                ),
              ),
            ),
          ],
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
