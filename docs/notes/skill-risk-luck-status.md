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

## Boldness: the definition to use (not implemented yet)

First idea (written into `boldness_calibration.py` and its results): risk of a guess =
`H - H2` (bits, Shannon minus collision entropy), boldness = its percentile among *every*
real guess in that position.

**Owner's correction, to implement:** compare against the guesses of **higher skill**
only. Boldness should say the player *chose* to be bold instead of showing skill: of the
guesses that were better, how many were less risky than the one played? The best-skill
guess has nothing better to compare with, so it carries no boldness. The calibration
script and its thresholds must be redone under this definition (the results file is for
the old one).

## Plan for tomorrow, in order

1. Boldness as above in `analyseGuesses` (`Landscape` keeps each candidate's skill and
   risk; boldness = share of strictly higher-skill candidates that are less risky).
2. Review: under the plot, `cut X bits (A -> B words) = expected Y + luck Z`, and a
   boldness line. Last-try steps keep their own plot.
3. `GameResult` carries per-guess boldness and total luck bits; recalibrate thresholds
   by simulation, then two achievements: `daredevil` (bold games, count) and
   `safe hands` (wins without a bold guess).
4. Play history (capped, in the backup file) and a profile page: skill, first-guess
   quality, boldness tendency, dependence on luck (share of wins that needed positive
   luck), net luck against expectation, and rule-based suggestions (for example the best
   opener for the language, play safer when bold guesses lose, try a guess that can win
   when few words remain).
5. Paper: say that risk is reported as a trait, not a reduction term; redo the risk
   section with the new boldness; add the profile idea as future work.

## Open

- Indic languages (which, and how a "letter" works in Devanagari and similar scripts).
- Quartet and relay race: bits breakdown and boldness per board.
- Whether to show the paper PDF anywhere other than the repo owner's machine.

## Not for this repo

The owner pasted a screenshot of Tippani's share dialog (THEME / MATERIAL / PORTRAIT /
SIDES / SIGNATURE / COLOUR toggles) asking for more compact buttons, then withdrew it
("not for you"). Nothing in Tippani was changed.
