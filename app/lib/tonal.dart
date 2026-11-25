import 'package:flutter/material.dart';

/// The tonal ramps of the app and the colour roles drawn from them.
///
/// Each family (the olive grey, pink, green, yellow, red, blue) is a ramp of
/// tones from 0 (black) to 100 (white), generated in OKLCH: the hue is fixed and
/// the chroma is capped, so a tone has the same lightness in every family. Every
/// surface, text and edge colour of the app is a tone of one of these ramps; the
/// grounds below pick which. This is the one place, with ui.dart and main.dart,
/// where colours are written as numbers.

const _neutral = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF010100),
  3: Color(0xFF020200),
  5: Color(0xFF040300),
  10: Color(0xFF0D0C04),
  15: Color(0xFF18170E),
  20: Color(0xFF242319),
  25: Color(0xFF302F25),
  30: Color(0xFF3C3B31),
  35: Color(0xFF48483D),
  40: Color(0xFF555449),
  45: Color(0xFF626156),
  50: Color(0xFF6F6E63),
  55: Color(0xFF7C7C70),
  60: Color(0xFF8A897D),
  65: Color(0xFF97978A),
  70: Color(0xFFA5A498),
  75: Color(0xFFB3B2A5),
  80: Color(0xFFC1C0B3),
  85: Color(0xFFCFCEC1),
  90: Color(0xFFDDDDCF),
  95: Color(0xFFEBEBDD),
  97: Color(0xFFF1F1E3),
  98: Color(0xFFF4F4E6),
  100: Color(0xFFFFFFFF),
};

const _pink = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF040004),
  3: Color(0xFF050005),
  5: Color(0xFF080108),
  10: Color(0xFF140613),
  15: Color(0xFF230D22),
  20: Color(0xFF331631),
  25: Color(0xFF441D41),
  30: Color(0xFF552552),
  35: Color(0xFF672D63),
  40: Color(0xFF783574),
  45: Color(0xFF8B3E86),
  50: Color(0xFF9D4797),
  55: Color(0xFFAF50A9),
  60: Color(0xFFC15ABA),
  65: Color(0xFFD265CB),
  70: Color(0xFFDD78D5),
  75: Color(0xFFE092D9),
  80: Color(0xFFE3A9DD),
  85: Color(0xFFE7BFE2),
  90: Color(0xFFECD3E9),
  95: Color(0xFFF3E5F2),
  97: Color(0xFFF7ECF5),
  98: Color(0xFFF8F0F7),
  100: Color(0xFFFFFFFF),
};

const _green = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF000200),
  3: Color(0xFF000200),
  5: Color(0xFF010401),
  10: Color(0xFF080E07),
  15: Color(0xFF121910),
  20: Color(0xFF1C261A),
  25: Color(0xFF263223),
  30: Color(0xFF30402D),
  35: Color(0xFF3B4D37),
  40: Color(0xFF455B41),
  45: Color(0xFF50684B),
  50: Color(0xFF5B7656),
  55: Color(0xFF678560),
  60: Color(0xFF73936C),
  65: Color(0xFF7FA177),
  70: Color(0xFF8BAF84),
  75: Color(0xFF99BE90),
  80: Color(0xFFA6CC9E),
  85: Color(0xFFB5DAAC),
  90: Color(0xFFC9E6C2),
  95: Color(0xFFE0EFDC),
  97: Color(0xFFE9F4E6),
  98: Color(0xFFEDF6EB),
  100: Color(0xFFFFFFFF),
};

const _yellow = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF050000),
  3: Color(0xFF070000),
  5: Color(0xFF0C0000),
  10: Color(0xFF110B00),
  15: Color(0xFF1D1602),
  20: Color(0xFF2B2204),
  25: Color(0xFF392D05),
  30: Color(0xFF473905),
  35: Color(0xFF564505),
  40: Color(0xFF665204),
  45: Color(0xFF755E03),
  50: Color(0xFF846B04),
  55: Color(0xFF947808),
  60: Color(0xFFA38510),
  65: Color(0xFFB3921B),
  70: Color(0xFFC2A028),
  75: Color(0xFFD1AE37),
  80: Color(0xFFDFBC48),
  85: Color(0xFFEDCB5C),
  90: Color(0xFFF4DA8A),
  95: Color(0xFFF9EABC),
  97: Color(0xFFFAF0CF),
  98: Color(0xFFFBF3D8),
  100: Color(0xFFFFFFFF),
};

