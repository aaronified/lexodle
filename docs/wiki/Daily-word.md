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
five-letter words that share no letter, drawn on the same curve by the date, the language and the
mode, the same for everyone, with 9 tries (quartet) and 10 (relay). The **lockdown** daily is a
single word with 6 tries and 5 hearts. The mode in view on the
home page, which you change with its chevrons or by swiping, decides which daily the daily button
plays. Each mode has its own streak, calendar and best. It is saved as you go, so closing the page
cannot reroll it, and it is played once a day.

- **The day** is the player's own calendar date, changing at their local midnight.
- **The clock.** So that the device clock cannot be set to another day, the app asks the server it
  is hosted on for the time (the `Date` header of one request, nothing else, no other service)
  when it starts, and again before opening the daily if the last answer is over ten minutes old.
  After that the time moves on by a monotonic clock that the player cannot change, so changing
  the device date afterwards does nothing. **If the server cannot be reached, the system time is
  used**, quietly, so the daily still plays offline. Anything saved on the device can of course
  still be edited by the person who owns it.
- **The streak** counts the days in a row on which a daily was solved **in that language and mode**: each
  language and each mode has its own streak and its own calendar (see [Languages](Languages)). A day not played
  yet does not break it; a day missed does. The home page shows it as a fire with the week
  (Monday first) and the language's flag. A **double fire** is a daily solved in three guesses or
  fewer, or with every guess at 80 skill or more.

## Sharing a puzzle

Dailies are not shared: everyone opens the app and plays the same daily. The link button is for
ordinary games (every mode) and for a shared puzzle already open. It offers two links to copy:

- **the puzzle**: the word (four for a quartet or a relay race) goes in the link only as a hash, so it
  does not give the word away; the length and the tries are in it;
- **the puzzle and my guesses**: the same, with the guesses made so far in plain. It opens already
  played, so whoever opens it sees the guesses and what they showed, and can go on from there.

`https://aaronified.github.io/lexodle/#/puzzle?l=en&m=classic&n=5&t=6&w=<hash>&g=crane.slate`

Whoever opens a link plays it in a browser as **practice**, with only the colours and the tries left:
it is never saved or counted (no streak, calendar, history, statistics or achievements). The app finds
the word by hashing the words of that length in the language until one matches; a hash is a disguise,
not a secret, since anyone can do the same. A link with a damaged hash, or a language or mode the app
does not know, opens the home page instead. The link opens the web app; it does not open the Android
app by itself.
