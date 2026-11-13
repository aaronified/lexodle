# Daily word

Everyone gets the same word on the same date, in every language: the date and the language are
hashed to pick a word, with no server involved. **From 2026-10-30** the whole word list is in play and
each word has a chance on a sigmoid curve of how common it is: the 2,500 commonest words are almost
equally likely, the next 500 fall from 100% to 50% of that, the 500 after fall from 50% to 0%, and
the rest have almost none. The curve is at half at the 3,000th word and is the same in every
language, however short its list (a short list most likely means an incomplete one):
`chance = 1000 / (1 + exp((rank - 3000) / 125))`, in whole numbers so that every device draws the same
word. Before that date the pick was one of the 3,000 commonest words, each equally likely, and those
days keep that draw. Every word of the list is a valid guess in a daily, whatever the date.

A word is not picked again within 90 days: each day's pick is redrawn if it was a daily in the last
90 days, replayed from a fixed start date (2026-10-26, and 2026-10-30 for the curve), so it depends
only on the date and not on when the app was last opened. A daily is always five letters and six
tries, whatever the settings say. Its skill and luck are worked out under the same chances the word
was drawn by, and the review says so.

**Each mode has its own daily.** The quartet and the relay race have a daily of their own: four
five-letter words, drawn on the same curve by the date, the language and the mode, the same for
everyone, with 9 tries (quartet) and 10 (relay). As in any other game, a word may share a letter
with an earlier one with a 10% chance, and a word with a letter twice counts as sharing one (before
2026-10-31 the words shared none, which favoured words with a letter twice). The **lockdown** daily
is a single word with 6 tries and 5 hearts. The **blind** daily is a single word with 10 tries,
played by the counts alone. The **equations** daily is one 8-tile equation with 5 tries, the same in
every language. The **mastermind** daily has no word and no limit on guesses: what it says to each
guess is drawn from the date, the language, the number of the guess and the guess itself (from the
pool of words still possible, as in the random pool), so everyone who makes the same guesses gets
the same replies, and the daily always uses random pools. The **geography** daily (English only) is
one five-letter place name with 6 tries, drawn on the places' own curve by the date. Today lists the dailies you chose (**choose dailies**, from game 4); each row plays that mode's daily, and the bottom button plays the next one not done. The others sit under **more dailies**. Each mode has its own streak, calendar and best. It is saved as you go, so closing the page
cannot reroll it, and it is played once a day.

- **The day** is the calendar date in India (IST, UTC+5:30) for everyone, so the dailies change at the same instant all over the world (18:30 UTC). Today shows the time left.
- **The clock.** So that the device clock cannot be set to another day, the app asks the server it
  is hosted on for the time (the `Date` header of one request, nothing else, no other service)
  when it starts, and again before opening the daily if the last answer is over ten minutes old.
  After that the time moves on by a monotonic clock that the player cannot change, so changing
  the device date afterwards does nothing. **If the server cannot be reached, the system time is
  used**, quietly, so the daily still plays offline. Anything saved on the device can of course
  still be edited by the person who owns it.
- **The streak** counts the days in a row on which a daily was solved **in that language and mode**: each
  language and each mode has its own streak and its own calendar (see [Languages](Languages)). A day not played
  yet does not break it; a day missed does. Today shows each daily with its mode icon in a square (green solved, yellow in progress, red when missed) and a flame with its streak. The you tab has a streak card that swipes between modes: the last seven days, today last, with a green flame for a solved day (two for a double fire), a skull for a lost one and a dim flame for a day not played, and a month view. A **double fire** is a daily solved in three guesses or
  fewer, or with every guess at 80 skill or more.

## Sharing a puzzle

Dailies are not shared: everyone opens the app and plays the same daily. The link button is for
ordinary games (every mode) and for a shared puzzle already open. It offers two links to copy:

- **the puzzle**: the word (four for a quartet or a relay race) goes in the link only as a hash, so it
  does not give the word away; the length and the tries are in it;
- **the puzzle and my guesses**: the same, with the guesses made so far in plain. It opens already
  played, so whoever opens it sees the guesses and what they showed, and can go on from there.

`https://aaronified.github.io/lexodle/#/puzzle?l=en&m=classic&n=5&t=6&w=<hash>&g=crane.slate`

Whoever opens a link plays it as **practice** (in the app on Android, in a browser elsewhere), with only the colours and the tries left:
it is never saved or counted (no streak, calendar, history, statistics or achievements). The app finds
the word by hashing the words of that length in the language until one matches; a hash is a disguise,
not a secret, since anyone can do the same. A link with a damaged hash, or a language or mode the app
does not know, opens the home page instead. On Android the link opens the app itself; elsewhere it opens the web app.
