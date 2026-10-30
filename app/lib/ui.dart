import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'logic.dart';
import 'medal.dart';
import 'words.dart';

export 'medal.dart' show Medal;

/// The sizes of the one-line choosers (the steppers and the mode button): the
/// label, the line under it, and the icons, so they read alike wherever they are.
const chooserLabelSize = 16.0;
const chooserSubSize = 11.0;
const chooserIconSize = 24.0;

/// The mode icon in the title of a game screen.
const headerIconSize = 20.0;

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

/// The one colour of each measure, wherever it shows: skill is blue, luck
/// yellow, risk green, bits violet. A number keeps its colour whatever its sign or size;
/// for luck the +/- sign carries the direction. The shades are brighter on the
/// dark and black pages and deeper on the light one, so they read on all three.
Color skillColor(ColorScheme c) => c.brightness == Brightness.dark
    ? const Color(0xFF4C8DFF)
    : const Color(0xFF1F5FD0);

Color luckColor(ColorScheme c) => c.brightness == Brightness.dark
    ? const Color(0xFFF2C230)
    : const Color(0xFF9A7400);

Color riskColor(ColorScheme c) => c.brightness == Brightness.dark
    ? const Color(0xFF5CB85C)
    : const Color(0xFF2E7D32);

/// The red of a heart, brighter on the dark and black pages, deeper on the light.
Color heartColor(ColorScheme c) => c.brightness == Brightness.dark
    ? const Color(0xFFFF7A66)
    : const Color(0xFFC0392B);

Color bitsColor(ColorScheme c) => c.brightness == Brightness.dark
    ? const Color(0xFFA98BFF)
    : const Color(0xFF7A4FD0);

/// The colour of the measure [which] ('skill', 'luck', 'risk', 'bits').
Color metricColor(ColorScheme c, String which) => switch (which) {
  'skill' => skillColor(c),
  'luck' => luckColor(c),
  'bits' => bitsColor(c),
  _ => riskColor(c),
};

/// The colour of a playstyle behaviour: a gambler is risk's green, a maximiser
/// skill's blue, an eliminator bits' violet, a closer luck's yellow, a prober the
/// accent. A style takes the colour of its early habit.
Color behaviourColor(ColorScheme c, String label) => switch (label) {
  'gambler' => riskColor(c),
  'maximiser' => skillColor(c),
  'eliminator' => bitsColor(c),
  'closer' => luckColor(c),
  _ => c.primary,
};

/// [text] with the words skill, luck and risk (and only those) in their own
/// colours, wherever they stand in it. Returns spans to put in a [Text.rich].
List<InlineSpan> measureSpans(ColorScheme c, String text) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in RegExp(
    r'\b(skill|luck|risk)\b',
    caseSensitive: false,
  ).allMatches(text)) {
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    spans.add(
      TextSpan(
        text: m[0],
        style: TextStyle(color: metricColor(c, m[0]!.toLowerCase())),
      ),
    );
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return spans;
}

/// A text whose words skill, luck and risk are in their own colours.
Widget measureText(
  BuildContext context,
  String text, {
  TextStyle? style,
  Key? key,
  TextAlign? textAlign,
}) => Text.rich(
  TextSpan(children: measureSpans(Theme.of(context).colorScheme, text)),
  key: key,
  style: style,
  textAlign: textAlign,
);

Color medalColor(ColorScheme c, Medal m) {
  final dark = c.brightness == Brightness.dark;
  return switch (m) {
    Medal.bronze => dark ? const Color(0xFFD28A4D) : const Color(0xFFA45F1D),
    Medal.silver => dark ? const Color(0xFFC4C8CF) : const Color(0xFF6F7782),
    Medal.gold => dark ? const Color(0xFFF0C219) : const Color(0xFFA57C00),
    Medal.platinum => dark ? const Color(0xFF7FDCD8) : const Color(0xFF2F8A99),
  };
}

