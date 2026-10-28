> **Superseded.** Written for the expected-pool version of the maths (skill from the expected pool, daring, the tries fit). Skill, luck and risk are now measured in bits; see `docs/paper/main.tex`. Kept for the record.

# Whole-paper verification (Opus subagent, 2026-10-25)

Scope: the reviewer read all of `docs/paper/main.tex`, checked every proof, traced every saved number to
`experiments/results`, re-ran the main experiments (verify_theorems, reduction_accounting,
luck_definitions, worked_game, prior_bias, play_skill, capacity_bound; all outputs identical), and
compared the paper with `logic.dart` and `multi_analysis.dart`. Not done: the Dart experiments
(calibrate_styles, predict_tries), risk_attitude.py and first_guess.py, the LaTeX build, the Flutter
tests.

## Verdict

The core maths of skill, luck and the accounting identity is right. Lemma 1, Proposition 2, Theorem 3
(including the variance (1 - sum q^3)/3, re-derived), Proposition 5's counterexamples and
Proposition 7's identity check line by line. Every saved number traced to its source. The problems are
in what the results are said to cover.

## Errors, by severity

Wrong results or claims

1. **Luck claims are unconditional** (abstract, (R3), plain.tex). They are proved only under (U): every
   possible word equally likely. The app, the quartet and the experiments draw answers by word
   frequency. prior_bias.txt shows mean luck then depends on the guess and rises with skill (tares +10.2,
   crane +10.6, abbey -6.4, mamma -8.2). plain.tex says "independent", which is wrong in the game as
   played. Fix: state "under (U)" in the abstract and (R3), drop "independent", or compute luck under the
   weighted law (Theorems 3 and 4 carry over unchanged).
2. **Proposition 9** (multi-board): its hypothesis fails in the app, which draws quartet answers by
   frequency, all distinct, preferring sets with no shared letters.
3. **Proposition 6**: "that loss belongs to skill" is false for skill as defined. A probe with the best
   split on the last try scores skill 100 and luck 0, so the loss appears nowhere. Define last-try skill
   (for example the chance of winning against 1/n) or delete the sentence.
4. **Proposition 8(3)**: the maximum 1 - 1/tau is never reached (a possible word splits itself off, so
   skill > 0). 8(2)'s case p = 1 needs N = 1, where daring is undefined, so it is vacuous.
5. **Daring at the opening guess**: every word is possible, so D = (1 - S)(1 - p)(5/6), a function of skill
   alone (crane 15.3, the median opener 27, more than the "frequent" player's mean of 19.7); wild's 6.0 is
   almost entirely its opener. This contradicts "separates the players by what they try, not by how good
   they are". The same section calls wild a player who "works the clues" (it ignores them) and says
   best-fit goes for the word "only when a good split", against "always an attempt at the word".
6. **Section 9.6 regression**: answers are drawn by frequency but luck assumes equal chance; last-try luck
   nearly encodes the outcome; everything is in-sample from one seed (R-squared 0.542 at 250 games, 0.483
   at 400 for the same model). "A game that ends early did so by a lucky split" is speculation.

Gaps

7. Theorem 4's proof: S_t is not F_{t-1}-measurable when the guess uses independent randomness; condition
   on the guess too. State luck is 0 after the game ends and that last-try luck also has conditional mean
   zero. The result covers Cov(luck_t, skill_s) for s <= t, not game-level sums.
8. Setting vs Proposition 2: needs "all green iff g = w", the setting says "only if".
9. Proposition 5(2): "nonzero unless a_max - E = E - 1" fails for equal class sizes ({2,2}: mean 0).
10. Daring uses the frequency weights, which the player does not see, while skill and luck use (U): two
    answer models in one score, against the stated justification of (U).

Notation and stale text

11. "A" is the answer and also the words remaining; "n" is the word length and also the number of fitting
    words; S is in [0,1] in Definition 3 and [0,100] in Section 6.
12. L626 calls H "the risk term" (it is the expected reduction). Table 4's caption gives standard errors of
    1.2 to 1.5 points but the within-six columns differ by 0.2 to 0.6: "no loss within six" overstates.
13. The multi-board daring Remark says equal weights, but the quartet and relay have no daring. A Remark
    promises a sharper bound from the clues; Section 9.9 shows it never improves the naive bound.
14. Open problem 8 is answered (a tie rule giving tied mass weight lambda has mean (2 lambda - 1) sum q^2,
    so only the mid-rank is fair for every law); problem 1 is mostly answered by Theorem 3(3)'s
    exchangeability argument; problem 9 is largely trivial (hard mode: possible words are still legal).

## Paper, results and code

Numbers: all match. verify_theorems.py: tests Theorem 3, Proposition 5 and Example 1 properly; for
Theorem 4 it correlates luck with the linear (n - E)/(n - 1), not skill; it does not test last-try luck,
multi-board, daring or non-uniform draws.

Code: review.dart:554 still shows the old daring definition; multi_analysis.dart:12-14 comment is stale
(linear skill, E-based luck); skillAgainst clamps to [0,100] and returns 100 when no guess splits (hides a
truncated E*); analyseGuesses for n <= 2 stores skills for only k words, so the percentile is not over
every guess; scoreGuess gives a word with no weight a weight of 1 (undocumented).

## The three changes that help most

1. Rewrite the claims for the frequency draw: compute luck under the weighted law, or state (U) in the
   abstract and (R3) and flag the bias in 9.5, 9.6 and Proposition 9.
2. Fix daring: the opening guess, Proposition 8(2) and (3), the Section 9.5 player descriptions, and the
   stale text in review.dart:554 and the L479 Remark.
3. Repair Proposition 6 and Theorem 4: define last-try skill, condition on the guess's randomisation, state
   the after-game convention, and limit "uncorrelated with skill" to s <= t.
