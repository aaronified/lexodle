import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'logic.dart';

/// The wrong-place yellow. The scheme's tertiary is too close to its green in
/// a muted Material You palette, so the yellow is its own warm hue, kept at a
/// lightness that reads in both themes.
Color yellowOf(ColorScheme c) => HSLColor.fromAHSL(
  1,
  47,
  .88,
  c.brightness == Brightness.dark ? .52 : .55,
).toColor();

/// Feedback colours. Green (secondary) is the right letter in the right place,
/// yellow the right letter in the wrong place; both are solid tiles with no
/// edge of their own. Absent letters recede into the surface.
(Color fill, Color fg) markColors(ColorScheme c, Mark m) => switch (m) {
  Mark.correct => (c.secondary, c.onSecondary),
  Mark.present => (yellowOf(c), onColor(c, yellowOf(c))),
  Mark.absent => (c.surfaceContainerHighest, c.onSurface.withValues(alpha: .4)),
};

/// The edge of a feedback tile: the fill itself, so it shows no edge.
Color markBorder(ColorScheme c, Mark m) => markColors(c, m).$1;

double markBorderWidth(Mark m) => 1;

/// Colour for a luck score: green above average, red below, plain at zero.
Color luckColor(ColorScheme c, double v) {
  if (v.round() == 0) return c.onSurface;
  return v < 0 ? c.error : c.secondary;
}

/// The colour of a difficulty position, [t] from 0 (easiest) to 1 (hardest):
/// the scheme's green (secondary) turning to its purple (primary) through the
/// hues between, so it follows the theme.
Color difficultyColor(ColorScheme c, double t) => HSLColor.lerp(
  HSLColor.fromColor(c.secondary),
  HSLColor.fromColor(c.primary),
  t.clamp(0.0, 1.0),
)!.toColor();

/// Readable text on [bg]: the lighter or the darker of the scheme's two
/// surface colours, whichever contrasts more.
Color onColor(ColorScheme c, Color bg) {
  final light = c.surface.computeLuminance() > c.onSurface.computeLuminance()
      ? c.surface
      : c.onSurface;
  final dark = identical(light, c.surface) ? c.onSurface : c.surface;
  return bg.computeLuminance() > .35 ? dark : light;
}

/// A language's flag: an emoji, or `svg:<name>` for one drawn in assets/flags
/// (the Catalan senyera has no emoji).
class FlagBadge extends StatelessWidget {
  const FlagBadge(this.flag, {super.key, this.size = 20});
  final String flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (flag.isEmpty) return SizedBox(width: size * 1.4, height: size);
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: Center(
        child: flag.startsWith('svg:')
            ? SvgPicture.asset(
                'assets/flags/${flag.substring(4)}.svg',
                width: size * 1.3,
                height: size * 0.87,
              )
            : Text(flag, style: TextStyle(fontSize: size * .9, height: 1)),
      ),
    );
  }
}

/// A Tabler filled icon from assets/icons, tinted with [color].
class TablerIcon extends StatelessWidget {
  const TablerIcon(
    this.name, {
    super.key,
    required this.size,
    required this.color,
  });
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// One letter tile, coloured by [mark]; tappable when [onTap] is given.
class MarkTile extends StatelessWidget {
  const MarkTile(
    this.ch, {
    super.key,
    this.mark,
    required this.size,
    this.onTap,
  });
  final String ch;
  final Mark? mark;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Color? fill;
    Color fg = c.onSurface;
    var border = ch.isEmpty ? c.outlineVariant : c.onSurface;
    var borderWidth = 1.0;
    if (mark != null) {
      (fill, fg) = markColors(c, mark!);
      border = markBorder(c, mark!);
      borderWidth = markBorderWidth(mark!);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: borderWidth),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          ch,
          style: TextStyle(
            fontSize: size * .5,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Small tracked lowercase caption, the section label of the whole app.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.textAlign});
  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: textAlign,
    style: TextStyle(
      fontSize: 12,
      letterSpacing: 2,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
    ),
  );
}
