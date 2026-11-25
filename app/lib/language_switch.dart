import 'app_log.dart';
import 'main.dart';
import 'words.dart';

/// Makes [code] the language in use. The length is kept when the language has
/// words of that length, and otherwise its first one is used. A failure is
/// logged and nothing changes.
Future<void> switchLanguage(String code) async {
  try {
    if (code == appState.lang) return;
    final langs = await WordBank.languages();
    final next = langs.where((l) => l.code == code);
    if (next.isEmpty) return;
    final to = next.first;
    final length = appState.length;
    appState.setup(
      lang: code,
      length: to.lengths.contains(length) ? length : to.lengths.first,
    );
  } catch (e) {
    appLog.w('language', 'switch failed ${e.runtimeType}');
  }
}

/// The stops of a language slider: the languages the player ticked, then any
/// other in [also] (the ones a page has data for), without repeats.
List<String> languageStops([Iterable<String> also = const []]) => [
  ...appState.playLangs,
  for (final c in also)
    if (!appState.playLangs.contains(c)) c,
];
