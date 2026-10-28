> **Superseded.** Written for the expected-pool version of the maths (skill from the expected pool, daring, the tries fit). Skill, luck and risk are now measured in bits; see `docs/paper/main.tex`. Kept for the record.

# Skill, risk and luck: status and plan

Written 2026-10-19 so the next session can start from here. The maths and the paper
are in `docs/paper/` (see its README); this file is what was *decided* and what is
*next*.

## What is built and pushed

- **Skill** = `ln(N/E) / ln(N/E*)`, `E` the expected pool, `E*` the smallest `E` over
  every real guess (scanned in the background). Log scale because the linear one
  crowds first guesses near 100.
- **Luck** = chance of a bigger pool minus chance of a smaller one, strictly inside
  (-100, +100)%, mean exactly 0, a martingale difference over a game. Last-try luck is
  0 for a guess that cannot win.
- One plot (`SplitPlot`) for skill and luck; quartet and relay race use the same maths
  per board (log2-weighted); in-game skill shows dots until the analysis lands and the
  end of a game waits for it before recording achievements.
- Backup (download/upload) in settings, route per screen, theme setting, onboarding
  start button, `luckiest man alive`, language mastery as one achievement.
- Paper: `docs/paper/main.tex`, compiles with Tectonic (`tectonic main.tex`, installed at
  `~/bin/tectonic.exe`). Experiments and saved results in `docs/paper/experiments/`.
  **The PDF is not committed** (git-ignored) by the owner's choice; committing it would
  not stop submission (check the venue's policy on public drafts, especially
  double-blind).

## Decisions (owner)

1. Luck keeps the uniform prior ("option 1"). The game draws answers by frequency, which
   gives a mean luck of about +10% for strong openings and -7 to -8% for weak ones. This
   is documented in the paper, not corrected.
2. **Risk is behavioural, not a source of reduction.** The review shows
   `cut = expected + luck` in bits (expected = the Shannon entropy H of the split). Risk
   is reported separately as a trait of the player's choice, never added into the sum.
3. **No extra skill credit for a guess that can win at once.** Skill is unchanged.
4. Skill achievement thresholds stay as they are (checked by simulation: a strong player
   gets every guess above 90 in 27% of won games, a casual one never).
5. Paper style: direct and succinct, no rhetoric.

## Daring (the owner's word for boldness): redefined 2026-10-24

Risk of a guess = `H - H2` (Shannon minus collision entropy, in bits) is a property of the guess
and stays in the accounting. **Daring** is now about going for the whole word: `100 * [guess could
be the answer] * (1 - skill/100) * (1 - chance it is the answer, by frequency) * (1 - 1/tries
left)`. It is 0 for a probe, on the last try, and for a best-split guess that also fits. It is in
`logic.dart` (`daringOf`, `GuessMetrics.daring/possible/winChance/triesLeft`); stored games carry
`metricsVersion` 2 and older ones are scored again. The share-of-safer-guesses daring and the first
(percentile) one are superseded; the latter is kept for the record in `boldness_calibration.py`.
Calibration: `app/tools/calibrate_styles.dart` (`results/daring_calibration.txt`): frequent and
random-fit about 20, best-fit about 4, wild about 6, best 0. Splits 2.5 / 12 / 12.
Tries: `app/tools/predict_tries.dart` (`results/predict_tries.txt`): skill + luck explain 0.46 to
0.60 of the variance in tries, daring adds 0.015 to 0.04. Quartet and relay have no daring weights
(every possible word is as likely as the next).

## Also built (2026-10-24)

- **Solver follows the settings** (2026-10-24): advice depends on the tries left (`recommendWithin`:
  two left, best chance of solving by the last try, weighted by frequency; one left, only the
  likeliest word that fits), and the quartet and relay race have their own solver
  (`multi_solver.dart`: shared guesses, per-board colours, relay boards open with blank rows to
  colour in; uses `recommendMulti` and `finalPicks`). Not done: two-tries-left advice for the
  multi-board modes, and the daring of the solver's advice.

- **History** as two tables (games, guesses) with the cached scores stamped by
  `metricsVersion`; games saved under an older one are scored again when the history page
  opens (`replay.dart`). In the backup as one compact line. Up to 10,000 games, saved by month.
- **Playstyles**: six (analyst, maverick, steady, gambler, wanderer, wildcard) from the means of
  skill and daring over the last 100 classic games, with a margin against flapping; shown on the
  home page; 8 achievements. **Thresholds come from simulated players at five letters, not from
  people.**
- **Daily word**, streaks and the double fire, with the trusted clock (server `Date` header,
  then a monotonic clock; the system time if the server cannot be reached).

## Next (not done)

1. Review: under the plot, `cut X bits (A -> B words) = expected Y + luck Z`. Last-try steps keep
   their own plot.
2. A profile of tendencies and rule-based suggestions (best opener for the language, play safer
   when bold guesses lose, try a guess that can win when few words remain), on the history page.
3. **Recalibrate the playstyle thresholds on real play, and per word length**: skill is not
   comparable across lengths (a player who ignores the clues scores 48 at five letters and 69 at
   eight).
4. Boldness for quartet and relay race (history rows have none; the playstyle reads classic only).

## Open

- Indic languages: wordfreq has Hindi, Bengali, Tamil and Urdu (Marathi falls back to Hindi, and
  Telugu, Malayalam, Kannada and Nepali silently to English). Which, and how a "letter" works in
  Devanagari and similar scripts (a tile is a grapheme cluster), the keyboard, and whether the
  Hunspell collections have dictionaries for them.
- Quartet and relay race: bits breakdown.
- Whether to show the paper PDF anywhere other than the repo owner's machine.

## Not for this repo

The owner pasted a screenshot of Tippani's share dialog (THEME / MATERIAL / PORTRAIT /
SIDES / SIGNATURE / COLOUR toggles) asking for more compact buttons, then withdrew it
("not for you"). Nothing in Tippani was changed.
