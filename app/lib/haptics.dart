import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';

/// The kinds of touch feedback, from the lightest to the heaviest, each a
/// different strength or pattern so a press can be told by feel.
enum Haptic {
  /// A letter key: a light tap.
  key,

  /// Backspace: the small click of a picker.
  erase,

  /// Enter, and the buttons that go somewhere: a medium tap.
  submit,

  /// A word that is not allowed, or already guessed: a heavy knock.
  reject,

  /// Any other press (a button, a tile, a stepper): the click of a picker.
  tap,

  /// A game won: a heavy knock, then a lighter one.
  win,

  /// A game lost: the phone's long vibration.
  lose,

  /// A heart broken in lockdown: a rumble, three knocks one on the other.
  heartBreak,
}

/// Touch feedback through the phone's vibration motor. It is there on Android
/// and iOS, off on the web and on a desktop, and off when the player has turned
/// it off in the settings.
class Haptics {
  const Haptics._();

  /// When the last one was fired, so the catch-all for plain taps does not add
  /// a second buzz to a press that has its own.
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether this platform has a vibration motor to use.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static void fire(Haptic kind) {
    if (!appState.haptics || !supported) return;
    _last = DateTime.now();
    switch (kind) {
      case Haptic.key:
        unawaited(HapticFeedback.lightImpact());
      case Haptic.erase:
      case Haptic.tap:
        unawaited(HapticFeedback.selectionClick());
      case Haptic.submit:
        unawaited(HapticFeedback.mediumImpact());
      case Haptic.reject:
        unawaited(HapticFeedback.heavyImpact());
      case Haptic.win:
        unawaited(HapticFeedback.heavyImpact());
        _later(const Duration(milliseconds: 140), () {
          unawaited(HapticFeedback.lightImpact());
        });
      case Haptic.lose:
        unawaited(HapticFeedback.vibrate());
      case Haptic.heartBreak:
        unawaited(HapticFeedback.heavyImpact());
        _later(const Duration(milliseconds: 70), () {
          unawaited(HapticFeedback.heavyImpact());
        });
        _later(const Duration(milliseconds: 140), () {
          unawaited(HapticFeedback.mediumImpact());
        });
        _later(const Duration(milliseconds: 230), () {
          unawaited(HapticFeedback.heavyImpact());
        });
    }
  }

  /// Runs [action] after [after]. In the root zone, so a test's clock does not
  /// hold the test open for it.
  static void _later(Duration after, void Function() action) {
    Zone.root.createTimer(after, action);
  }

  /// Whether one was fired in the last [within].
  static bool recently([Duration within = const Duration(milliseconds: 120)]) =>
      DateTime.now().difference(_last) < within;
}

/// Gives every plain tap in the app the click of [Haptic.tap], unless the press
/// already gave its own feedback a moment before. A tap is a press and release
/// close together and close in place; a drag or a scroll is not one.
class TapHaptics extends StatefulWidget {
  const TapHaptics({super.key, required this.child});
  final Widget child;

  @override
  State<TapHaptics> createState() => _TapHapticsState();
}

class _TapHapticsState extends State<TapHaptics> {
  final _down = <int, (Offset, DateTime)>{};

  void _onDown(PointerDownEvent e) =>
      _down[e.pointer] = (e.position, DateTime.now());

  void _onUp(PointerUpEvent e) {
    final d = _down.remove(e.pointer);
    if (d == null) return;
    final moved = (e.position - d.$1).distance;
    final held = DateTime.now().difference(d.$2);
    if (moved > kTouchSlop || held > const Duration(milliseconds: 500)) return;
    // the press's own handler runs as the pointer goes up; give it a moment to
    // fire its feedback before deciding there was none
    Haptics._later(const Duration(milliseconds: 40), () {
      if (!Haptics.recently(const Duration(milliseconds: 100))) {
        Haptics.fire(Haptic.tap);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onDown,
    onPointerUp: _onUp,
    onPointerCancel: (e) => _down.remove(e.pointer),
    child: widget.child,
  );
}
