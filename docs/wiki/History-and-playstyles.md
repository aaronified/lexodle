# History and playstyles

Every finished game is kept (up to 10,000) as two tables, so that nothing is lost if the maths
changes: a row per game (when, language, mode, length, tries, pool, the answers, won, the daily
date) and a row per guess (the word, with its skill, luck, daring, risk and pool sizes cached
under the version of the maths that made them). The guesses are the facts; the scores can be
thrown away and worked out again, which happens, game by game, newest first, when the history is
opened after the maths has changed (a game scored with older maths counts as played but is left
out of the averages until then). Rows are compact lists, and are saved a month at a time, so
finishing a game rewrites one month, not the whole record. The history is in the backup.

## The history page

Tap your playstyle on the home screen. A row of flags picks the language (see
[Languages](Languages)); the page is about that language. It has:

- the playstyle, and what it is read from;
- an **overall** analysis of every game, however many (games, won, skill, daring, luck, guesses
  to win);
- **how play changed**: a line each for skill, luck and daring over the last 50 weeks (rolling
  seven-day windows ending today) or the last 50 months, with a gap where nothing was played. Tap
  or drag along it to pick a period and see its games, its numbers, the change on the last period
  you played, and the playstyle that period alone would have. Luck is drawn about the middle
  line, which is a luck of 0%. A fourth line, **guesses**, is the expected number of guesses a
  game takes, on its own scale (1 to 7) at the right edge; see
  [Skill, luck and daring](Skill-luck-and-daring);
- the games, newest first: **the last ten, and "load 10 more" as you need them**. Each opens its
  review, rebuilt from the guesses alone.

## Playstyles

Your **playstyle** is read, **per language**, from your last 100 classic games in it (a daily is
one): the means of skill and of daring over the guesses that had a choice to make, once you have
10 games. Skill gives three tiers (loose, solid, sharp) and daring splits each in two, which
makes six styles, each with an icon shown on the home page:

|           | careful   | bold     |
| --------- | --------- | -------- |
| **sharp** | analyst   | maverick |
| **solid** | steady    | gambler  |
| **loose** | wanderer  | wildcard |

Careful means working the clues; bold means going for the word itself. It moves as you play, and
a margin around the line keeps one game either side of it from changing your style. The
thresholds come from simulated players of seven habits played through the app's own maths (paper
Section 9.5); they are **not measured on people yet**, and skill is not comparable across word
lengths, so treat the style as a first reading.

## When saved data cannot be read

The history is kept one block per month. If a stored row cannot be read (for example after a change
between versions), only that row is left out, not the month, and the rest of the progress (stats,
daily log, achievements, settings) is read on its own. The unreadable text is kept under its own key
with `:unread` added, so saving what was read does not overwrite the only copy. There is no message
in the app for this; each start prints one line to the device log (`lexodle: start v… found N keys,
M games, P played, R rows skipped`), readable with `adb logcat -s flutter`. Backups are still taken
whole or not at all.
