import 'dart:math';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'equations.dart' show faceOf;
import 'swipe_clear.dart' show CursorDrag;
import 'haptics.dart';
import 'logic.dart';
import 'tonal.dart';
import 'ui.dart';

/// The widest screen that counts as a phone: below it the keyboard is bigger.
const phoneWidth = 600.0;

/// The on-screen keyboard: QWERTY for the letters the language uses, then the
/// language's own extra letters (accents and the like), with keys coloured by
/// what the game has learned about them.
class LetterKeyboard extends StatelessWidget {
  const LetterKeyboard({
    super.key,
    required this.letters,
    required this.onLetter,
    required this.onEnter,
    required this.onBack,
    this.onBlank,
    this.marks = const {},
    this.quadMarks = const {},
    this.enterLabel = 'enter',
    this.enterEnabled = true,
    this.numberPad = false,
    this.faces = faceOf,
    this.onCursor,
    this.chances = const {},
    this.popups = true,
  });

  /// Per letter, the chance that a copy is in place (green) and that a copy is
  /// in the word and not yet in place (yellow): the key shows them as one
  /// column filling it from the bottom, the green first and the yellow on top of
  /// it. A letter with a mark of [marks] is drawn by its mark instead.
  final Map<String, (double, double)> chances;

  /// Moves the cursor of the row being typed by this many tiles: a drag along
  /// the space key (the blank, `_`) does it, as along a phone keyboard's space
  /// bar. Only the games give it; the solvers and the rest do not.
  final void Function(int by)? onCursor;

  /// The number pad of the equations, in place of the letters: the signs along
  /// the top, 7 8 9 / 4 5 6 / 1 2 3 with + and enter tall on the right, then 0
  /// and a wide backspace, and the space (a blank, whose drag moves the cursor)
  /// under it.
  final bool numberPad;

  /// What a key is drawn as.
  final String Function(String) faces;

  /// Whether a pressed letter key shows a small popup with its letter above it.
  /// The games turn it off when nothing could take the letter (the game is
  /// over): the key still sinks under the finger.
  final bool popups;

  final Set<String> letters;
  final Map<String, Mark> marks;

  /// For the games with several boards: per letter, what each board says about
  /// it. A key with any of these is split into equal parts, one per board in
  /// reading order (top left, top right, bottom left, bottom right), each in
  /// that board's feedback colour, with no edge or gap between them.
  final Map<String, List<Mark?>> quadMarks;
  final void Function(String) onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBack;

  /// Types a blank, a pencil mark for a letter not worked out yet. When set, a
  /// wide key for it sits on a row of its own under the letters.
  final VoidCallback? onBlank;
  final String enterLabel;

