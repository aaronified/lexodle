import 'retired_abbreviations.dart';

/// The first daily that never has a retired word as its answer. Earlier dailies
/// keep the draw they had, so one played before replays against the same word.
const dailyRetireFrom = '2026-11-25';

/// English words that are another word spelt as it is said, with its final g
/// dropped (comin for coming). They stay valid guesses, but from
/// [dailyRetireFrom] no daily (classic, lockdown, blind, quartet, relay) draws
/// one as its answer: a word that would be drawn is drawn again.
const retiredEnglish = <String>{
  'agin', 'bein', 'bitchin', 'bubblin', 'bussin', 'chillin', 'comin', //
  'copin', 'dancin', 'doin', 'filin', 'fittin', 'flamin', 'formin', //
  'freakin', 'frickin', 'friggin', 'gettin', 'gittin', 'goin', 'gradin', //
  'heckin', 'hummin', 'imagin', 'jonesin', 'knockin', 'layin', 'liftin', //
  'likin', 'livin', 'lockin', 'lookin', 'makin', 'maskin', 'messin', //
  'nestin', 'nothin', 'nuthin', 'nuttin', 'pantin', 'playin', 'postin', //
  'pullin', 'punchin', 'rattlin', 'reelin', 'rockin', 'savin', 'seein', //
  'sewin', 'storin', 'takin', 'talkin', 'tellin', 'trappin', 'trippin', //
  'tyin', 'usin', 'waggin', 'youngin', //
};

/// The first daily that never has a word of [retiredEnglishLater] as its answer.
const dailyRetireFromLater = '2026-11-27';

/// English "words" that are not words: abbreviations and acronyms (intnl, accts,
/// mtdna), a web address (https), a typo (rythm), the stretched sounds of chat
/// (whyyy, grrrr, mmhmm) and a word spelt as it is said (gonna, wanna, kinda).
/// They stay valid guesses, but from [dailyRetireFromLater] no daily draws one
/// as its answer.
const retiredEnglishLater = <String>{
  'intnl', 'apprx', 'instr', 'accts', 'appts', 'empts', 'bldgs', 'tbsps', //
  'cllrs', 'srsly', 'https', 'rythm', 'mtdna', 'ssdna', 'dsdna', 'cpdna', //
  'shrna', 'snrna', 'whyyy', 'grrrr', 'grrrl', 'pssst', 'pssht', 'mmhmm', //
  'hmmph', 'hnnng', 'skrrt', 'ooooh', 'yesss', 'waaay', 'buuut', 'maaan', //
  'yaaay', 'heeey', 'baaad', 'yeees', 'yaaas', 'aaagh', 'aieee', 'biiig', //
  'gonna', 'wanna', 'gotta', 'kinda', 'sorta', 'outta', 'tryna', 'finna', //
  'dunno', 'lemme', 'gimme', 'yknow', //
};

/// Whether [word] may not be the answer of the daily of [date] in the language
/// [code]: the g-dropped English words from [dailyRetireFrom]; from
/// [dailyRetireFromLater] the other English words above and, in every language,
/// the words the Wiktionary shows as nothing but an abbreviation.
bool retiredAnswer(String code, String word, String date) =>
    (code == 'en' &&
        date.compareTo(dailyRetireFrom) >= 0 &&
        retiredEnglish.contains(word)) ||
    (date.compareTo(dailyRetireFromLater) >= 0 &&
        ((code == 'en' && retiredEnglishLater.contains(word)) ||
            (retiredAbbreviations[code]?.contains(word) ?? false)));

/// Every word of the language [code] that is no word to guess: the g-dropped
/// English ones, the other English abbreviations and respellings and, in every
/// language, the ones the Wiktionary shows as nothing but an abbreviation. They
/// are taken out of the guesses and of free play from [dailyRetireFromLater].
Set<String> removedWords(String code) => {
  if (code == 'en') ...retiredEnglish,
  if (code == 'en') ...retiredEnglishLater,
  ...?retiredAbbreviations[code],
};