const _red = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF070000),
  3: Color(0xFF080000),
  5: Color(0xFF0D0000),
  10: Color(0xFF1A0403),
  15: Color(0xFF2C0A08),
  20: Color(0xFF3F110D),
  25: Color(0xFF521713),
  30: Color(0xFF671E18),
  35: Color(0xFF7C231D),
  40: Color(0xFF922A23),
  45: Color(0xFFA73028),
  50: Color(0xFFBD372F),
  55: Color(0xFFD23F36),
  60: Color(0xFFE7483E),
  65: Color(0xFFE9685B),
  70: Color(0xFFE98276),
  75: Color(0xFFEA998E),
  80: Color(0xFFEBAEA5),
  85: Color(0xFFEDC2BB),
  90: Color(0xFFF0D5D0),
  95: Color(0xFFF6E6E3),
  97: Color(0xFFF8EDEB),
  98: Color(0xFFFAF0EF),
  100: Color(0xFFFFFFFF),
};

const _blue = <int, Color>{
  0: Color(0xFF000000),
  2: Color(0xFF000008),
  3: Color(0xFF00010A),
  5: Color(0xFF000210),
  10: Color(0xFF020A22),
  15: Color(0xFF041438),
  20: Color(0xFF0E2144),
  25: Color(0xFF162C58),
  30: Color(0xFF1C386D),
  35: Color(0xFF234483),
  40: Color(0xFF2A509A),
  45: Color(0xFF315CB0),
  50: Color(0xFF3869C7),
  55: Color(0xFF4B78CE),
  60: Color(0xFF5F87D2),
  65: Color(0xFF7396D6),
  70: Color(0xFF87A4DA),
  75: Color(0xFF9AB2DD),
  80: Color(0xFFAEC0E1),
  85: Color(0xFFC1CEE6),
  90: Color(0xFFD4DCEB),
  95: Color(0xFFE5EAF3),
  97: Color(0xFFECF0F7),
  98: Color(0xFFF0F3F8),
  100: Color(0xFFFFFFFF),
};

/// The tone [t] of a family, as a colour. The tones that exist are 0, 2, 3, 5,
/// every five up to 95, 97, 98 and 100.
abstract final class Tonal {
  static Color neutral(int t) => _neutral[t]!;
  static Color pink(int t) => _pink[t]!;
  static Color green(int t) => _green[t]!;
  static Color yellow(int t) => _yellow[t]!;
  static Color red(int t) => _red[t]!;
  static Color blue(int t) => _blue[t]!;
}

/// The three grounds the app can be drawn on: pure black (OLED), the olive dark
/// one, and the cream light one.
enum Ground { black, night, cream }

/// What a ground adds to the [ColorScheme]: the fills one step above the page
/// (grouped surfaces and fields [s1], tiles inside them [s2], tracks and
/// switches [s3]) and the edge for what is outlined, [line].
@immutable
class AppTones extends ThemeExtension<AppTones> {
  const AppTones({
    required this.s1,
    required this.s2,
    required this.s3,
    required this.line,
    required this.faint,
  });

  final Color s1, s2, s3, line, faint;

  /// The tones of [g].
  factory AppTones.of(Ground g) => switch (g) {
    Ground.black => AppTones(
      s1: Tonal.neutral(15),
      s2: Tonal.neutral(20),
      s3: Tonal.neutral(25),
      line: Tonal.neutral(35),
      faint: Tonal.neutral(50),
    ),
    Ground.night => AppTones(
      s1: Tonal.neutral(20),
      s2: Tonal.neutral(25),
      s3: Tonal.neutral(30),
      line: Tonal.neutral(40),
      faint: Tonal.neutral(55),
    ),
    Ground.cream => AppTones(
      s1: Tonal.neutral(95),
      s2: Tonal.neutral(90),
      s3: Tonal.neutral(85),
      line: Tonal.neutral(80),
      faint: Tonal.neutral(60),
    ),
  };

