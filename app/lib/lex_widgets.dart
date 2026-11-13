import 'dart:async';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'lex.dart';
import 'logic.dart';
import 'ui.dart';

/// The widgets of lex and hints (issue #93): pure, they take values and
/// callbacks and never touch the app state.

/// What each hint is called in the tray and on the lex page.
String hintTitle(HintKind k) => switch (k) {
  HintKind.grey => 'rule one out',
  HintKind.yellow => 'a letter that is in',
  HintKind.green => 'a letter in its place',
};

/// What each hint does, in a few words.
String hintDoes(HintKind k) => switch (k) {
  HintKind.grey => 'a letter that is not in the word',
  HintKind.yellow => 'a letter that is in the word',
  HintKind.green => 'a letter and where it goes',
};

Mark _markOf(HintKind k) => switch (k) {
  HintKind.grey => Mark.absent,
  HintKind.yellow => Mark.present,
  HintKind.green => Mark.correct,
};

/// The lex balance as a pill: the scheme's green with the gem and the number in
/// yellow. 28px high, no border. [big] is the page's large balance. [joined]
/// squares its left corners, to sit against the hint part of a [HintBar].
class LexChip extends StatelessWidget {
  const LexChip(this.n, {super.key, this.big = false, this.joined = false});
  final int n;
  final bool big;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final y = yellowOf(c);
    final h = big ? 44.0 : 28.0;
    final r = Radius.circular(h / 2);
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: big ? 18 : 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.secondary,
        borderRadius: BorderRadius.horizontal(
          left: joined ? Radius.zero : r,
          right: r,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TablerIcon('diamond', size: big ? 24 : 16, color: y),
          SizedBox(width: big ? 8 : 5),
          Text(
            '$n',
            style: TextStyle(
              fontSize: big ? 26 : 14,
              height: 1,
              fontWeight: FontWeight.bold,
              color: y,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one control above the keyboard: a lamp, "hint" and "N free" on a surface
/// part, joined with no gap to the lex chip (hidden when [lex] is null). 28px
/// to look at, 44px to tap.
class HintBar extends StatelessWidget {
  const HintBar({
    super.key,
    required this.free,
    required this.lex,
    required this.onTap,
    this.expanded = false,
  });
  final int free;
  final int? lex;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final n = lex;
    final label = [
      'hint',
      if (free > 0) '$free free',
      if (n != null) '$n lex',
    ].join(', ');
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHigh,
                    borderRadius: BorderRadius.horizontal(
                      left: const Radius.circular(14),
                      right: n == null
                          ? const Radius.circular(14)
                          : Radius.zero,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TablerIcon('bulb', size: 16, color: c.onSurface),
                      const SizedBox(width: 6),
                      const Text(
                        'hint',
                        style: TextStyle(fontSize: 13, height: 1),
                      ),
                      if (free > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$free free',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (n != null) LexChip(n, joined: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long a hold takes to buy, how far a finger may drift, and how long a
/// first press stays armed for the keyboard path.
const holdDuration = Duration(milliseconds: 700);
const holdSlop = 24.0;
const armDuration = Duration(seconds: 4);

/// One row of the hint tray. Bought by holding until the bar is full; for
/// keyboard, screen reader and switch users, by activating it twice.
class HintHoldRow extends StatefulWidget {
  const HintHoldRow({
    super.key,
    required this.kind,
    required this.price,
    required this.free,
    required this.lex,
    required this.onBuy,
  });
  final HintKind kind;
  final int price;
  final int free;
  final int lex;
  final VoidCallback onBuy;

  @override
  State<HintHoldRow> createState() => _HintHoldRowState();
}

class _HintHoldRowState extends State<HintHoldRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: holdDuration,
  )..addStatusListener(_status);
  Offset? _down;
  bool _armed = false;
  Timer? _armTimer;

  bool get _canBuy => widget.free > 0 || widget.lex >= widget.price;

  @override
  void dispose() {
    _armTimer?.cancel();
    _hold.dispose();
    super.dispose();
  }

  void _status(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _down = null;
    _buy();
    _hold.reset();
  }

  void _buy() {
    _armTimer?.cancel();
    if (_armed && mounted) setState(() => _armed = false);
    try {
      widget.onBuy();
    } catch (e) {
      appLog.w('hint', 'could not buy a hint: ${e.runtimeType}');
    }
  }

  void _arm() {
    _armTimer?.cancel();
    setState(() => _armed = true);
    _armTimer = Timer(armDuration, () {
      if (mounted) setState(() => _armed = false);
    });
  }

  /// A screen reader, keyboard or switch activation: the first arms, the second
  /// buys.
  void _activate() {
    if (!_canBuy) return;
    if (_armed) {
      _buy();
    } else {
      _arm();
    }
  }

  bool get _reduced => MediaQuery.of(context).disableAnimations;

  void _pointerDown(PointerDownEvent e) {
    if (!_canBuy || _reduced) return;
    _down = e.position;
    _hold.forward(from: 0);
  }

  void _pointerMove(PointerMoveEvent e) {
    final d = _down;
    if (d == null) return;
    if ((e.position - d).distance > holdSlop) {
      _down = null;
      _hold.reset();
    }
  }

  void _pointerEnd(PointerEvent e) {
    if (!mounted) return;
    final held = _down != null;
    _down = null;
    if (!_canBuy) return;
    if (_reduced) {
      if (e is PointerUpEvent) _activate();
      return;
    }
    if (_hold.isAnimating) _hold.reset();
    if (held && e is PointerUpEvent) {
      showToast(context, 'keep holding until the bar is full');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (fill, fg) = markColors(c, _markOf(widget.kind));
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final free = widget.free > 0;
    final short = widget.price - widget.lex;
    final sub = !_canBuy
        ? 'you need $short more lex · earn it from achievement medals'
        : _armed
        ? 'press again to buy for ${free ? 'a free hint' : '${widget.price} lex'}'
        : 'hold to buy · ${hintDoes(widget.kind)}';
    final title = hintTitle(widget.kind);
    return Semantics(
      button: true,
      enabled: _canBuy,
      label: '$title, $sub',
      excludeSemantics: true,
      onTap: _canBuy ? _activate : null,
      child: Listener(
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerEnd,
        onPointerCancel: _pointerEnd,
        child: Opacity(
          opacity: _canBuy ? 1 : .55,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (context, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const ValueKey('hold-fill'),
                        widthFactor: _hold.value,
                        heightFactor: 1,
                        child: ColoredBox(color: fill.withValues(alpha: .35)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: TablerIcon('bulb', size: 20, color: fg),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: TextStyle(fontSize: 11, color: dim),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (free)
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'free · ${widget.free}',
                            style: const TextStyle(fontSize: 13, height: 1),
                          ),
                        )
                      else
                        LexChip(widget.price),
                    ],
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

/// A bought hint above the keyboard, in the tile colours and small: a green
/// hint is a row of five with the letter at [pos], a yellow or grey one a
/// single tile.
class HintMiniRow extends StatelessWidget {
  const HintMiniRow({
    super.key,
    required this.kind,
    required this.letter,
    this.pos = 0,
    this.length = 5,
  });
  final HintKind kind;
  final String letter;
  final int pos;

  /// The tiles of a green hint's row: the word's length.
  final int length;

  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final caption = switch (kind) {
      HintKind.green => 'in its place',
      HintKind.yellow => 'is in the word, somewhere',
      HintKind.grey => 'is not in the word',
    };
    Widget tile(String ch, {Mark? mark}) => ExcludeSemantics(
      child: SizedBox(
        width: _size,
        height: _size,
        child: MarkTile(ch, mark: mark, size: _size),
      ),
    );
    final tiles = kind == HintKind.green
        ? [
            for (var i = 0; i < length; i++)
              Padding(
                padding: EdgeInsets.only(right: i < length - 1 ? 3 : 0),
                child: i == pos ? tile(letter, mark: Mark.correct) : tile(''),
              ),
          ]
        : [tile(letter, mark: _markOf(kind))];
    return Semantics(
      label: kind == HintKind.green
          ? 'hint: $letter, in its place, position ${pos + 1}'
          : 'hint: $letter $caption',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...tiles,
          const SizedBox(width: 10),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ),
        ],
      ),
    );
  }
}
