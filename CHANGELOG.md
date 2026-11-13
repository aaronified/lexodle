# Changelog

Each point is a summary line (shown in the app after an update, lowercase, under
80 characters), then indented details (shown here only). The release workflow
takes the `Unreleased` section for the release notes and the app, then renames
it to the version.

## Unreleased

- every game has a timer, and the time is in history
  A pill left of the keyboard counts your play time from the first key you press until the game ends. It pauses when the app is in the background and keeps its time when a saved game resumes. History shows the time next to the result. Games from before have no time.

- settings: one button on every page, and everything in it
  A settings button sits top right on the tabs and the secondary pages. Theme (first), reminders, backup, support, what's new, sound, haptics, updates, the log and about all live there, each opening at its step. The you tab no longer carries them.
- learn opens after the first game, with how to play
  Until game 24 learn shows only a how to play for each open mode, and a mode is added as it opens. The how to play button and row are gone from you.
- today: the mode icon is in the square, and free play has no dots
  Each daily's icon now sits in its square: green when solved, yellow in progress, a red icon when missed (the skull is only in the streak calendar). The free play button no longer shows pending-daily dots.

## 0.10.2

- one ladder: every row, tab and card opens at its step
  What a player sees now opens by the games played, from one list. A mode taught early in the first run opens at once, and what is scheduled up to its step opens with it. An intro card waits until it is handled, one at a time, and no mode is named before its step. The new look is the only look: its switch is gone.
- game over: skill, luck and risk in two steps
  From the second game the panel shows the three numbers with a line each. The full maths and the detailed analysis come once every mode is open. The medals list comes with achievements and the save-word bookmark with my words.
- diy has a mode row, and the solver follows the mode
  Make a puzzle in any open mode without switching today first. The solver row says which mode it solves.
- mode settings open for every open mode, and what's new has a row
  A mode's free play settings no longer wait for three plays of it. You has a "what's new" row.
- today: pending dailies show on the mode button for every open mode

- settings: only what has no other home
  The settings page no longer repeats the theme, backup and support, which are rows on you. It keeps vibrate, sound, the new look switch, updates, faster openings, the log, and about and licences.

- equations keep their own tries
  Choosing an equations difficulty (brutal is 3 tries) also changed the tries of classic, quartet and relay. Equations now have a setting of their own. If classic free play was stuck on fewer tries, set it again in mode settings.

- you: language, how to play, solver, diy and settings are back
  The new look had dropped them. You has a row for each: language, how to play and settings always, solver and diy from game 6. A failed screen falls back to the right home, and what's new shows once after an update.
- you: backup and support open only their own section
  They no longer open the whole settings page. The achievements row shows the lex pill.
- learn, history and playstyle: mode pills in one scrolling row
  The row scrolls sideways with its edges faded only where there is more. Learn gets its own mode pills.
- today: a finished daily opens its game over screen
  Tapping a solved or missed daily on today showed a placeholder message instead of the game. It opens the finished game, with its game over and review screens, again.

- lex chip: readable in dark and black
  The gem and number sit on a deeper green with a lighter yellow, so they no longer wash out. Light is unchanged.

## 0.10.1

- today: one button for free play and the mode
  The bottom of today is one plain button, free play and the mode name. With one mode open a tap starts it. With more, swipe or use the arrows to change the mode, tap to play it. The daily is started from its row.

- free play plays the mode in view
  Free play on today no longer opens the mode menu: it starts a free game of the mode you are on. The mode menus come later, from the you tab. The every mode card now just dismisses.

- today: free play stays on one line
  The free play button no longer wraps onto two lines on a narrow phone.

- your first daily says how a daily differs
  The first time a daily opens, a short sheet says: one word a day, the same for everyone, new at midnight in india, the number of tries, it is logged for your streak and history, and free play is for practice. It shows once.
- today shows one card at a time, and it opens the feature
  The next-up card is gone. A card for what just opened (a mode, achievements, history, my words, learn) is tappable and takes you into it; once handled, it does not come back.

- a quiet border where a page needs one
  Cards on the page, outlined buttons, text fields, dialogs and sheets have a thin, faint border again (0.75 px, about 1.5 to 2:1 against the page); a focused field has a clear line. Shades still separate everything inside a card.

