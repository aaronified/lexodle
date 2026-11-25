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

/// Whether [word] may not be the answer of the English daily of [date].
bool retiredAnswer(String word, String date) =>
    (date.compareTo(dailyRetireFrom) >= 0 && retiredEnglish.contains(word)) ||
    (date.compareTo(dailyRetireFromLater) >= 0 &&
        retiredEnglishLater.contains(word));
