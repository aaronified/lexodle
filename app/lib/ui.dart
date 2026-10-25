import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'logic.dart';
import 'words.dart';

/// How strongly secondary text (captions, notes) shows against the page: dim,
/// but still readable (4.5:1) in both themes.
const dimAlpha = .66;

/// The wrong-place yellow. The scheme's tertiary is too close to its green in
/// a muted Material You palette, so the yellow is its own warm hue, kept at a
/// lightness that reads in both themes: a bright yellow on the dark page, and
/// a deeper amber on the light one, where a pale yellow would vanish.
Color yellowOf(ColorScheme c) => HSLColor.fromAHSL(
  1,
  47,
  .88,
  c.brightness == Brightness.dark ? .52 : .42,
).toColor();

/// Feedback colours. Green (secondary) is the right letter in the right place,
/// yellow the right letter in the wrong place; both are solid tiles with no
/// edge of their own. Absent letters recede into the surface.
(Color fill, Color fg) markColors(ColorScheme c, Mark m) => switch (m) {
  Mark.correct => (c.secondary, c.onSecondary),
  Mark.present => (yellowOf(c), onColor(c, yellowOf(c))),
  Mark.absent => (
    Color.alphaBlend(c.onSurface.withValues(alpha: .14), c.surface),
    c.onSurface.withValues(alpha: .55),
  ),
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
            ? _svgFlags(flag.substring(4))
            : Text(flag, style: TextStyle(fontSize: size * .9, height: 1)),
      ),
    );
  }

  /// One flag, or two (`gb+us`) side by side, each cropped to its half, for a
  /// language that merges two variants.
  Widget _svgFlags(String names) {
    Widget one(String name, Alignment half, {bool crop = false}) {
      final flag = SvgPicture.asset(
        'assets/flags/$name.svg',
        width: size * 1.3,
        height: size * 0.87,
      );
      return crop
          ? ClipRect(
              child: Align(alignment: half, widthFactor: .5, child: flag),
            )
          : flag;
    }

    final parts = names.split('+');
    if (parts.length != 2) return one(names, Alignment.center);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        one(parts[0], Alignment.centerLeft, crop: true),
        one(parts[1], Alignment.centerRight, crop: true),
      ],
    );
  }
}

/// The badge (the flag) of the language with this [code], or nothing while the
/// languages are not read yet or there is no such language.
Widget languageBadge(String code, {double size = 14}) {
  for (final l in WordBank.loadedLanguages ?? const <Language>[]) {
    if (l.code == code) return FlagBadge(l.flag, size: size);
  }
  return const SizedBox.shrink();
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
    this.cursor = false,
  });
  final String ch;
  final Mark? mark;
  final double size;
  final VoidCallback? onTap;

  /// Whether this is the slot the next typed letter goes into.
  final bool cursor;

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
    if (cursor) {
      border = c.primary;
      borderWidth = 2;
    }
    // a blank is a space typed as a pencil mark, shown as a dim underscore
    final isBlank = ch == ' ';
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
          isBlank ? '_' : ch,
          style: TextStyle(
            fontSize: size * .5,
            fontWeight: FontWeight.bold,
            color: isBlank ? fg.withValues(alpha: dimAlpha) : fg,
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
      color: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: dimAlpha),
    ),
  );
}
