# The bits maths (2026-10)

What changed, and why.

| Before | Now |
| --- | --- |
| skill from the expected pool, `ln(N/E)/ln(N/E*)` | skill = `H / H* x 100`, `H` the entropy of the split, in bits |
| luck from the size of the pool landed in | luck from the gain landed in: P(gain < yours) - P(gain > yours); the same number, in bits it is gain - `H` |
| daring: going for the word at a cost | risk: P(gain < H) - P(gain > H), as a share of the riskiest guess |
| expected tries = base - skill + luck + daring (a fit) | bits gained = bits expected + luck, exactly; tries are not predicted |
| six tiers of skill and daring | five behaviours, six styles of an early and an end habit |

Decisions: bits (log base 2) are the unit; trits were rejected. A win counts as cutting all
the remaining bits. The last guess with one word left scores skill 100, risk 0, luck 0, gain 0.
The final-try rules (skill is the win chance share, luck is the outcome less the chance) are kept.

Playstyle thresholds come from simulated players (`docs/paper/experiments/styles`), not
people. Achievements are 97, each with a medal, kept as numbers per language. Each mode has its
own daily and streak. `metricsVersion` is 5, so stored games are scored again when the history
is opened.

Not done here: the PDFs of the paper (no LaTeX), and screenshots in `docs/screenshots`, which
show the old screens.