  @override
  AppTones copyWith({
    Color? s1,
    Color? s2,
    Color? s3,
    Color? line,
    Color? faint,
  }) => AppTones(
    s1: s1 ?? this.s1,
    s2: s2 ?? this.s2,
    s3: s3 ?? this.s3,
    line: line ?? this.line,
    faint: faint ?? this.faint,
  );

  @override
  AppTones lerp(AppTones? other, double t) => other == null
      ? this
      : AppTones(
          s1: Color.lerp(s1, other.s1, t)!,
          s2: Color.lerp(s2, other.s2, t)!,
          s3: Color.lerp(s3, other.s3, t)!,
          line: Color.lerp(line, other.line, t)!,
          faint: Color.lerp(faint, other.faint, t)!,
        );
}

/// The tones of the theme in force.
AppTones tonesOf(BuildContext context) =>
    Theme.of(context).extension<AppTones>() ?? AppTones.of(Ground.night);

/// The [ColorScheme] of [g]: the page, the text, and the roles each family plays:
/// pink acts (primary), green selects (secondary container) and is the right
/// place, red is a mistake, yellow the right letter in the wrong place.
ColorScheme schemeOf(Ground g) {
  final dark = g != Ground.cream;
  final t = AppTones.of(g);
  final bg = switch (g) {
    Ground.black => Tonal.neutral(0),
    Ground.night => Tonal.neutral(15),
    Ground.cream => Tonal.neutral(98),
  };
  final text = dark ? Tonal.neutral(95) : Tonal.neutral(10);
  final dim = dark ? Tonal.neutral(70) : Tonal.neutral(40);
  return ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? Tonal.pink(80) : Tonal.pink(40),
    onPrimary: dark ? Tonal.pink(20) : Tonal.pink(95),
    primaryContainer: dark ? Tonal.pink(30) : Tonal.pink(90),
    onPrimaryContainer: dark ? Tonal.pink(90) : Tonal.pink(20),
    secondary: dark ? Tonal.green(80) : Tonal.green(40),
    onSecondary: dark ? Tonal.green(20) : Tonal.neutral(98),
    secondaryContainer: dark ? Tonal.green(30) : Tonal.green(85),
    onSecondaryContainer: dark ? Tonal.green(85) : Tonal.green(20),
    tertiary: dark ? Tonal.yellow(85) : Tonal.yellow(70),
    onTertiary: Tonal.neutral(10),
    tertiaryContainer: dark ? Tonal.yellow(30) : Tonal.yellow(90),
    onTertiaryContainer: dark ? Tonal.yellow(90) : Tonal.yellow(30),
    error: dark ? Tonal.red(70) : Tonal.red(40),
    onError: dark ? Tonal.red(20) : Tonal.neutral(98),
    errorContainer: dark ? Tonal.red(40) : Tonal.red(85),
    onErrorContainer: dark ? Tonal.red(90) : Tonal.red(20),
    surface: bg,
    onSurface: text,
    onSurfaceVariant: dim,
    surfaceDim: bg,
    surfaceBright: t.s2,
    surfaceContainerLowest: bg,
    surfaceContainerLow: bg,
    surfaceContainer: bg,
    surfaceContainerHigh: t.s2,
    surfaceContainerHighest: t.s1,
    outline: t.line,
    outlineVariant: t.s2,
    shadow: Tonal.neutral(0),
    scrim: Tonal.neutral(0),
    inverseSurface: text,
    onInverseSurface: bg,
    inversePrimary: dark ? Tonal.pink(40) : Tonal.pink(80),
    surfaceTint: Colors.transparent,
  );
}
