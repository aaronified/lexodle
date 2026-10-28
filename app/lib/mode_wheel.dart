import 'package:flutter/material.dart';

import 'modes.dart';
import 'ui.dart';

/// How far a drag must go, in logical pixels, to change the mode on release.
const modeSwipeDistance = 50.0;

/// A fling faster than this (logical pixels a second) changes the mode too.
const modeSwipeSpeed = 700.0;

/// The name of the Tabler filled icon of each game mode: one piece, four
/// tiles, a knight.
String modeIconName(GameMode m) => switch (m) {
  GameMode.classic => 'puzzle',
  GameMode.quartet => 'layout-grid',
  GameMode.relay => 'chess-knight',
};

/// The mode under the modes' own line: "four words at once · +3 tries".
String modeSub(GameMode m) =>
    m.extraTries == 0 ? m.sub : '${m.sub} · +${m.extraTries} tries';

/// The mode button of the home page, with the play row under it: a loop of the
/// game modes (classic, quartet, relay race, and round to classic again, in both
/// directions). The chevrons, a swipe anywhere over [below] or the button, and
/// the arrow keys, all turn it: the mode's icon and name follow the finger.
/// A tap on the button opens the game modes ([onOpen]). [below] is the play and
/// the daily, which follow the mode the button shows.
class ModeSwitch extends StatefulWidget {
  const ModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.onOpen,
    required this.below,
    this.height = 52,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onChanged;
  final VoidCallback onOpen;
  final Widget below;
  final double height;

  /// The mode [steps] along the loop from [from] (negative goes back).
  static GameMode step(GameMode from, int steps) {
    const all = GameMode.values;
    return all[(from.index + steps) % all.length];
  }

  @override
  State<ModeSwitch> createState() => _ModeSwitchState();
}

class _ModeSwitchState extends State<ModeSwitch> {
  double _drag = 0;
  bool _moved = false;

  void _change(int by) => widget.onChanged(ModeSwitch.step(widget.mode, by));

  void _update(DragUpdateDetails d) {
    setState(() {
      _drag += d.delta.dx;
      if (_drag.abs() > 6) _moved = true;
    });
  }

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _drag;
    setState(() => _drag = 0);
    if (dx.abs() >= modeSwipeDistance || v.abs() >= modeSwipeSpeed) {
      // dragged left brings the next mode, right the previous
      final dir = dx.abs() >= modeSwipeDistance ? dx.sign : v.sign;
      _change(dir < 0 ? 1 : -1);
    }
  }

  Widget _face(ColorScheme c, GameMode m) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 44),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablerIcon(modeIconName(m), size: 24, color: c.primary),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.label,
                key: ValueKey('mode-name-${m.name}'),
                style: const TextStyle(letterSpacing: 1.2, height: 1.1),
              ),
              Text(
                modeSub(m),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final chevron = c.onSurface.withValues(alpha: dimAlpha);
    Widget arrow(String key, IconData icon, String label, int by) => SizedBox(
      width: 44,
      height: widget.height,
      child: IconButton(
        key: ValueKey(key),
        tooltip: label,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: chevron),
        onPressed: () => _change(by),
      ),
    );
    return GestureDetector(
      key: const ValueKey('play-area'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => setState(() => _drag = 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              SizedBox(
                height: widget.height,
                child: Tooltip(
                  message: 'game modes',
                  child: OutlinedButton(
                    key: const ValueKey('mode-button'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      // a swipe that ended on the button is not a tap
                      if (_moved) {
                        _moved = false;
                        return;
                      }
                      widget.onOpen();
                    },
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset(_drag.clamp(-90.0, 90.0) * .6, 0),
                        child: _face(c, widget.mode),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 1,
                child: arrow(
                  'mode-prev',
                  Icons.chevron_left,
                  'previous mode',
                  -1,
                ),
              ),
              Positioned(
                right: 1,
                child: arrow('mode-next', Icons.chevron_right, 'next mode', 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            key: const ValueKey('mode-dots'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final m in GameMode.values)
                Container(
                  key: ValueKey('mode-dot-${m.name}'),
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m == widget.mode ? c.primary : c.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          widget.below,
        ],
      ),
    );
  }
}