- the new look is the app
  Today and you are the first two tabs; words joins at game 9 and learn at game 24 (a veteran has all four). The first launch asks for a language and a theme, then plays your first game. Anyone who turned the new look off keeps it off; the switch is in the settings.

- words: every language looks a word up in its own wiktionary
  Meanings, pronunciation, origin and synonyms of the answer and of saved words come from the Wiktionary of the word's language: French, Spanish, Italian, Portuguese, Catalan, Romanian, German, Dutch, Swedish, Danish, Norwegian, Polish, Czech, Hungarian, Turkish and Indonesian. English stays on the English one. A french word's link reads "wiktionnaire", and so on for each edition. Entries saved before stay as they were. A word can always be saved, with your own notes, if the lookup fails.

- words: saved and collected are the header, and swipe
  The two lists are the page's header and swipe sideways. A banner floats at the bottom on both lists with the count and the next trophy, and can be dismissed. It comes back for the next trophy.
- you: the streak card swipes between modes
  A swipe header with arrows and dots replaces the mode pills. The month hides the week, and its day cells have a faint border.
- history: playstyle has its own card
  The playstyle card sits under the chart. The summary line is shorter, with the mode icon. Games are shaded rows. The playstyle screen is a page with a back button.
- achievements: lex is a chip at the top right
  It opens the rule and the total earned. The three most recent achievements show what they paid.
- the tab bar has a shadow, the app stretches at the end of a scroll
  Buttons, cards, dialogs, chips and fields share one radius (6), switches are higher contrast, and the ladder has the every-mode step at game 6 and learn at game 24.
- my words: a word with no entry has a retry
  A word is saved even when the lookup fails. Its page says no entry was kept
  and asks for your own notes, and "try the lookup again" fetches the entry
  later and keeps it with your note.
- you: mode settings for free play, one mode at a time
  A new page in you changes the free play settings of a mode you have played
  three times, without switching to it. It lists what each daily always uses.
  The word draw, hearts, blind tries, equation length, colour logic and
  mastermind pool are each mode's own. Tries, length, helper and shared letters
  are one setting, shared by the modes that use them.
- you: the chip is the header; lex joins achievements
  The you page opens with your username chip. Every row has an icon. The order
  is achievements (lex and hints sit at the top of that page, the balance on
  the row), friends and social, reminders, history (with your playstyle),
  backup, support.
- lex: the hint currency, kept and backed up
  Achievements pay lex: bronze 1, silver 2, gold 3, platinum 5. Only the
  highest level a game earns pays, an achievement pays once a day in each
  language, and a game in which a hint was used pays nothing (streaks are
  untouched). Hints cost 10 (grey), 25 (yellow) and 50 (green), can be undone
  until the next guess, and every player has one free hint to start. Players
  with achievements get a one-time starting grant of the medal values they
  hold (formula awaiting confirmation); new players see lex once they have
  played a game. The backup carries the balance and the ledger.

- no more borders on buttons, cards, chips and fields
  Controls are flat fills now. The letter tiles, the keys and the thin lines
  between list rows keep theirs. The black theme has two more fill shades so
  cards and dialogs stay visible on true black.
- hints: spend lex on a clue, with one free hint to start
  A lamp above the keyboard opens three hints: a letter that is not in the
  word (10 lex), a letter that is in it (25) and a letter in its place (50).
  Hold a hint until its bar fills to buy it; undo works until your next guess.
  The hint shows above the keyboard. A game with a hint pays no lex, and the
  streak is safe. Classic, lockdown, geography, quartet and relay have it (not blind, equations or mastermind).
- new look: today, words, learn and you as tabs, as they are taught
  The bar shows today and you first; words joins at game 9 and learn, the last
  piece, at game 24. Today lists your dailies, with the state of each in words
  and a streak; you choose which dailies are yours. The you tab has the streak
  week (with a month view), the theme, a username chip with an icon in the
  logo's colours, and your numbers.
- equations get fewer tries: easy 7, normal 5, hard 4, brutal 3
  A guess can test a lot of numbers at once, so the daily (normal) has 5 tries,
  not 6, and the difficulty grid of the equations says 7, 5, 4 and 3.
