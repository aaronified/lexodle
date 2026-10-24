import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

Future<ByteData> _bytes(String path) async =>
    ByteData.view((await File(path).readAsBytes()).buffer);

/// Gives a test the app's real fonts, all from files in the repository: a test
/// draws every glyph as a box (and measures text in boxes) unless it is given
/// the fonts the app draws with.
///
/// * JetBrains Mono, regular and bold: the app's one font (`assets/fonts`), which
///   the check in `tools/check_glyphs.py` shows covers every character the app
///   can draw, so no fallback font is ever needed;
/// * Material Icons, cut down to the few icons the app uses
///   (`test/fonts/MaterialIcons-Regular.otf`, Apache 2.0).
///
/// Flags and icons are SVG assets, which a test reads from the assets itself.
/// Nothing is read from the Flutter SDK, the system or the network, and calling
/// it again does nothing.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  _loaded = true;
  await (FontLoader('JetBrainsMono')
        ..addFont(_bytes('assets/fonts/JetBrainsMono-Regular.ttf'))
        ..addFont(_bytes('assets/fonts/JetBrainsMono-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(_bytes('test/fonts/MaterialIcons-Regular.otf'))).load();
}
