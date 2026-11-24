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
