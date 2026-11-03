# Changelog

Each point is a summary line (shown in the app after an update, lowercase, under
80 characters), then indented details (shown here only). The release workflow
takes the `Unreleased` section for the release notes and the app, then renames
it to the version.

## Unreleased

- learn has a strategy guide for the mode you have selected
  Every mode has one: how to play it well. The word drills stay for the modes
  that play single words with the usual colours (classic, quartet, relay,
  lockdown, mastermind); equations, blind and themed show the guide alone.
  The learn button in game modes now works in every mode.

- every game has a help button with the rules of its mode
  At the top right, daily games too: the rules and colours of the mode, then
  typing, spaces (blanks), locks and what a daily is.

- equations: the keys are a number pad
  Digits in three rows of three with 0 under them, the signs beside them, then
  enter and backspace.

## 0.7.0

- new mode: mastermind, no daily
  The word is not chosen: every guess is answered as a word still possible
  would answer it, and you win by guessing the word that is left. Random draws
  one of the words left, so the reply that keeps the most is the likeliest;
  largest always keeps the most, with no chance in it. There is no limit on
  guesses. It has achievements for wins and for short games in both.

- new mode: equations, with a daily
  Guess a true equation of 6, 7 or 8 tiles: digits and + − × ÷ =, one = with a
  sum on the left and a whole number on the right, no leading zeros and no lone
  0. The colours work as in classic. The daily is 8 tiles, 6 tries, the same in
  every language. It has no skill, luck or review; it has achievements of its
  own (wins, quick wins, last try, brutal, speed and a daily streak).

- the modes swipe: blind after lockdown, themed last
  The order is classic, quartet, relay, lockdown, blind, equations and themed
  (English only). Saved games and settings are not affected.

- blind: double tap on the counts locks the pencilled greens
  The guesses of a blind game cycle their colour on a tap, so they cannot lock;
  the counts do instead, as the board does in the other modes.

## 0.6.0

- the end panel scrolls and moves with it
  Scroll the text up and the panel rises, to three quarters of the screen, then
  the text scrolls; scroll down and the text returns to the top, then the panel
  drops. The handle and the result row stay in place and drag the panel. The
  boards no longer move: the panel slides over them.

- double tap on a board's guesses clears the typed row
  Locking the greens keeps only the locked letters; the other letters typed in
  the row are cleared. In a relay race only the board in play can lock.

- english: contractions without the apostrophe are no longer words
  Hasnt, didnt, thats and 28 more (31 in all) are removed from the word list.
  The daily words change with the list, so this ships right before midnight.

## 0.5.1

- blind: control cycles the colour under the cursor
  Like shift locks: a tap of the control key gives the letter under the cursor
  its next colour, as tapping it in the guesses does.

- themed: the best 500 places are likely, the rest have a small chance
  The curve falls away sooner (half at the 550th place, little past the 650th),
  and every other place keeps a small chance, a few in a hundred in all. The
  game options still give the frequency or the equal chance.
- faster, sharper and luckier wins in every mode
  New achievements for the fewest guesses, the best average skill and the best
  average luck in lockdown, blind and the relay race, and the luck of a quartet.
  On the first start after this update they are worked out once from the games
  kept; from then on they are earned as games are played.

- the achievements are listed by section
  General, milestones, then quartet, relay race, lockdown and blind, then the
  streaks, each under a heading.
- the end panel rises from the bottom
  It slides up in 0.3 seconds with a square top border and a shadow on the
  guesses, and the gap between the handle and the guesses is as thin as can be.
- every game left unfinished resumes, with its locks and colours
  Leaving a game and coming back puts it as it was: the word (or words), the
  guesses, hearts, the half-typed row with its locks and cursor, and a blind
  game's colours. This was only so for the daily. A finished game is not kept.
  A practice or a puzzle from a link is still not kept.
- double tap the guesses to lock every green
  A double tap on the submitted guesses locks all the greens found so far, in
  place of the locks you had set, and a toast says so. In a quartet it follows
  the board you tapped. The locks are yours: the same colour, and unlocked as
  usual. Not in a blind game, which has no greens to read.
- quartet: locks clear when a word is solved; the cursor has its own colour
  Locks stay between guesses until a board is solved, as in a relay race. The
  cursor border is the ink colour, so it no longer looks like a (pink) lock.

## 0.5.0

- learn: tap a guess to see why it scored as it did
  It shows how the guess and the best guess split the words that fitted: the
  groups, the biggest group, the words left and the bits.
- learn: the styles, taught
  The three habits of the opening (gambler, maximiser, eliminator) and the two
  of the end (closer, prober) with their rules, when each is right, and a real
  example of each. Luck is explained, with an example that averages nothing.
- learn: every graded guess says which habit it counts as
  Practice, choose the best and closing name the habit and the numbers behind
  it, the habit of the best guess, and the luck, which is the answer's doing.
- learn: fourteen achievements for learning
  Practice, flawless words, unaided words, rounds of choose the best and of
  closing, three words, a learning streak and a full lesson. They count once for
  you, not per language.
- learn: a home with six entries and your progress
  The opening, the styles, practise a word, choose the best, closing and three words, each
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
