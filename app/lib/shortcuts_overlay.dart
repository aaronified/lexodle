import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How long Alt is held before the list of shortcuts shows.
const shortcutsDelay = Duration(milliseconds: 100);

/// Every shortcut and gesture of the app, by heading: the keys or the gesture,
/// and what they do.
const shortcutGroups = <(String, List<(String, String)>)>[
  (
    'keyboard · game',
    [
      ('a–z · 0–9 · + − * /', 'type in the tile with the thick border'),
      ('x', 'types × in an equation'),
      ('space', 'a blank: a pencil mark for a tile not worked out'),
      ('enter', 'submit the guess'),
      ('backspace · delete', 'clear a tile'),
      ('shift + backspace', 'erase the whole row being typed'),
      ('← →', 'move the cursor'),
      ('shift (tap)', 'lock or unlock the letter under the cursor'),
      ('ctrl (tap)', 'blind: next colour on the letter under the cursor'),
    ],
  ),
  (
    'keyboard · everywhere',
    [
      ('↑ ↓', 'scroll whatever the mouse is over'),
      ('← →', 'step a swiper, a review, or the mode on the home page'),
      ('alt (hold)', 'this list'),
    ],
  ),
  (
    'gestures',
    [
      ('tap a tile', 'move the cursor there'),
      ('drag along the keyboard', 'move the cursor, a tile at a time'),
      ('double tap a tile', 'lock or unlock its letter'),
      ('double tap the guesses', 'lock every green found so far'),
      ('swipe right to left on the row', 'erase the row being typed'),
      ('blind: tap a guess letter', 'pencil a colour: green, yellow, grey'),
      ('blind: double tap the counts', 'lock the pencilled greens'),
      ('swipe the mode button', 'turn through the modes, three to a drag'),
      ('drag the end panel', 'raise or lower it'),
    ],
  ),
];

/// Holds [child] (the whole app) and, while Alt is held (after
/// [shortcutsDelay]), draws over it a frosted pane listing the keyboard
/// shortcuts and the gestures. It takes no key and no touch: everything under it
/// goes on working.
class ShortcutsOverlay extends StatefulWidget {
  const ShortcutsOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<ShortcutsOverlay> createState() => _ShortcutsOverlayState();
}

class _ShortcutsOverlayState extends State<ShortcutsOverlay> {
  Timer? _timer;
  bool _shown = false;

  static bool _isAlt(KeyEvent e) =>
      e.logicalKey == LogicalKeyboardKey.altLeft ||
      e.logicalKey == LogicalKeyboardKey.altRight;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (!_isAlt(e)) return false;
    if (e is KeyDownEvent) {
      _timer ??= Timer(shortcutsDelay, () {
        _timer = null;
        if (mounted && HardwareKeyboard.instance.isAltPressed) {
          setState(() => _shown = true);
        }
      });
    } else if (e is KeyUpEvent) {
      _timer?.cancel();
      _timer = null;
      // the other Alt key may still be down
      if (_shown && !HardwareKeyboard.instance.isAltPressed) {
        setState(() => _shown = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_shown) const Positioned.fill(child: IgnorePointer(child: _Pane())),
    ],
  );
}

class _Pane extends StatelessWidget {
  const _Pane();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        key: const ValueKey('shortcuts-pane'),
        color: c.surface.withValues(alpha: .55),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (heading, rows) in shortcutGroups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(
                        heading,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: c.primary,
                        ),
                      ),
                    ),
                    for (final (keys, what) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 210,
                              child: Text(
                                keys,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                what,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