  /// False greys the enter key out and makes it do nothing (the maker's create
  /// key until the word is ready).
  final bool enterEnabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _build(context, box.maxWidth < phoneWidth),
  );

  Widget _build(BuildContext context, bool phone) {
    final c = Theme.of(context).colorScheme;
    final tones = tonesOf(context);
    // on a phone the keys are taller and wider (the keys of the phone's own
    // keyboard are about this size), with the letters bigger
    final keyHeight = phone ? 58.0 : 46.0;
    final gap = phone ? 2.0 : 2.5;
    const base = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    final extra = letters.where((l) => !base.join().contains(l)).toList()
      ..sort();
    final rows = <List<String>>[
      for (final r in base) r.split('').where(letters.contains).toList(),
      for (var i = 0; i < extra.length; i += 10)
        extra.sublist(i, min(i + 10, extra.length)),
    ];
    // the enter key, greyed out when it cannot be used
    final enterTap = enterEnabled ? onEnter : () {};
    final enterColors = enterEnabled
        ? (c.primary, c.onPrimary)
        : (c.surfaceContainerHighest, c.onSurface.withValues(alpha: dimAlpha));
    final enterFeel = enterEnabled ? Haptic.submit : Haptic.key;
    // enter and backspace flank the third row of letters
    const actionRow = 2;

    // Letters take the feedback colours; the two action keys have colours of
    // their own, from the scheme: enter is the accent, backspace the error
    // container, so neither can be mistaken for a letter or its feedback.
    Widget key(
      String label,
      VoidCallback tap, {
      Mark? mark,
      double flex = 1,
      (Color fill, Color fg)? colors,
      List<Mark?>? quad,
      (double, double)? chance,
      Haptic feel = Haptic.key,
      void Function(int by)? drag,
      bool space = false,
    }) {
      // a single letter, digit or sign shows a popup; enter, delete, the space and
      // the words on the action keys do not
      final popup = popups && label.length == 1 && label != '_' && drag == null;
      // each press has its own feel (see [Haptic])
      void press() {
        Haptics.fire(feel);
        tap();
      }

      if (quad != null && quad.any((m) => m != null)) {
        return Expanded(
          flex: (flex * 10).round(),
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: _Press(
              popup: popup,
              popupFill: tones.s3,
              popupFg: c.onSurface,
              child: InkWell(
                onTap: press,
                borderRadius: BorderRadius.circular(radiusInner),
                child: _QuadKey(label: label, marks: quad, height: keyHeight),
              ),
            ),
          ),
        );
      }
      if (chance != null && mark == null) {
        return Expanded(
          flex: (flex * 10).round(),
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: _Press(
              popup: popup,
              popupFill: tones.s3,
              popupFg: c.onSurface,
              child: InkWell(
                onTap: press,
                borderRadius: BorderRadius.circular(radiusInner),
                child: _ChanceKey(
                  label: label,
                  green: chance.$1,
                  yellow: chance.$2,
                  height: keyHeight,
                ),
              ),
            ),
          ),
        );
      }
      // a key not tried yet is outlined, like an empty tile; a mark or an
      // action key is a plain fill of its own
      Color? fill;
      var fg = c.onSurface;
      if (mark != null) (fill, fg) = markColors(c, mark);
      if (colors != null) (fill, fg) = colors;
      final button = InkWell(
        onTap: press,
        borderRadius: BorderRadius.circular(radiusInner),
        child: Container(
          height: space ? 50 : keyHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: fill == null ? Border.all(color: tones.line) : null,
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: label.length > 1
                  ? (phone ? 13 : 11)
                  : (phone ? 21 : 16),
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
      );
      // the key sinks under the finger (an untried one takes the tonal fill) and
      // a letter shows a popup above it; the action keys and the space only sink
      final pressed = _Press(
        popup: popup,
        popupFill: (mark != null || colors != null) ? fill : tones.s3,
        popupFg: fg,
        pressFill: mark == null && colors == null ? tones.s1 : null,
        child: button,
      );
      return Expanded(
        flex: (flex * 10).round(),
        child: Padding(
          padding: EdgeInsets.all(gap),
          // a drag along the key (the space) moves the cursor; a tap presses it
          child: drag == null
              ? pressed
              : CursorDrag(onMove: drag, child: pressed),
        ),
      );
    }

    if (numberPad) {
      // one cell of the pad, and a key two cells tall for + and enter
      final cell = keyHeight + 2 * gap;
      Widget digit(String ch) =>
          key(faces(ch), () => onLetter(ch), mark: marks[ch]);
      Widget tall(Widget k) => SizedBox(
        height: cell * 2,
        child: Column(children: [k]),
      );
      return Center(
        child: ConstrainedBox(
          // a number pad is narrower than a row of letters
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: phone ? 2 : 6),
            child: Column(
              children: [
                Row(children: [digit('='), digit('/'), digit('*'), digit('-')]),
                Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: Column(
                        children: [
                          Row(children: [digit('7'), digit('8'), digit('9')]),
                          Row(children: [digit('4'), digit('5'), digit('6')]),
                        ],
                      ),
                    ),
                    Expanded(flex: 10, child: tall(digit('+'))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: Column(
                        children: [
                          Row(children: [digit('1'), digit('2'), digit('3')]),
                          Row(
                            children: [
                              digit('0'),
                              key(
                                '⌫',
                                onBack,
                                flex: 2,
                                colors: (c.errorContainer, c.onErrorContainer),
                                feel: Haptic.erase,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: tall(
                        key(
                          enterLabel,
                          enterTap,
                          colors: enterColors,
                          feel: enterFeel,
                        ),
                      ),
                    ),
                  ],
                ),
                // the space: a tap is a blank, a drag along it moves the cursor
                if (onBlank != null)
                  Row(
                    children: [
                      key('_', onBlank!, flex: 4, drag: onCursor, space: true),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final pad = Padding(
      padding: EdgeInsets.symmetric(horizontal: phone ? 2 : 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Row(
              children: [
                // a short row of a language's extra letters keeps keys of the
                // same size, centred, not stretched across the whole row
                if (i > 2 && rows[i].length < 10)
                  Spacer(flex: (10 - rows[i].length) * 5),
                if (i == actionRow)
                  key(
                    enterLabel,
                    enterTap,
                    flex: 1.6,
                    colors: enterColors,
                    feel: enterFeel,
                  ),
                for (final l in rows[i])
                  key(
                    faces(l),
                    () => onLetter(l),
                    mark: marks[l],
                    quad: quadMarks[l],
                    chance: chances[l],
                  ),
                if (i == actionRow)
                  key(
                    '⌫',
                    onBack,
                    flex: 1.6,
                    colors: (c.errorContainer, c.onErrorContainer),
                    feel: Haptic.erase,
                  ),
                if (i > 2 && rows[i].length < 10)
                  Spacer(flex: (10 - rows[i].length) * 5),
              ],
            ),
          if (onBlank != null)
            Row(
              children: [
                const Spacer(flex: 20),
                key('_', onBlank!, flex: 6, drag: onCursor, space: true),
                const Spacer(flex: 20),
              ],
            ),
        ],
      ),
    );
    return pad;
  }
}

/// One key split in four by board: a 2 x 2 of the boards' colours, the letter
/// over it in whichever of the page's two text colours reads best on their
/// average. The parts are painted without anti-aliasing at their shared edges,
/// so no seam shows between them.
/// A key under the finger: it sinks to 93% in 90 ms (an untried key takes the
/// [pressFill] tone under it), and a key with a [popup] shows a small key with
/// its letter above it, so the finger does not hide the letter. The popup stays
/// inside the screen (the keys at the edge shift it inward). Reduced motion
/// shows the same without the animation.
class _Press extends StatefulWidget {
  const _Press({
    required this.child,
    required this.popup,
    required this.popupFill,
    required this.popupFg,
    this.pressFill,
  });
  final Widget child;
  final bool popup;
  final Color popupFill, popupFg;
  final Color? pressFill;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;
  OverlayEntry? _entry;
  static const _popupWidth = 44.0, _popupHeight = 56.0, _gap = 6.0;

  void _on(PointerDownEvent e) {
    setState(() => _down = true);
    if (!widget.popup) return;
    try {
      final box = context.findRenderObject() as RenderBox?;
      final overlay = Overlay.maybeOf(context);
      if (box == null || !box.attached || overlay == null) return;
      final at = box.localToGlobal(Offset.zero);
      final screen = MediaQuery.sizeOf(context).width;
      final left = (at.dx + box.size.width / 2 - _popupWidth / 2).clamp(
        4.0,
        screen - _popupWidth - 4,
      );
      final top = at.dy - _popupHeight - _gap;
      final label = _label(widget.child);
      if (label == null) return;
      final still = MediaQuery.disableAnimationsOf(context);
      _entry = OverlayEntry(
        builder: (_) => Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? 1 : 0, end: 1),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 6),
                  child: Transform.scale(scale: .9 + .1 * t, child: child),
                ),
              ),
              child: Container(
                key: const ValueKey('key-popup'),
                width: _popupWidth,
                height: _popupHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.popupFill,
                  borderRadius: BorderRadius.circular(radiusElement),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.popupFg,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_entry!);
    } catch (e) {
      appLog.w('keyboard', 'popup failed ${e.runtimeType}');
      _hide();
    }
  }

  /// The letter on the key: the first [Text] under it.
  String? _label(Widget w) {
    String? found;
    void visit(Element el) {
      if (found != null) return;
      final wd = el.widget;
      if (wd is Text && wd.data != null) {
        found = wd.data;
        return;
      }
      el.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  void _off([PointerEvent? e]) {
    _hide();
    if (mounted && _down) setState(() => _down = false);
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: _on,
      onPointerUp: _off,
      onPointerCancel: _off,
      child: AnimatedScale(
        scale: _down ? .93 : 1,
        duration: still ? Duration.zero : const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _down ? widget.pressFill : null,
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _QuadKey extends StatelessWidget {
  const _QuadKey({
    required this.label,
    required this.marks,
    required this.height,
  });
  final String label;
  final List<Mark?> marks;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colors = [
      for (var i = 0; i < 4; i++)
        i < marks.length && marks[i] != null
            ? markColors(c, marks[i]!).$1
            : null,
    ];
    // the average of what is behind the letter, an unset part being the page
    final base = tonesOf(context).s1;
    final shown = [for (final x in colors) x ?? base];
    final avg = Color.fromARGB(
      255,
      shown.map((x) => (x.r * 255).round()).reduce((a, b) => a + b) ~/ 4,
      shown.map((x) => (x.g * 255).round()).reduce((a, b) => a + b) ~/ 4,
      shown.map((x) => (x.b * 255).round()).reduce((a, b) => a + b) ~/ 4,
    );
    // the letter has an outline of the opposite colour, so it reads over any of
    // the four parts, yellow and green included
    final ink = onColor(c, avg);
    // (the other of the page's two text colours)
    final halo = ink == c.surface ? c.onSurface : c.surface;
    // the key's fill is the tonal one, so a key the boards have all greyed (or
    // left clear) still stands out from the page, with no shadow or edge
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radiusInner),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusInner),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: ValueKey('quad-$label'),
                painter: QuadPainter(colors),
              ),
              Center(child: _HaloText(label, ink, halo)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One key that shows a letter's chances as a column filling it from the
/// bottom: green (a copy in place) at the foot, yellow (a copy in the word, not
/// in place yet) on top of it. The letter is drawn as the quartet keyboard's.
class _ChanceKey extends StatelessWidget {
  const _ChanceKey({
    required this.label,
    required this.green,
    required this.yellow,
    required this.height,
  });
  final String label;
  final double green;
  final double yellow;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    var g = green.clamp(0.0, 1.0), y = yellow.clamp(0.0, 1.0);
    if (g + y > 1) {
      final k = 1 / (g + y);
      g *= k;
      y *= k;
    }
    final inner = height;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: tonesOf(context).s1,
        borderRadius: BorderRadius.circular(radiusInner),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: g * inner,
              child: ColoredBox(
                key: ValueKey('chance-g-$label'),
                color: markColors(c, Mark.correct).$1,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: g * inner,
              height: y * inner,
              child: ColoredBox(
                key: ValueKey('chance-y-$label'),
                color: markColors(c, Mark.present).$1,
              ),
            ),
            Center(child: _HaloText(label, c.onSurface, c.surface)),
          ],
        ),
      ),
    );
  }
}

/// Paints [colors] (null = leave clear) as the four quarters of its box.
class QuadPainter extends CustomPainter {
  QuadPainter(this.colors);
  final List<Color?> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 2, h = size.height / 2;
    for (var i = 0; i < 4; i++) {
      final color = colors[i];
      if (color == null) continue;
      final x = (i % 2) * w, y = (i ~/ 2) * h;
      canvas.drawRect(
        Rect.fromLTWH(x, y, w + (i % 2 == 0 ? .5 : 0), h + (i < 2 ? .5 : 0)),
        Paint()
          ..color = color
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(QuadPainter old) =>
      old.colors.toString() != colors.toString();
}

/// A letter drawn over colours of every kind: in [color], with a ring of
/// shadows of [halo] all round it (and a soft one), so it can be read on yellow,
/// green and grey alike. One Text, so it is found and tapped as any letter.
class _HaloText extends StatelessWidget {
  const _HaloText(this.text, this.color, this.halo);
  final String text;
  final Color color;
  final Color halo;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      color: color,
      shadows: [
        for (final (dx, dy) in const [
          (-1.5, 0.0),
          (1.5, 0.0),
          (0.0, -1.5),
          (0.0, 1.5),
          (-1.1, -1.1),
          (1.1, -1.1),
          (-1.1, 1.1),
          (1.1, 1.1),
        ])
          Shadow(
            color: halo.withValues(alpha: .9),
            offset: Offset(dx, dy),
            blurRadius: 1,
          ),
        Shadow(color: halo.withValues(alpha: .7), blurRadius: 5),
      ],
    ),
  );
}