- history: a days range beside weeks and months
  The plot can show the last 50 days. Weeks and months are unchanged.
- achievements: the recent ones first, and sorting
  The three achievements earned most recently sit on top, and the list can be
  sorted by closest to the next level, by medal, or a to z.

## 0.9.0

- my words: save words, and collect every word you win
  A bookmark beside the answer on the end screen (lost games too, and on each
  word of a quartet or relay race) saves the word (not a geography or equation answer) with a copy of its
  Wiktionary entry, so it opens without a connection. My words, next to how to play on the
  home page and as a card in learn, lists them with a language filter, search
  and sort, a note of your own on each (shown cut short in the list). Every
  word answer of a won game is also collected like a trophy, by language (and
  places for geography; equation answers are not), in a second tab; its entry is fetched when you open it, and
  the bookmark keeps a copy. Three achievements: word collector (the top level
  is every word of the language), word keeper and annotator. Wins already in
  the history are collected when the achievements are rebuilt. The backup
  carries it all.

- themed is now called geography
  The themed wordle is renamed geography, and the other themes (mythology,
  history, mathematics) are hidden for now; their code stays. Saved games and
  settings keep their place.
- luck achievements average every guess
  A guess made with one word left has no chance in it, so scores 0 luck, and the
  achievements now count it, as the luck on the end screen does. Before, the
  achievement skipped it, so +16% on screen could earn a +20 achievement.
- mastermind and geography have a daily
  Both modes get a daily button on the home page, a streak and a calendar, like
  the other modes. The mastermind daily has no word and no limit on guesses:
  what it says to each guess is drawn from the date, so everyone who makes the
  same guesses gets the same replies (always random pools). The geography daily
  is one five-letter place, English only. A clean sweep counts the dailies a
  language offers, so the geography one is not asked of other languages.

## 0.8.0

- every mode with one board has its own playstyle
  Classic, lockdown, blind, equations, mastermind and themed each read a
  playstyle from their own last 100 games, in each language. The playstyle card
  and the glyph on the home page follow the mode, and the card says which mode
  it is for. The card has a mode filter with an "all" option (every mode with a
  playstyle, read together). The backup carries them all. The quartet and the
  relay race, which play several boards, have none.
- the history can be limited to one mode
  A mode filter under the languages (with "all", the default) limits the overall
  card, the trend and the list of games to that mode.
- the tests run on every pull request
  A CI workflow runs the analyzer on lib (errors only), every test and the paper check
  on each pull request and each push to main, and the debug APK is built on pull
  requests that touch the app.
- blind greys the keyboard once every letter is found
  With the colour logic on, when as many letters are green, yellow or settled by
  the counts as the word has, every other key turns grey.
- a game shows only the top level of each achievement
  The end panel and the history list, and count, only the highest level of an
  achievement a game earned, not every level passed on the way.

## 0.7.3

- the achievements history is a page of its own
  A history button at the top right of the achievements screen opens it.
- a full set achievement, with four levels
  Level 1 is earned once the first level of every other achievement has been
  earned (in any language), level 2 once the second has, and so on to level 4.
- achievements can be earned again
  Every level that counts up (and the days with every daily, the modes won in) starts
  again after its top level, and a repeat of a best-of level or a streak run is shown
  as an unlock like the first. The first win of each mode is earned once. Language
  mastery, the completionist and the styles worn stay once.
- a game in the history shows the achievements it earned
  A strip of their icons on its row, and the full list on its review page, under
  "earned in this game", for classic, quartet and relay games alike. They are kept
  with the game and in the backup. Games from before show none.
- the draw row above the mode button follows the mode, and each mode keeps its own
  The words of a mode: curve, every word, or by frequency, kept for that mode.
  The themed wordle: curve or every place. The equations: nothing to choose, and
  it says so. The mastermind: the pool of a reply, random or the largest. A
  backup carries the choice of every mode; the daily is not affected.
- a lost daily is a red campfire with a cross
  In place of the flame: on the day of the week where the daily was played and
  lost, and as the big icon of the streak card when today's was lost. A day not
  played keeps its unlit flame.
