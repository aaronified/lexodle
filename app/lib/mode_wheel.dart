import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import 'haptics.dart';
import 'modes.dart';
import 'ui.dart';

/// How many modes a drag across the whole button turns.
const modeDetents = 3;

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
  GameMode.equations => 'calculator',
  GameMode.mastermind => 'ghost',
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
    this.lang = 'en',
    required this.onChanged,
    required this.onOpen,
    required this.below,
    this.height = 52,
  });

  final GameMode mode;

  /// The language, which decides the modes the swipe has (themed is English only).
  final String lang;
  final ValueChanged<GameMode> onChanged;
  final VoidCallback onOpen;
  final Widget below;
  final double height;

  /// The mode [steps] along the loop from [from] (negative goes back).
  static GameMode step(GameMode from, int steps, {String lang = 'en'}) {
    final all = GameMode.loopFor(lang);
    final i = all.indexOf(from);
    // a mode the language does not have goes back into the loop
    if (i < 0) return steps > 0 ? all.first : all.last;
    return all[(i + steps) % all.length];
  }

  @override
  State<ModeSwitch> createState() => _ModeSwitchState();
}

class _ModeSwitchState extends State<ModeSwitch>
    with SingleTickerProviderStateMixin {
  /// How far the finger has gone, in pixels (left is negative), and where the
  /// ratchet is as a result, in modes: a drag of [modeDetents] detents across the
  /// button, one mode to each, so a full drag turns three. The face follows the
  /// finger inside a detent and takes the next mode as one is crossed, with a
  /// tick, as a ratchet does.
  double _acc = 0;
  double _pos = 0;
  int _ticked = 0;
  double _width = 1;
  double _from = 0, _to = 0;
  bool _busy = false;
  bool _moved = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  /// How far a finger goes for one mode, in pixels.
  double get _detent => _width / modeDetents;

  /// The mode the ratchet is on now: the one it was on, moved by the detents
  /// passed.
  GameMode get _shown =>
      ModeSwitch.step(widget.mode, _pos.round(), lang: widget.lang);

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _setPos(_from + (_to - _from) * t));
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Moves the ratchet to [p] detents, with a tick for each one crossed.
  void _setPos(double p) {
    _pos = p;
    final k = p.round();
    if (k != _ticked) {
      _ticked = k;
      Haptics.fire(Haptic.tap);
    }
  }

  /// Runs the ratchet on to [target] detents, then reports the mode it lands on.
  void _goTo(int target) {
    // nothing to run on from a ratchet at rest (a tap that cancelled a drag)
    if (_busy || (target == 0 && _pos == 0)) return;
    _busy = true;
    _from = _pos;
    _to = target.toDouble();
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _pos = 0;
        _ticked = 0;
        _busy = false;
      });
      if (target != 0) {
        widget.onChanged(
          ModeSwitch.step(widget.mode, target, lang: widget.lang),
        );
      }
    });
  }

  /// One mode along the loop (+1 next, -1 previous), for a chevron.
  void _step(int by) => _goTo(by);

  void _update(DragUpdateDetails d) {
    if (_busy) return;
    setState(() {
      _acc += d.delta.dx;
      if (_acc.abs() > 6) _moved = true;
      // dragged left brings the next mode, right the previous
      _setPos(-_acc / _detent);
    });
  }

  void _end(DragEndDetails d) {
    if (_busy) return;
    var target = _pos.round();
    final v = d.primaryVelocity ?? 0;
    // a short, fast flick is still one mode
    if (target == 0 && v.abs() >= modeSwipeSpeed) target = v < 0 ? 1 : -1;
    _acc = 0;
    _goTo(target);
    // the drag is over: the tap that may follow it on the button is a new one
    Future<void>.delayed(Duration.zero, () => _moved = false);
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

  /// The mode the ratchet is on, slid a little off centre by the finger inside
  /// its detent and fading as it nears the next.
  Widget _faces(ColorScheme c) {
    final f = _pos - _pos.round();
    return Center(
      child: Transform.translate(
        offset: Offset(-f * _detent, 0),
        child: Opacity(
          key: const ValueKey('mode-face'),
          opacity: 1 - f.abs() * 0.9,
          child: _face(c, _shown),
        ),
      ),
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
      // the drag is tracked from where the finger went down, so it follows it 1:1
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _end(DragEndDetails()),
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
              for (final m in GameMode.loopFor(widget.lang))
                Container(
                  key: ValueKey('mode-dot-${m.name}'),
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m == _shown ? c.primary : c.outlineVariant,
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
