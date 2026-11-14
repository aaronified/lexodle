import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licences of what the app bundles beyond Dart packages (those are
/// listed by Flutter itself) to the page behind "about" > "view licences":
/// the font, the icons, the word lists, the Wiktionary entries and the dictionaries
/// that filtered the lists.
void registerLicences() {
  LicenseRegistry.addLicense(() async* {
    Future<String> text(String asset) => rootBundle.loadString(asset);
    yield LicenseEntryWithLineBreaks([
      'JetBrains Mono (font)',
    ], await text('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Tabler Icons',
    ], await text('assets/icons/LICENSE-tabler.txt'));
    yield LicenseEntryWithLineBreaks(
      ['Flags (Twemoji graphics, CC BY 4.0)'],
      '${await text('assets/flags/NOTICE.txt')}\n'
      '${await text('assets/flags/LICENSE-twemoji-graphics.txt')}',
    );
    yield LicenseEntryWithLineBreaks([
      'Word lists (adapted from wordfreq, CC BY-SA 4.0)',
    ], await text('assets/words/LICENSE.md'));
    yield LicenseEntryWithLineBreaks([
      'Place names (GeoNames, CC BY 4.0)',
    ], await text('assets/geography/NOTICE.md'));
    yield LicenseEntryWithLineBreaks(
      ['Natural Earth land (public domain) via world-atlas (ISC)'],
      'The outline of the land on the map of a place is Natural Earth '
      '(naturalearthdata.com), which is in the public domain, as packaged '
      'by the world-atlas npm package (ISC licence).',
    );
    yield LicenseEntryWithLineBreaks([
      'Wiktionary entries (CC BY-SA 4.0)',
    ], await text('assets/wiktionary/NOTICE.md'));
    yield LicenseEntryWithLineBreaks([
      'Spelling dictionaries used to filter the word lists',
    ], await text('assets/words/SOURCES.md'));
  });
}
