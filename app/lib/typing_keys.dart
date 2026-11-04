import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'equations.dart' show typedEquationChar;
import 'guess_input.dart' show ShiftTap;

/// What every screen that types a guess does with the keys, so that no screen
/// is without one of them: enter submits; backspace and delete take back a
/// letter, and with shift clear the whole row; the arrows move the cursor;
/// tapping shift locks the letter under the cursor (when the screen has locks);
/// any other key types its character (in the equations, `x` and the drawn signs
/// are the ASCII ones). Control and command are left to the system.
class TypingKeys {
  TypingKeys({
    required this.submit,
    required this.back,
    required this.clearRow,
    required this.move,
    required this.type,
    this.toggleLock,
    this.equations = false,
  });

  final VoidCallback submit;
  final VoidCallback back;
  final VoidCallback clearRow;
  final void Function(int by) move;
  final void Function(String ch) type;

  /// Null on a screen with no locks.
  final VoidCallback? toggleLock;
  final bool equations;

  final _shift = ShiftTap();

  KeyEventResult handle(KeyEvent e) {
    if (toggleLock != null && _shift.tapped(e)) {
      toggleLock!();
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter) {
      submit();
    } else if (k == LogicalKeyboardKey.backspace ||
        k == LogicalKeyboardKey.delete) {
      if (keys.isShiftPressed) {
        clearRow();
      } else {
        back();
      }
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      move(-1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      move(1);
    } else if (e.character != null) {
      final ch = e.character!.toLowerCase();
      type(equations ? typedEquationChar(ch) : ch);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}
