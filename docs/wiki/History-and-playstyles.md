# History and playstyles

Every finished game is kept (up to 10,000) as two tables, so that nothing is lost if the maths
changes: a row per game (when, language, mode, length, tries, pool, the answers, won, the daily
date) and a row per guess (the word, with its skill, luck, risk, bits and pool sizes, and what the
playstyle reads, cached under the version of the maths that made them). The guesses are the facts; the scores can be
thrown away and worked out again, which happens, game by game, newest first, when the history is
opened after the maths has changed (a game scored with older maths counts as played but is left
out of the averages until then). Rows are compact lists, and are saved a month at a time, so
finishing a game rewrites one month, not the whole record. The history is in the backup.

## The history page

Tap your playstyle on the home screen. A row of flags picks the language (see
[Languages](Languages)); the page is about that language. It has:

- the playstyle, and what it is read from;
- an **overall** analysis of every game, however many (games, won, skill, risk, luck, guesses
  to win);
- **how play changed**: a line each for skill, luck and risk over the last 50 weeks (rolling
  seven-day windows ending today) or the last 50 months, with a gap where nothing was played. Tap
  or drag along it to pick a period and see its games, its numbers, the change on the last period
  you played, and the playstyle that period alone would have. Luck is drawn about the middle
  line, which is a luck of 0; see [Skill, luck and risk](Skill-luck-and-risk);
- the games, newest first: **the last ten, and "load 10 more" as you need them**. Each opens its
  review, rebuilt from the guesses alone.

## Playstyles

Your **playstyle** is read, **per language**, from your last 100 classic games in it (a daily is
one). It is two habits: what you do early, and what you do at the end.

Each guess is counted as one thing, the first that applies.

| When | Behaviour | The guess |
| --- | --- | --- |
| early: 64 or more words left | **gambler** | has a risk of 75 or more |
| | **maximiser** | is in the top 10% of the guesses scored, by expected gain |
| | **eliminator** | has four or more letters never tried in the game |
| end: 16 or fewer words left, or 3 greens known | **closer** | fits every clue, so it can win |
| | **prober** | does not fit, is in the top 10%, and 3 or more words are left |

A **habit** is the behaviour with the largest share of a phase's guesses, if that is 40% or more.
You are rated once you have 10 games and 10 guesses in each phase. Your style is your early habit
and your end habit:

|                    | prober at the end | closer at the end |
| ------------------ | ----------------- | ----------------- |
| **maximiser** early | analyst           | maverick          |
| **eliminator** early | detective        | sweeper           |
| **gambler** early  | wildcard          | gambler           |

It moves as you play, and a margin of 5 points keeps one game either side of a line from changing
your habit. The playstyle page shows, with a real game for each style, how each guess was counted,
and the exact rules behind the info dots. The thresholds come from simulated players of the six
styles played through the app's own maths (paper, Playstyles); they are **not measured on people
yet**, so treat the style as a first reading.

## When saved data cannot be read

The history is kept one block per month. If a stored row cannot be read (for example after a change
between versions), only that row is left out, not the month, and the rest of the progress (stats,
daily log, achievements, settings) is read on its own. The unreadable text is kept under its own key
with `:unread` added, so saving what was read does not overwrite the only copy. There is no message
in the app for this; each start prints one line to the device log (`lexodle: start v… found N keys,
M games, P played, R rows skipped`), readable with `adb logcat -s flutter`. Backups are still taken
whole or not at all.
