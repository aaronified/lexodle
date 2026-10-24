# Review of the signed-daring proposal (Opus subagent, 2026-10-25)

The reviewer read `signed-daring-proposal.md`, `app/lib/logic.dart`, the paper's sections on luck, the
accounting identity, daring and the guesses fit, and the two experiment tools. It did not re-prove the
whole paper, and it did not rerun the experiments. Its findings, condensed:

## Recommendation

- **Skill: keep it.** `100 ln(n/E) / ln(n/E*)` is the skill term of the exact identity and predicts the
  guess count better than a percentile does (0.136 against 0.026 alone). Even spread over the options is
  not a sensible goal for skill: the shape of its distribution changes with n, and a position-dependent
  transform is just the percentile again. For a figure that is even over the options, show "beats X% of
  options" (`Landscape.percentile`) beside it.
- **Luck: keep the form, fix the probability law.** Luck is Cliff's delta of the outcome against an
  independent copy, so its mean is zero under any answer law. It should use the law the game draws
  answers from (frequency-weighted); daring already uses weights, so two answer models sit side by side.
- **Daring: the same Cliff's-delta construction, against a reference choice law Q** (what a competent
  player picks here): `D(g) = 100 * sum_h Q(h) (1[k(h) < k(g)] - 1[k(h) > k(g)])`, with key
  `k = 1[possible] (1 - skill/100) (1 - p)` (no tries factor). Mean zero under Q, in (-1, 1), mid-rank
  ties, depends only on the position and the choice. Q: a softmax over skill that also weights the
  possible words, or empirical choices per (n-band, tries). The proposed boldness order is not to be
  adopted.

## Errors found in the proposal

1. The rank daring on the boldness order is almost the reverse of the skill percentile (for a probe it
   equals roughly minus twice the percentile minus 100), so fits C and E are collinear and their
   coefficients mean nothing.
2. In that order a useless probe (skill 0) is rated almost maximally daring: a bad probe is unskilled,
   not daring.
3. Tries left drops out of any rank daring (a constant within a position); at 1 try left every
   possible word ties at 0.
4. The simulation draws answers by frequency, but `chanceLuck` assumes equal chance, so luck's zero
   mean and zero covariance with skill are not guaranteed in the fitted data.
5. Luck has real atoms: an even split gives 0 for every outcome, a probe on the last try gives 0, and
   luck ignores whether the singleton landed in is the guess itself (solved) or another word (one more
   try), which is what the guess count depends on.
6. The R-squared differences are within noise (the same fit gave 0.483 at 400 games and 0.542 at 250);
   everything is in-sample from one seed.
7. Game-level means are endogenous (short games average only opening guesses), and a lost game coded 7
   is a censored value treated as exact.
8. Raw daring mostly records "guessed a possible word"; test the win-now chance directly.
9. The app and the tool take percentiles over different sets (for n <= 2 the app scores at most k words).
10. Strict less-minus-more and mid-rank are the same thing (2 mid-rank - 1): no real tie conflict.

## A better evaluation

Work in bits so the identity holds and sum over the game; a discrete-time hazard model (or an ordinal
logit with a loss category) on each guess's scores plus n and tries left; at least 2000 games over several
seeds and languages with held-out data, paired-bootstrap intervals on the differences, and variance
inflation factors. Partial skill out of daring so the coefficients can be read.

## Before building

(a) check whether the win-now chance alone matches raw daring's contribution; (b) check luck under the
weighted law keeps mean zero and stays uncorrelated with skill; (c) fit Q from the simulation's habit
mixture and check the Q-based daring has mean about 0 for each tries-left and a usable spread when
n <= 20; (d) decide whether the outcome is "guesses" or "guesses given a win".

## Edge cases of the rank daring

Late positions (probes about 99% of the options): possible words all land near +100 and probes are
spread by skill, meaningless as daring. n = 2: both words tie with zero-skill probes. n = 1: undefined
(the code returns null; the screen must not show 0). Tries left 1: undefined. Tries left 2: the same
ranks as at 6 although the decision is very different. Tie atoms plus the tolerance give arbitrary
middling values. Tiny n with a uniform Q over thousands of options: the rank depends on how many junk
words the dictionary has, which the Q-weighted version fixes.
