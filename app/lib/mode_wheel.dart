import 'package:flutter/material.dart';

import 'modes.dart';
import 'ui.dart';

/// How far a drag must go, in logical pixels, to change the mode on release.
const modeSwipeDistance = 50.0;

/// A fling faster than this (logical pixels a second) changes the mode too.
const modeSwipeSpeed = 700.0;

/// The name of the Tabler filled icon of each game mode: one piece, four
/// tiles, a knight, a lock.
String modeIconName(GameMode m) => switch (m) {
  GameMode.classic => 'puzzle',
  GameMode.quartet => 'layout-grid',
  GameMode.relay => 'chess-knight',
  GameMode.lockdown => 'lock',
  GameMode.themed => 'world',
  GameMode.blind => 'zoom-question',
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
    const all = GameMode.loop;
    final i = all.indexOf(from);
    // a mode of the popup only (themed, blind) goes back into the loop
    if (i < 0) return steps > 0 ? all.first : all.last;
    return all[(i + steps) % all.length];
  }

  @override
  State<ModeSwitch> createState() => _ModeSwitchState();
}

class _ModeSwitchState extends State<ModeSwitch>
    with SingleTickerProviderStateMixin {
  /// How far the mode on show is dragged, in pixels: the next mode comes in
  /// from the side the finger is going, as wide as the button, and the pair
  /// follows the finger.
  double _dx = 0;
  double _width = 1;
  double _from = 0, _to = 0;
  bool _busy = false;
  bool _moved = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _dx = _from + (_to - _from) * t);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Slides to the mode [by] along the loop (+1 next, -1 previous), then
  /// reports it.
  void _step(int by) {
    if (_busy) return;
    _busy = true;
    _from = _dx;
    _to = by > 0 ? -_width : _width;
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _dx = 0;
        _busy = false;
      });
      widget.onChanged(ModeSwitch.step(widget.mode, by));
    });
  }

  /// Slides back to the mode on show.
  void _settle() {
    if (_busy || _dx == 0) return;
    _busy = true;
    _from = _dx;
    _to = 0;
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _dx = 0;
        _busy = false;
      });
    });
  }

  void _update(DragUpdateDetails d) {
    if (_busy) return;
    setState(() {
      _dx = (_dx + d.delta.dx).clamp(-_width, _width);
      if (_dx.abs() > 6) _moved = true;
    });
  }

  void _end(DragEndDetails d) {
    if (_busy) return;
    final v = d.primaryVelocity ?? 0;
    final far = _dx.abs() >= modeSwipeDistance;
    if (far || v.abs() >= modeSwipeSpeed) {
      // dragged left brings the next mode, right the previous
      final dir = far ? _dx.sign : v.sign;
      _step(dir < 0 ? 1 : -1);
    } else {
      _settle();
    }
  }

  Widget _face(ColorScheme c, GameMode m) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 44),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablerIcon(modeIconName(m), size: chooserIconSize, color: c.primary),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.label,
                key: ValueKey('mode-name-${m.name}'),
                style: const TextStyle(
                  fontSize: chooserLabelSize,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                modeSub(m),
                style: TextStyle(
                  fontSize: chooserSubSize,
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

  /// The mode on show and, while it is dragged, the one coming in beside it.
  Widget _faces(ColorScheme c) {
    final dir = _dx < 0 ? 1 : -1;
    final p = (_dx.abs() / _width).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(_dx, 0),
          child: Opacity(opacity: 1 - p, child: _face(c, widget.mode)),
        ),
        if (_dx != 0)
          Transform.translate(
            offset: Offset(_dx + (dir > 0 ? _width : -_width), 0),
            child: Opacity(
              key: const ValueKey('mode-incoming'),
              opacity: p,
              child: _face(c, ModeSwitch.step(widget.mode, dir)),
            ),
          ),
      ],
    );
  }

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
        onPressed: () => _step(by),
      ),
    );
    return GestureDetector(
      key: const ValueKey('play-area'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _settle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
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
                      child: LayoutBuilder(
                        builder: (context, box) {
                          _width = box.maxWidth.isFinite
                              ? box.maxWidth.clamp(1.0, 1e5)
                              : 1;
                          return SizedBox(
                            width: double.infinity,
                            height: widget.height,
                            child: _faces(c),
                          );
                        },
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
              for (final m in GameMode.loop)
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