/// A line that starts with a measure's term and number ('skill 82', 'luck +20',
/// 'risk 30'): the words up to the first colon or dot in the measure's colour,
/// the rest plain. Returns plain text when [text] does not start with [lead].
Widget metricLine(
  BuildContext context,
  String text,
  String which, {
  TextStyle? style,
  Key? key,
  TextAlign? textAlign,
}) {
  final c = Theme.of(context).colorScheme;
  final base = style ?? DefaultTextStyle.of(context).style;
  final stops = [
    for (final m in [text.indexOf(':'), text.indexOf(' ·')])
      if (m >= 0) m,
  ];
  final end = stops.isEmpty
      ? text.length
      : stops.reduce((x, y) => x < y ? x : y);
  if (!text.startsWith(which)) {
    return Text(text, key: key, style: style, textAlign: textAlign);
  }
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: text.substring(0, end),
          style: TextStyle(color: metricColor(c, which)),
        ),
        TextSpan(text: text.substring(end)),
      ],
    ),
    key: key,
    style: base,
    textAlign: textAlign,
  );
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
    this.locked = false,
  });
  final String ch;
  final Mark? mark;
  final double size;
  final VoidCallback? onTap;

  /// Whether the letter is locked: a thin accent border and a lock in the corner.
  final bool locked;

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
    if (locked && mark == null) border = c.primary;
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
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                isBlank ? '_' : ch,
                style: TextStyle(
                  fontSize: size * .5,
                  fontWeight: FontWeight.bold,
                  color: isBlank ? fg.withValues(alpha: dimAlpha) : fg,
                ),
              ),
              if (locked)
                Positioned(
                  top: 3,
                  right: 3,
                  child: TablerIcon(
                    'lock',
                    key: const ValueKey('locked'),
                    size: size * .22,
                    color: c.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tracked lowercase caption, the section label of the whole app.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.textAlign}) : span = null;

  /// A caption with parts of it in colour (see [metricParts]).
  const Caption.rich(TextSpan this.span, {super.key, this.textAlign})
    : text = '';
  final String text;
  final TextSpan? span;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      letterSpacing: 2,
      color: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: dimAlpha),
    );
    return span == null
        ? Text(text, textAlign: textAlign, style: style)
        : Text.rich(span!, textAlign: textAlign, style: style);
  }
}

/// [text] as a span in the colour of the measure [which].
TextSpan metricSpan(ColorScheme c, String text, String which) => TextSpan(
  text: text,
  style: TextStyle(color: metricColor(c, which)),
);

/// A line made of [parts]: each is its text and the measure it stands for
/// ('skill', 'luck', 'daring'), or null for plain text.
TextSpan metricParts(ColorScheme c, List<(String, String?)> parts) => TextSpan(
  children: [
    for (final (t, which) in parts)
      which == null ? TextSpan(text: t) : metricSpan(c, t, which),
  ],
);

/// A hairline dialog in the app's look: the page's own background, a close
/// cross at the top right and a title. [children] scroll.
Future<T?> showHairlineDialog<T>(
  BuildContext context, {
  required String title,
  Color? titleColor,
  Widget? leading,
  required List<Widget> children,
}) => showDialog<T>(
  context: context,
  builder: (context) {
    final c = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
              child: Row(
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 10)],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('dialog-close'),
                    tooltip: 'close',
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 4, 19, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// A small round "i" that opens [text] in a dialog: the long explanations live
/// behind it, beside the heading they belong to. The words skill, luck and risk
/// in the text are in their own colours.
class InfoDot extends StatelessWidget {
  const InfoDot(this.text, {super.key, this.title = ''});
  final String text;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return Semantics(
      button: true,
      label: 'explain',
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => showHairlineDialog<void>(
          context,
          title: title,
          children: [
            Text.rich(
              TextSpan(children: measureSpans(c, text)),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        radius: 16,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: dim, width: 1.5),
          ),
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: dim,
            ),
          ),
        ),
      ),
    );
  }
}
