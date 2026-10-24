# Signed daring, and how evenly skill, luck and daring spread: a proposal to review

Written 2026-10-25 for a maths review. Nothing here is built yet.

## What the owner asked for

1. Daring should be a signed number like luck (luck is -100 to +100, with 0 the middle outcome).
2. "All three, skill, luck and daring, must be spread between all possible options, more or less
   equally. And their combination should predict the count of guesses to solution."

## The definitions as they stand (app/lib/logic.dart, docs/paper/main.tex)

Position: n words still possible, tau tries left (this one included), each word with a weight w
(frequency). A guess g splits the possible words into groups; the sum of squared group sizes
gives the expected pool E(g) = sum(c^2)/n. E* is the smallest E over all guesses the game accepts.

- skill(g) = 100 * ln(n/E) / ln(n/E*)   (0..100; 100 = as good as the best guess)
- luck(g, outcome) = 100 * (P(land in a bigger pool) - P(land in a smaller pool)), probabilities
  over the possible answers (equal chance for each word in the app). Mean zero over answers for
  every g (a theorem). Range -100..100. Distribution over answers is roughly uniform.
- raw daring(g) = 100 * 1[g possible] * (1 - skill/100) * (1 - p(g)) * (1 - 1/tau), with
  p(g) = w(g) / sum of weights of the possible words (0 for a probe). Range 0..100. It is 0 for
  every probe, so most options tie at 0.

## What was measured (tools/spread_check.dart, tools/predict_tries2.dart, English 5 letters)

Over all ~5000 guesses the game accepts, in the opening (n = 4994, tau = 6):

| score | share of the options in each tenth of its scale |
| --- | --- |
| skill | 0 0 0 2 8 18 30 26 13 3 (a hump at 60 to 80) |
| raw daring | 4 21 36 26 10 2 0 0 0 0 (all below 50) |
| luck, over the answers, best guess | 7 14 9 11 10 9 10 10 11 10 (roughly even) |

Later in a game (n = 91, 33, 18) skill is spread over the lower and middle tenths and raw daring
puts 99% of the options in the first tenth (nearly every option is a probe, with raw daring 0).

A rank daring over all options (share of options less daring minus share more daring) is exactly
even in the opening (10% in every tenth) but, with probes tied at 0, puts 98% of the options at
about 0 once few words are left.

## Candidates for the signed daring

- Boldness order b(g): a guess that could be the answer has b = raw daring; a probe has
  b = -skill(g) (so the best probe is the most careful, a poor probe sits just below the words).
  darRank(g) = 100 * (share of options with b < b(g) - share with b > b(g)). Even over the options
  by construction, signed, and without the atom of ties at the probes.
- skillPct(g) = mid-rank share of options that g beats (0..100): even over the options by
  construction.

## Predicting the guess count (250 simulated games, mixed habits, English 5)

Least squares of tries (a lost game counts 7) on the game's mean of each score over its guesses
with a choice:

| regressors | R^2 |
| --- | --- |
| skill (log) | 0.136 |
| skillPct | 0.026 |
| luck | 0.370 |
| raw daring | 0.022 |
| rank daring | 0.000 |
| skill + luck + raw daring (now) | 0.542 |
| skillPct + luck + raw daring | 0.463 |
| skillPct + luck + darRank | 0.475 |
| skill + luck + darRank | 0.564 |
| skill + skillPct + luck + darRank | 0.565 |

So replacing log skill with its percentile among the options costs about 8 points of R^2, and a
rank daring on the boldness order costs nothing (a gain of 2).

## Questions for the reviewer

1. Are the definitions of luck, raw daring, the boldness order and the rank daring mathematically
   sound? Properties worth checking: bounds, the treatment of ties (mid-rank versus the strict
   less-minus-more that luck uses), whether the rank daring is well defined when most options tie,
   whether it depends only on the position and the choice (not on the answer), and invariance.
2. "Spread more or less equally": is the right reading that each score should be roughly uniform
   over the options (skill and daring) or over the outcomes (luck)? Skill as a log-ratio is not
   uniform over the options and the measurement shows a percentile skill predicts the guess count
   worse. Is there a transform of skill that is closer to even over the options and loses no
   predictive power (a fixed monotone transform, a mix, or a different quantity)? Or should skill
   keep its definition (which is tied to the exact accounting identity
   reduction = skill + risk + luck) and the "spread" be met by daring and luck only? Say which.
3. Is the regression sound as evidence that "the combination predicts the guess count"? Game-level
   means over guesses with a choice, a lost game coded as 7, simulated players only. What would be
   a better design or a fairer statistic (per-guess models, an ordinal or survival model, a
   held-out set)? Are the three scores collinear enough to make the coefficients meaningless?
4. Is there a better way to define a signed daring that is not just a ranking: one that is zero
   for a "neutral" choice by a principle (as luck is zero by the average over answers) rather than
   by the shape of the option set?

Please report: errors found, then a recommendation for the final definitions, with the reasoning
in plain terms and anything that should be tested before it is built.
