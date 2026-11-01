# Changelog

Each point is a summary line (shown in the app after an update, lowercase, under
80 characters), then indented details (shown here only). The release workflow
takes the `Unreleased` section for the release notes and the app, then renames
it to the version.

## Unreleased

- learn: tap a guess to see why it scored as it did
  It shows how the guess and the best guess split the words that fitted: the
  groups, the biggest group, the words left and the bits.
- learn: fourteen achievements for learning
  Practice, flawless words, unaided words, rounds of choose the best and of
  closing, three words, a learning streak and a full lesson. They count once for
  you, not per language.
- learn: a home with five entries and your progress
  The opening, practise a word, choose the best, closing and three words, each
  with a trend of its skill in the language and length, and the days in a row.
- learn: three words, to find a set that tells the most
  Type three words to play first, whatever the answer. It scores what they tell
  together and the chance to win by the fourth and fifth guess, against the best
  set the app could find. They need not start with the best opener.
- learn: closing, ten endgames
  Few words fit and two or three tries are left: pick the guess most likely to
  win in time, from the exact chances. Often it is not a word that fits.
- learn: the opening, a lesson
  The best first guess for your language and length, and for each of the colours
  it is most likely to show the best second guess. Compare the next best openers.
- learn: choose the best, with the groups behind each pick
  Each position shows the clues so far and four words; pick the one that splits
  the words that fit best. The groups of every option can be shown, with their
  chances, bits and what each adds to the words left.
- learn: a hint button and undo
  The hint gives the best guess in three steps (the letter, the word, why).
  Undo takes the last guess back with the words that fitted before it.

- the draggable bar is on every end panel
  The quartet and the relay race have it too, not only a single word.

- places: the obscure tail is never the answer
  Every place past the best known thousand or so still had one chance in the
  draw, which added up (mehetia, an island). They are still valid guesses, but
  can no longer be drawn.

- relay and quartet: one guess for each of the last 3 words
  Two achievements, baton pass (relay race) and domino (quartet): win with one
  guess for each of the last three words, 1/5/15/40 times. The skilled cousin of
  luckiest man alive, which is luck. In a relay race a free ride counts.

- the end panel can be dragged
  A bar on top of the analysis under a finished game drags it down to show more
  of the guesses, or up (or with a double tap) to read about the word.

- lockdown: the game's locks are green, yours are pink
  A letter the game locked (a green in lockdown) has a green border and lock;
  one you locked keeps the accent colour.

## 0.4.6

- dailies change at midnight India time for everyone
  The date of a daily is the date in IST (UTC+5:30), the same instant all over
  the world.
- the words of the dailies cannot be read off the source
  The daily draw is salted with a secret put in at build time.

- blind has a daily
  One word, five letters, 10 tries, the same for everyone, with a streak, a
  calendar and a streak achievement of its own (blind kindling to blind phoenix).
- the daily quartet and relay race may share a letter
  From 2026-11-01 a daily word may share a letter with an earlier one with a
  10% chance, as in any other game (a word with a letter twice counts as
  sharing). Before, they shared none, which favoured words with a letter twice.

- relay race: locks do not carry to the next target
  When a target is solved, the next word starts with nothing locked.
- abbreviations are out of the word lists
  Acronyms and abbreviations that an en.wiktionary entry let in (http, nato,
  covid, lgbt, afaik and others, 36 in English, one each in Spanish, French and
  Swedish) are removed; tools/abbreviations.py keeps them out of a rebuild. It
  moves the daily picks after them.

- quartet and relay: the screen stays smooth while they are analysed
  The analysis of each guess of a quartet or relay race now runs on other
  threads, as a classic game's does. It ran on the screen's own, which made the
  second guess hard to type.
- quartet and relay: doubled letters are not favoured
  Words kept from sharing letters tend to be words with a letter twice, so a
  daily could be four of them. From 2026-11-01 at most two of a daily's four
  words have a letter twice; in other games a word with a letter twice counts as
  sharing a letter.

- blind: a doubled letter can be green in two places
  A letter may be green in several positions. The limits are: a position is
  green with one letter, no more letters than the length are green or yellow,
  and a letter is never yellow in every position.
- bafta is not a word
  Removed from the English list (it moves the daily picks after it).

- blind games do not count greens whose places are unknown
  The game phase and the playstyle of a blind guess no longer treat the
  places of earlier greens as known.

- blind review shows the real colours and both counts
  The tiles of a blind game's review are the colours the guesses really had,
  with the two count squares beside each row.
- quartet keys have a soft shadow
  A key every board has greyed no longer blends into the page.

- blind: colour logic keeps your pencil possible, and can be turned off
  Green and yellow belong to a letter in a position. A letter is green in one
  position (a new green sends the old back to yellow), a position is green with
  one letter, a letter yellow everywhere else it can be can only be green, a
  green or yellow letter cannot be grey, and a row cannot show more than its
  counts; a toast says why a colour was passed over. The game modes screen has a
  colour logic switch for blind: off marks nothing for you and lets you pencil
  anything on any tile.

## 0.4.5

- blind: a colour you pencil on a letter shows everywhere
  It marks that letter on every tile and on the keyboard, with the colours the
  counts already settle.

## 0.4.4

- blind marks the obvious on the keyboard and the grid
  A guess with 0 right and 0 elsewhere greys all its letters; one whose counts
  add up to the word length turns its letters yellow and greys every other
  letter. Deduced greys are fixed; deduced yellows can only be tapped between
  yellow and green.

## 0.4.3

- lockdown skill counts only the guesses you were allowed
  Skill in lockdown is measured against the best word that keeps the locked
  greens in place, not the best word in the whole list, in play, in the review
  and when history is re-scored.
- places: only the best known 1,000 are likely answers
  The geography draw curve is about even for the 600 most read places and
  falls to almost nothing past the 1,000th (it was 1,200 and 2,000). Every
  place is still a valid guess.
- the first guess is analysed faster after the first time
  The opening analysis of a position is kept in the app's cache (4 bytes per
  word, at most 10 MB, oldest deleted first) and reused on later starts. The
  luckiest guesses of that first guess are worked out when you open its review.
- what's new is shown after an update
  The first start of a new version lists its changes once.