- the streak card is greyed out where there is no daily
  The themed wordle and the mastermind have no daily and so no streak: the card
  stays on the home page, greyed out, and says no daily.
## 0.7.2

- learn weighs the equations and the mastermind as the game does
  The learn pages used the answer curve of the setting for the equations and
  the mastermind, where the game counts every one as likely as the next; so a
  skill in learn could differ from the same guess in the game. They now use
  equal chances there too, which is also what the precomputed openings hold.
- the key of a precomputed opening is the same on the web and on the phone
  The key hashed with a multiplication that a web build rounds, so the web
  asked for files that did not exist. It is now done in 16-bit halves, and a
  test pins the keys. Openings kept before this are worked out again once; the
  precompute workflow has to be run again.
- the styles page names equations and places, the tab names the page on top
  The styles page said "words" in the equations and themed modes. The tab of a
  learn page opened by its address (the guide) was renamed by the page under
  it; now only the page on top names it. The opening page no longer asks for
  second guesses that the precompute workflow never makes for a small list.
- read the clue counts, and the learn pages take keys
  A finished round of read the clue is kept in the learn log, shows its
  progress on the learn home, and earns two new achievements for each mode
  (rounds finished, ten of ten). In choose the best, closing and read the clue
  the keys 1 to 4 choose and enter goes on. Make your own now takes the
  computer's keyboard: type, backspace and delete, shift and backspace clear
  the word, enter makes it.
- precomputed openings, on the web and on the phone
  The web reads the opening of a list from the `precomputed` branch instead of
  working it out (a minute on the web), and the opening page shows the best
  second guesses at once. On the phone, settings has a faster openings section
  that shows the size of the language in use, the equations, the places and
  every list, and downloads the ones chosen; they can be removed again.
