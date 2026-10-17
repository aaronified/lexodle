import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licences of what the app bundles beyond Dart packages (those are
/// listed by Flutter itself) to the page behind "about" > "view licences":
/// the font, the icons, the word lists and the dictionaries that filtered them.
void registerLicences() {
  LicenseRegistry.addLicense(() async* {
    Future<String> text(String asset) => rootBundle.loadString(asset);
    yield LicenseEntryWithLineBreaks([
      'JetBrains Mono (font)',
    ], await text('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Tabler Icons',
    ], await text('assets/icons/LICENSE-tabler.txt'));
    yield LicenseEntryWithLineBreaks([
      'Word lists (adapted from wordfreq, CC BY-SA 4.0)',
    ], await text('assets/words/LICENSE.md'));
    yield LicenseEntryWithLineBreaks([
      'Spelling dictionaries used to filter the word lists',
    ], await text('assets/words/SOURCES.md'));
  });
}
