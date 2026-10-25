# Daily word

Everyone gets the same word on the same date, in every language: the date and the language are
hashed to pick one of the 3,000 most common words of the language, every one equally likely and no
other word ever, with no server involved. A word is not picked again within 90 days: each day's
pick is redrawn if it was a daily in the last 90 days, replayed from a fixed start date (2026-10-26),
so it depends only on the date and not on when the app was last opened. A daily is always five
letters and six tries, whatever the settings say. It is saved as you go, so closing the page
cannot reroll it, and it is played once a day.

- **The day** is the player's own calendar date, changing at their local midnight.
- **The clock.** So that the device clock cannot be set to another day, the app asks the server it
  is hosted on for the time (the `Date` header of one request, nothing else, no other service)
  when it starts, and again before opening the daily if the last answer is over ten minutes old.
  After that the time moves on by a monotonic clock that the player cannot change, so changing
  the device date afterwards does nothing. **If the server cannot be reached, the system time is
  used**, quietly, so the daily still plays offline. Anything saved on the device can of course
  still be edited by the person who owns it.
- **The streak** counts the days in a row on which a daily was solved **in that language**: each
  language has its own streak and its own calendar (see [Languages](Languages)). A day not played
  yet does not break it; a day missed does. The home page shows it as a fire with the week
  (Monday first) and the language's flag. A **double fire** is a daily solved in three guesses or
  fewer, or with every guess at 80 skill or more.