- learn achievements are counted for each mode
  Practice, choose the best, closing and three words have their own levels in
  every mode, worded for it (equations, places, words); what was earned in
  classic stays where it was. The days in a row, the languages and the lengths
  count whatever the mode. A learn event now knows its mode (an old one is
  classic's), and the progress on the learn home is that of the mode in view.
- practise a word takes everything the game takes
  Its keyboard takes the colours of the guesses; delete, shift and backspace,
  and shift to lock work; a swipe clears the row; a tap moves the cursor and a
  second tap locks a letter; a double tap on the guesses locks the greens. The
  three words page and the solver take the same keys. A mouse now drags lists
  as a finger does.
- the hint with one word left is one line
  It said it split 1 equation into 1 groups; it now says only that word fits.
- a workflow that precomputes the openings
  Run by hand, it works out the opening of every list ahead, with the app's own
  scoring, and publishes it to the `precomputed` branch (the web app and the
  phone's download will read it; that comes next).
- practise an equation no longer crashes
  The learn pages worked at the word length (5) in the equations mode, where no
  equation has that length, so the page broke. They now use the length of the
  equations, and the number pad, as in the game.
- learn addresses carry the mode
  `#/equations/learn/free` instead of `#/learn/free`: each mode's learn pages
  have addresses of their own, and opening one chooses that mode.
- learn talks about equations and places in those modes
  The learn pages said "word" in every mode; the equations mode now says
  equations, the themed mode places.
- the browser tab names the learn page
  The tab reads like `classic/learn` or `equations/learn/guide`, and the guide
  has its own address, so the browser's back and forward keep it. So does each
  licence text.
- the learn drills work in every mode
  The opening, practise, choose the best, closing and three words now run on
  the words of the mode in view: the equations, the places, or the words of the
  language. Blind shows the counts, not the tile colours.
- learn is short, with pictures
  The strategy page of each mode is short lines under headings, with crops of
  the real tiles where a picture says more.
- how to play is short, with pictures
  Each mode's help shows crops of the real tiles under short lines: the rules
  and what the colours mean, typing, spaces, locks and erase. The same parts
  read the same in every mode.
- make your own works in every mode with an answer
  Classic, lockdown (with its hearts), blind, quartet and relay (four words),
  equations (a true equation, on the number pad) and themed (a place). The link
  carries the mode, so whoever opens it plays that mode as practice. The
  mastermind has no answer to make up, so it has no button there. Links made
  before still open as classic.

- learn has the graduation hat
  On its button in the game modes and in the title of every learn screen.

- mastermind: skill, luck and a review after the game
  Each guess is scored against the words still possible, and the game is
  reviewed against the word it settled on, which fits every reply. The random
  pool has luck too; the largest pool has none, since its replies have no
  chance in them, so it shows skill only. New achievements for skill and luck.

- double tap for the greens works over the gaps too
  Over the submitted guesses as one area: on a tile, in the gap between tiles or
  between rows, or one tap on a row and the next on another. A quartet or relay
  does it per board.
- the space key moves the cursor on every keyboard that has one
  The solvers, the learn page and the three-words page too, as in the games.

- equations: the number pad is laid out like a keypad
  = ÷ × − along the top, 7 8 9, 4 5 6 and 1 2 3 with a tall + and a tall enter
  on the right, then a small 0 and a wide backspace, and the space under it all.
  Dragging the space moves the cursor, as in the other modes.

- the cursor moves by dragging the space key, not the whole keyboard
  As along the space bar of a phone keyboard, and only in the games: not in the
  solvers. The other keys only type.

- haptics for what had none
  A lock going on is a firm click and coming off a light one; erasing a row, a
  swiper stepping, the end panel reaching the top or bottom of its travel, a
  right or wrong answer in a drill, and an incomplete row in the solver all have
  a feel now; the achievements of a game end are three knocks, each harder,
  after the win or loss. The settings switch still turns them all off.

- the end panel shows the boards when it is pulled down
  The boards run on beneath it, so lowering the panel reveals them instead of
  an empty space, and they can be scrolled above it.

- drag along the on-screen keyboard to move the cursor
  A tile for every few finger-widths, with a tick, as along the space bar of a
  phone keyboard. Taps still type. In the games and the solvers.

- equations: the opening is scored the first time the mode is used
  The moment it is chosen (or its length changes), on another thread, and kept
  for every later game. The ten openings used last are kept, older ones are
  worked out again if wanted.

- equations: skill, luck and a review after the game
  Scored as words are, against the best equation that could have been played.
  The opening is searched on another thread from the moment the game starts and
  kept for the next game (about 10 seconds the first time at 8 tiles). New
  achievements for skill and luck. History opens an equations game in its
  review.

- mastermind: the word's wiktionary page loads before the last guess
  The word is known once only one is left, so it is looked up then, and the
  game over page has it at once.

## 0.7.1

- the app looks for an update when it opens, and a toast says so
  Each time it starts (on Android), unless the check is switched off in
  settings. The toast has an underlined link that saves a backup and downloads
  the update; the settings show how it goes. The equations pad has the space
  key, wider.

- a yellow dot above a chevron when a daily is pending that way
  The nearest pending daily in each direction round the modes, so at most two
  dots, one above each chevron. The mode in view is not counted.

- split keys: the letter has a stronger shadow
  A ring of shadow in the opposite colour all round the letter, so it reads
  over yellow and green.

- history: equations and mastermind games can be opened
  Tap one in the list to see its board as it was played, each guess coloured.
  They have no review, so the board is all there is.

- the mode swipe is a ratchet
  A drag across the whole button turns three modes: the face follows the
  finger and takes the next mode as each third is passed, with a tick. A short,
  quick flick is still one mode.

- achievements for winning in every mode and for every daily of a day
  Every way in (win in 2, 4, 6 or 7 different modes), a full day (solve 2, 3,
  4 or 6 different dailies in one day) and clean sweep (every daily on the
  same day, 1, 7, 30 and 100 days). The equations daily now counts among the
  dailies and double fires too.

- hold alt to see every shortcut and gesture
  After a tenth of a second a frosted pane lists them, for as long as alt is
  held. It takes no touch or key: the screen under it goes on working.

- a swipe from right to left erases the row being typed
  Over the current guess only. Shift and backspace do the same on a keyboard,
  and delete works like backspace. The game's own locks stay.

- an update is downloaded once
  If Android's installer is closed (or the install permission is asked for),
  pressing install opens it again on the file already downloaded, checked
  against GitHub's checksum, instead of downloading it a second time.

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
